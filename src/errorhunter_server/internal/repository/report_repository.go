package repository

import (
	"context"

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
	var reports []model.WeeklyReport
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("week_number DESC").
		Offset(offset).Limit(pageSize).
		Find(&reports).Error
	return reports, total, err
}
