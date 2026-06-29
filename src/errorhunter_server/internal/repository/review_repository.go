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
