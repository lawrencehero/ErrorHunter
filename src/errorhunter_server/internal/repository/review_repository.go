package repository

import (
	"context"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"gorm.io/gorm"
)

// ReviewRecordRepository 复习记录数据访问
type ReviewRecordRepository struct {
	db *gorm.DB
}

func NewReviewRecordRepository(db *gorm.DB) *ReviewRecordRepository {
	return &ReviewRecordRepository{db: db}
}

// Create 创建复习记录
func (r *ReviewRecordRepository) Create(ctx context.Context, record *model.ReviewRecord) error {
	return r.db.WithContext(ctx).Create(record).Error
}

// FindByQuestionAndDate 检查今日是否已复习
func (r *ReviewRecordRepository) FindByQuestionAndDate(ctx context.Context, questionID int64, userID int64, date time.Time) (*model.ReviewRecord, error) {
	var record model.ReviewRecord
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)
	err := r.db.WithContext(ctx).
		Where("question_id = ? AND user_id = ? AND reviewed_at >= ? AND reviewed_at < ?",
			questionID, userID, startOfDay, endOfDay).
		First(&record).Error
	if err != nil {
		return nil, err
	}
	return &record, nil
}

// ListByUser 用户复习历史
func (r *ReviewRecordRepository) ListByUser(ctx context.Context, userID int64, page, pageSize int) ([]model.ReviewRecord, int64, error) {
	var total int64
	r.db.WithContext(ctx).Model(&model.ReviewRecord{}).Where("user_id = ?", userID).Count(&total)

	offset := (page - 1) * pageSize
	records := make([]model.ReviewRecord, 0)
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("reviewed_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&records).Error
	return records, total, err
}

// ListByQuestion 按错题取最近 N 条复习记录（倒序），用于错题详情"复习历史"。
// limit<=0 时返回空切片（防御性，调用方应传正数如 20）。
func (r *ReviewRecordRepository) ListByQuestion(ctx context.Context, questionID int64, limit int) ([]model.ReviewRecord, error) {
	if limit <= 0 {
		return []model.ReviewRecord{}, nil
	}
	records := make([]model.ReviewRecord, 0, limit)
	err := r.db.WithContext(ctx).
		Where("question_id = ?", questionID).
		Order("reviewed_at DESC").
		Limit(limit).
		Find(&records).Error
	return records, err
}

// CountByQuestion 单题累计复习次数。
func (r *ReviewRecordRepository) CountByQuestion(ctx context.Context, questionID int64) (int, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&model.ReviewRecord{}).
		Where("question_id = ?", questionID).
		Count(&count).Error
	return int(count), err
}

// CountByQuestions 批量取多题累计复习次数，返回 questionID -> count。
// 用于错题列表/复习队列批量填充 ReviewCount，避免 N+1。空入参返回空 map。
func (r *ReviewRecordRepository) CountByQuestions(ctx context.Context, questionIDs []int64) (map[int64]int, error) {
	result := make(map[int64]int, len(questionIDs))
	if len(questionIDs) == 0 {
		return result, nil
	}
	type row struct {
		QuestionID int64
		Count      int
	}
	var rows []row
	err := r.db.WithContext(ctx).
		Model(&model.ReviewRecord{}).
		Select("question_id, COUNT(*) as count").
		Where("question_id IN ?", questionIDs).
		Group("question_id").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	for _, r := range rows {
		result[r.QuestionID] = r.Count
	}
	return result, nil
}

// GetStatsByDateRange 获取日期范围内的统计
type ReviewStats struct {
	TotalReviews int
	MasteredCount int
	Accuracy     float64
}

func (r *ReviewRecordRepository) GetStatsByDateRange(ctx context.Context, userID int64, start, end time.Time) (*ReviewStats, error) {
	var stats ReviewStats
	err := r.db.WithContext(ctx).Model(&model.ReviewRecord{}).
		Where("user_id = ? AND reviewed_at >= ? AND reviewed_at < ?", userID, start, end).
		Select(`
			COUNT(*) as total_reviews,
			SUM(CASE WHEN self_rating = 'MASTERED' THEN 1 ELSE 0 END) as mastered_count
		`).
		Scan(&stats).Error
	if err != nil {
		return nil, err
	}
	if stats.TotalReviews > 0 {
		stats.Accuracy = float64(stats.MasteredCount) / float64(stats.TotalReviews) * 100
	}
	return &stats, nil
}

// TodayReviewSummary 今日复习汇总（供首页"查看复习"展示真实结果数据，
// 而非空报告全零）。区间为 [start, end) 的一天。
type TodayReviewSummary struct {
	TotalCount     int   // 今日复习总数（review_records 行数）
	MasteredCount  int   // 自评 MASTERED 数
	PartialCount   int   // 自评 PARTIAL 数
	FailedCount    int   // 自评 FAILED 数
	DurationSec    int   // 今日复习总用时（秒）
	EliminatedCount int  // 今日新消灭题数（mastered_at 落在今天的题数）
}

// GetTodaySummary 聚合用户今日复习汇总。
//   - 各自评计数与总用时来自 review_records（reviewed_at 在今天）。
//   - 今日消灭数来自 questions（mastered_at 落在今天的题数，含永久消灭的母题）。
func (r *ReviewRecordRepository) GetTodaySummary(ctx context.Context, userID int64, start, end time.Time) (*TodayReviewSummary, error) {
	var s TodayReviewSummary
	err := r.db.WithContext(ctx).Model(&model.ReviewRecord{}).
		Where("user_id = ? AND reviewed_at >= ? AND reviewed_at < ?", userID, start, end).
		Select(`
			COUNT(*) AS total_count,
			SUM(CASE WHEN self_rating = 'MASTERED' THEN 1 ELSE 0 END) AS mastered_count,
			SUM(CASE WHEN self_rating = 'PARTIAL' THEN 1 ELSE 0 END) AS partial_count,
			SUM(CASE WHEN self_rating = 'FAILED' THEN 1 ELSE 0 END) AS failed_count,
			COALESCE(SUM(review_duration_sec), 0) AS duration_sec
		`).
		Scan(&s).Error
	if err != nil {
		return nil, err
	}

	// 今日消灭数：mastered_at 在今天的题数。
	var eliminated int64
	if err := r.db.WithContext(ctx).Model(&model.Question{}).
		Where("user_id = ? AND mastered_at >= ? AND mastered_at < ?", userID, start, end).
		Count(&eliminated).Error; err != nil {
		return nil, err
	}
	s.EliminatedCount = int(eliminated)
	return &s, nil
}
