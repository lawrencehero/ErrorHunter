package repository

import (
	"context"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"gorm.io/gorm"
)

// KnowledgePointRepository 知识点仓库
type KnowledgePointRepository struct {
	db *gorm.DB
}

func NewKnowledgePointRepository(db *gorm.DB) *KnowledgePointRepository {
	return &KnowledgePointRepository{db: db}
}

// ListByGradeAndSubject 按年级 + 学科查询知识点（grade/subject 存于 keywords JSONB）
func (r *KnowledgePointRepository) ListByGradeAndSubject(ctx context.Context, grade, subject, version string) ([]model.KnowledgePoint, error) {
	var points []model.KnowledgePoint
	err := r.db.WithContext(ctx).
		Where("keywords->>'grade' = ? AND keywords->>'subject' = ? AND version = ?", grade, subject, version).
		Order("sort_order ASC").
		Find(&points).Error
	if err != nil {
		return nil, err
	}
	return points, nil
}
