package service

import (
	"context"
	"fmt"
	"log"

	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/model"
	"gorm.io/gorm"
)

// KnowledgePointSeeder 知识点幂等种子
// 启动时把 configs/knowledge_points.yaml 的知识点 upsert 进 knowledge_points 表。
// grade/domain/is_recommended/subject 编码进 keywords JSONB（不改表结构）。
type KnowledgePointSeeder struct {
	db  *gorm.DB
	cfg *config.KnowledgePointConfig
}

func NewKnowledgePointSeeder(db *gorm.DB, cfg *config.KnowledgePointConfig) *KnowledgePointSeeder {
	return &KnowledgePointSeeder{db: db, cfg: cfg}
}

// Seed 执行种子，返回新增条数（已存在的更新，不计入新增）
func (s *KnowledgePointSeeder) Seed(ctx context.Context) (int, error) {
	created := 0

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 同步序列到当前最大 id：init-db.sql 显式插入 id 但未推进 knowledge_points_id_seq，
		// 不同步会导致后续 INSERT 从 1 开始撞主键。
		if err := tx.Exec(
			"SELECT setval('knowledge_points_id_seq', (SELECT COALESCE(MAX(id), 1) FROM knowledge_points))",
		).Error; err != nil {
			return fmt.Errorf("sync knowledge_points_id_seq: %w", err)
		}

		for _, p := range s.cfg.Points {
			keywords := model.JSONBFromMap(map[string]interface{}{
				"grade":          p.Grade,
				"domain":         p.Domain,
				"subject":        s.cfg.Subject,
				"is_recommended": p.IsRecommended,
			})
			stage := model.Grade(p.Grade).Stage()

			// find-or-create 按 (name, version, keywords->>'grade')
			var existing model.KnowledgePoint
			err := tx.WithContext(ctx).
				Where("name = ? AND version = ? AND keywords->>'grade' = ?", p.Name, s.cfg.Version, p.Grade).
				First(&existing).Error

			if err == nil {
				// 命中：更新 keywords / sort_order / stage
				if err := tx.Model(&existing).Updates(map[string]interface{}{
					"keywords":   keywords,
					"sort_order": p.SortOrder,
					"stage":      stage,
				}).Error; err != nil {
					return fmt.Errorf("update knowledge point %q: %w", p.Name, err)
				}
				continue
			}

			if err != gorm.ErrRecordNotFound {
				return fmt.Errorf("query knowledge point %q: %w", p.Name, err)
			}

			// 新增
			kp := model.KnowledgePoint{
				Name:      p.Name,
				Level:     3,
				Stage:     stage,
				Keywords:  keywords,
				SortOrder: p.SortOrder,
				Version:   s.cfg.Version,
			}
			if err := tx.Create(&kp).Error; err != nil {
				return fmt.Errorf("create knowledge point %q: %w", p.Name, err)
			}
			created++
		}
		return nil
	})
	if err != nil {
		return 0, err
	}

	log.Printf("Knowledge points seeded (%d created, %d total in config)", created, len(s.cfg.Points))
	return created, nil
}
