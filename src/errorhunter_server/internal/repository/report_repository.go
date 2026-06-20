package repository

import (
	"context"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"gorm.io/gorm"
)

// WeeklyReportRepository 周报数据访问
type WeeklyReportRepository struct {
	db *gorm.DB
}

func NewWeeklyReportRepository(db *gorm.DB) *WeeklyReportRepository {
	return &WeeklyReportRepository{db: db}
}

// Create 创建周报
func (r *WeeklyReportRepository) Create(ctx context.Context, report *model.WeeklyReport) error {
	return r.db.WithContext(ctx).Create(report).Error
}

// FindByID 根据ID查找
func (r *WeeklyReportRepository) FindByID(ctx context.Context, id int64) (*model.WeeklyReport, error) {
	var report model.WeeklyReport
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&report).Error
	if err != nil {
		return nil, err
	}
	return &report, nil
}

// ListByUser 用户周报列表
func (r *WeeklyReportRepository) ListByUser(ctx context.Context, userID int64, page, pageSize int) ([]model.WeeklyReport, int64, error) {
	var total int64
	r.db.WithContext(ctx).Model(&model.WeeklyReport{}).Where("user_id = ?", userID).Count(&total)

	offset := (page - 1) * pageSize
	reports := make([]model.WeeklyReport, 0)
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("week_number DESC").
		Offset(offset).Limit(pageSize).
		Find(&reports).Error
	return reports, total, err
}

// DashboardStats Dashboard统计数据
type DashboardStats struct {
	TotalQuestions  int64
	MasteredCount   int64
	PendingReview   int64
}

// GetDashboardStats 获取Dashboard基础统计
func (r *WeeklyReportRepository) GetDashboardStats(ctx context.Context, userID int64) (*DashboardStats, error) {
	stats := &DashboardStats{}

	// 总题数（未删除）
	r.db.WithContext(ctx).Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Count(&stats.TotalQuestions)

	// 已消灭题数
	r.db.WithContext(ctx).Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NULL AND status IN (?, ?)",
			userID, model.StatusMastered, model.StatusPermanentlyMastered).
		Count(&stats.MasteredCount)

	// 今日待复习数
	today := time.Now()
	r.db.WithContext(ctx).Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NULL AND status IN (?, ?) AND next_review_date <= ?",
			userID, model.StatusNotStarted, model.StatusReviewing, today).
		Count(&stats.PendingReview)

	return stats, nil
}

// ErrorDistributionItem 错因分布项
type ErrorDistributionItem struct {
	Category string `json:"category"`
	Count    int64  `json:"count"`
}

// GetErrorDistribution 获取错因分布
func (r *WeeklyReportRepository) GetErrorDistribution(ctx context.Context, userID int64) ([]ErrorDistributionItem, error) {
	items := make([]ErrorDistributionItem, 0)
	err := r.db.WithContext(ctx).
		Model(&model.Question{}).
		Select("error_category as category, COUNT(*) as count").
		Where("user_id = ? AND deleted_at IS NULL AND error_category != ?", userID, model.ErrorUnknown).
		Group("error_category").
		Order("count DESC").
		Scan(&items).Error
	return items, err
}

// WeeklyTrendItem 周趋势项
type WeeklyTrendItem struct {
	Date           string `json:"date"`
	NewQuestions   int64  `json:"new_questions"`
	MasteredCount  int64  `json:"mastered_count"`
}

// GetWeeklyTrend 获取最近7天趋势
func (r *WeeklyReportRepository) GetWeeklyTrend(ctx context.Context, userID int64) ([]WeeklyTrendItem, error) {
	items := make([]WeeklyTrendItem, 0)

	// 最近7天每天新增错题数
	type dateCount struct {
		Date  string
		Count int64
	}
	newQuestions := make([]dateCount, 0)
	r.db.WithContext(ctx).
		Model(&model.Question{}).
		Select("TO_CHAR(created_at, 'YYYY-MM-DD') as date, COUNT(*) as count").
		Where("user_id = ? AND deleted_at IS NULL AND created_at >= ?", userID, time.Now().AddDate(0, 0, -6)).
		Group("TO_CHAR(created_at, 'YYYY-MM-DD')").
		Order("date ASC").
		Scan(&newQuestions)

	// 最近7天每天消灭错题数
	masteredQuestions := make([]dateCount, 0)
	r.db.WithContext(ctx).
		Model(&model.Question{}).
		Select("TO_CHAR(mastered_at, 'YYYY-MM-DD') as date, COUNT(*) as count").
		Where("user_id = ? AND deleted_at IS NULL AND mastered_at IS NOT NULL AND mastered_at >= ?", userID, time.Now().AddDate(0, 0, -6)).
		Group("TO_CHAR(mastered_at, 'YYYY-MM-DD')").
		Order("date ASC").
		Scan(&masteredQuestions)

	// 合并为7天数据
	newMap := make(map[string]int64)
	for _, nq := range newQuestions {
		newMap[nq.Date] = nq.Count
	}
	masteredMap := make(map[string]int64)
	for _, mq := range masteredQuestions {
		masteredMap[mq.Date] = mq.Count
	}

	for i := 6; i >= 0; i-- {
		date := time.Now().AddDate(0, 0, -i).Format("2006-01-02")
		items = append(items, WeeklyTrendItem{
			Date:          date,
			NewQuestions:  newMap[date],
			MasteredCount: masteredMap[date],
		})
	}

	return items, nil
}

// WeakKnowledgeItem 薄弱知识点项
type WeakKnowledgeItem struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Count int64  `json:"count"`
}

// GetWeakKnowledgeTop 获取薄弱知识点Top3
func (r *WeeklyReportRepository) GetWeakKnowledgeTop(ctx context.Context, userID int64) ([]WeakKnowledgeItem, error) {
	items := make([]WeakKnowledgeItem, 0)
	err := r.db.WithContext(ctx).
		Table("question_knowledge").
		Select("knowledge_points.id, knowledge_points.name, COUNT(*) as count").
		Joins("JOIN questions ON questions.id = question_knowledge.question_id").
		Joins("JOIN knowledge_points ON knowledge_points.id = question_knowledge.knowledge_point_id").
		Where("questions.user_id = ? AND questions.deleted_at IS NULL AND questions.status NOT IN (?, ?)",
			userID, model.StatusMastered, model.StatusPermanentlyMastered).
		Group("knowledge_points.id, knowledge_points.name").
		Order("count DESC").
		Limit(3).
		Scan(&items).Error
	return items, err
}
