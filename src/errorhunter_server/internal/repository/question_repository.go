package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"gorm.io/gorm"
)

// QuestionRepository 错题数据访问
type QuestionRepository struct {
	db *gorm.DB
}

func NewQuestionRepository(db *gorm.DB) *QuestionRepository {
	return &QuestionRepository{db: db}
}

// Create 创建错题
func (r *QuestionRepository) Create(ctx context.Context, question *model.Question) error {
	return r.db.WithContext(ctx).Create(question).Error
}

// FindByID 根据ID查找（包含知识点关联）
func (r *QuestionRepository) FindByID(ctx context.Context, id int64) (*model.Question, error) {
	var question model.Question
	err := r.db.WithContext(ctx).
		Preload("KnowledgePoints").
		Where("id = ? AND deleted_at IS NULL", id).
		First(&question).Error
	if err != nil {
		return nil, err
	}
	return &question, nil
}

// FindByIDWithDeleted 查找包括已软删除的
func (r *QuestionRepository) FindByIDWithDeleted(ctx context.Context, id int64) (*model.Question, error) {
	var question model.Question
	err := r.db.WithContext(ctx).
		Unscoped().
		Preload("KnowledgePoints").
		Where("id = ?", id).
		First(&question).Error
	if err != nil {
		return nil, err
	}
	return &question, nil
}

// List 分页列表
type ListFilter struct {
	UserID           int64
	Status           []model.QuestionStatus
	ErrorCategory    *model.ErrorCategory
	KnowledgePointID *int
	StartDate        *time.Time
	EndDate          *time.Time
	Keyword          string
	Tag              *string // 自定义标签筛选（custom_tags JSONB 包含）
	SortBy           string // created_at, updated_at
	SortOrder        string // asc, desc
	Page             int
	PageSize         int
}

type ListResult struct {
	List  []model.Question
	Total int64
}

func (r *QuestionRepository) List(ctx context.Context, filter ListFilter) (*ListResult, error) {
	query := r.db.WithContext(ctx).Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NULL", filter.UserID)

	if len(filter.Status) > 0 {
		query = query.Where("status IN ?", filter.Status)
	}
	if filter.ErrorCategory != nil {
		query = query.Where("error_category = ?", *filter.ErrorCategory)
	}
	if filter.KnowledgePointID != nil {
		query = query.Joins("JOIN question_knowledge ON question_knowledge.question_id = questions.id").
			Where("question_knowledge.knowledge_point_id = ?", *filter.KnowledgePointID)
	}
	if filter.StartDate != nil {
		query = query.Where("created_at >= ?", *filter.StartDate)
	}
	if filter.EndDate != nil {
		endDate := filter.EndDate.Add(24 * time.Hour)
		query = query.Where("created_at <= ?", endDate)
	}
	if filter.Keyword != "" {
		query = query.Where("ocr_text ILIKE ?", "%"+filter.Keyword+"%")
	}
	// 自定义标签筛选：custom_tags 是 JSONB 数组，用 @> 包含查询。
	// 参数化拼成 ["tag"]::jsonb，对 tag 内双引号转义防注入。
	if filter.Tag != nil && *filter.Tag != "" {
		escaped := strings.ReplaceAll(*filter.Tag, `"`, `\"`)
		query = query.Where("custom_tags @> ?::jsonb", fmt.Sprintf(`["%s"]`, escaped))
	}

	// Count total
	var total int64
	countQuery := query.Session(&gorm.Session{})
	if err := countQuery.Count(&total).Error; err != nil {
		return nil, err
	}

	// Sort
	sortField := "created_at"
	if filter.SortBy == "updated_at" {
		sortField = "updated_at"
	}
	sortOrder := "DESC"
	if filter.SortOrder == "asc" {
		sortOrder = "ASC"
	}
	query = query.Order(sortField + " " + sortOrder)

	// Pagination
	offset := (filter.Page - 1) * filter.PageSize
	query = query.Offset(offset).Limit(filter.PageSize)

	list := make([]model.Question, 0)
	if err := query.Preload("KnowledgePoints").Find(&list).Error; err != nil {
		return nil, err
	}

	return &ListResult{List: list, Total: total}, nil
}

// GetDistinctTags 返回该用户所有错题中去重后的自定义标签集合。
// 用 jsonb_array_elements_text 把 custom_tags 数组展开成行再 DISTINCT。
// 跳过 deleted_at IS NOT NULL 的软删题。custom_tags 为空/NULL 的题不产生行。
func (r *QuestionRepository) GetDistinctTags(ctx context.Context, userID int64) ([]string, error) {
	var tags []string
	err := r.db.WithContext(ctx).
		Raw(`SELECT DISTINCT tag FROM questions, jsonb_array_elements_text(custom_tags) AS tag
		     WHERE user_id = ? AND deleted_at IS NULL`, userID).
		Scan(&tags).Error
	if err != nil {
		return nil, err
	}
	return tags, nil
}

// GetReviewableByIDs 按 ID 批量取可复习的错题（单题复习入口用）。
// 不限 due 日期、不限每日上限；排除已软删与已永久消灭的题。Preload 知识点，
// 排序与 GetDueQuestions 一致（review_round DESC, next_review_date ASC）。
func (r *QuestionRepository) GetReviewableByIDs(ctx context.Context, userID int64, ids []int64) ([]model.Question, error) {
	list := make([]model.Question, 0)
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.WithContext(ctx).
		Preload("KnowledgePoints").
		Where("user_id = ? AND id IN ? AND deleted_at IS NULL AND status != ?", userID, ids, model.StatusPermanentlyMastered).
		Order("review_round DESC, next_review_date ASC").
		Find(&list).Error
	if err != nil {
		return nil, err
	}
	return list, nil
}

// Update 更新错题
func (r *QuestionRepository) Update(ctx context.Context, question *model.Question) error {
	return r.db.WithContext(ctx).Save(question).Error
}

// SoftDelete 软删除
func (r *QuestionRepository) SoftDelete(ctx context.Context, id int64) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&model.Question{}).
		Where("id = ?", id).
		Update("deleted_at", now).Error
}

// Restore 恢复软删除
func (r *QuestionRepository) Restore(ctx context.Context, id int64) error {
	return r.db.WithContext(ctx).Unscoped().
		Model(&model.Question{}).
		Where("id = ? AND deleted_at IS NOT NULL", id).
		Update("deleted_at", nil).Error
}

// PermanentDelete 永久删除
func (r *QuestionRepository) PermanentDelete(ctx context.Context, id int64) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 先清理知识点关联，否则 fk_qk_question (ON DELETE NO ACTION) 会阻止删除
		if err := tx.Exec("DELETE FROM question_knowledge WHERE question_id = ?", id).Error; err != nil {
			return err
		}
		return tx.Unscoped().Delete(&model.Question{}, id).Error
	})
}

// ListDeletedImageURLs 获取用户回收站中所有错题的图片 URL（用于清理对象存储）
func (r *QuestionRepository) ListDeletedImageURLs(ctx context.Context, userID int64) ([]string, error) {
	var urls []string
	err := r.db.WithContext(ctx).Unscoped().
		Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NOT NULL", userID).
		Pluck("image_url", &urls).Error
	return urls, err
}

// ListRecycleBin 回收站列表
func (r *QuestionRepository) ListRecycleBin(ctx context.Context, userID int64, page, pageSize int) (*ListResult, error) {
	var total int64
	r.db.WithContext(ctx).Model(&model.Question{}).
		Unscoped().
		Where("user_id = ? AND deleted_at IS NOT NULL", userID).
		Count(&total)

	offset := (page - 1) * pageSize
	list := make([]model.Question, 0)
	err := r.db.WithContext(ctx).
		Unscoped().
		Preload("KnowledgePoints").
		Where("user_id = ? AND deleted_at IS NOT NULL", userID).
		Order("deleted_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&list).Error
	if err != nil {
		return nil, err
	}

	return &ListResult{List: list, Total: total}, nil
}

// ClearRecycleBin 清空回收站
func (r *QuestionRepository) ClearRecycleBin(ctx context.Context, userID int64) (int64, error) {
	var affected int64
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 先清理这些回收站题目的知识点关联，否则 fk_qk_question 会阻止删除
		if err := tx.Exec(
			"DELETE FROM question_knowledge WHERE question_id IN (SELECT id FROM questions WHERE user_id = ? AND deleted_at IS NOT NULL)",
			userID,
		).Error; err != nil {
			return err
		}
		res := tx.Unscoped().
			Where("user_id = ? AND deleted_at IS NOT NULL", userID).
			Delete(&model.Question{})
		affected = res.RowsAffected
		return res.Error
	})
	return affected, err
}

// GetDueQuestions 获取今日待复习题目
func (r *QuestionRepository) GetDueQuestions(ctx context.Context, userID int64, today time.Time) ([]model.Question, error) {
	questions := make([]model.Question, 0)
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND deleted_at IS NULL AND status IN (?, ?) AND next_review_date <= ?",
			userID, model.StatusNotStarted, model.StatusReviewing, today).
		Order("review_round DESC, next_review_date ASC").
		Preload("KnowledgePoints").
		Find(&questions).Error
	return questions, err
}

// GetReviveCandidates 获取复活检测候选题目
func (r *QuestionRepository) GetReviveCandidates(ctx context.Context, userID int64, today time.Time, limit int) ([]model.Question, error) {
	questions := make([]model.Question, 0)
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND deleted_at IS NULL AND status = ? AND revive_check_date <= ?",
			userID, model.StatusMastered, today).
		Order("mastered_at ASC").
		Limit(limit).
		Preload("KnowledgePoints").
		Find(&questions).Error
	return questions, err
}

// UpdateReviewPlan 更新复习计划
func (r *QuestionRepository) UpdateReviewPlan(ctx context.Context, id int64, status model.QuestionStatus, round, masterCount int, nextReviewDate time.Time) error {
	updates := map[string]interface{}{
		"status":           status,
		"review_round":     round,
		"master_count":     masterCount,
		"next_review_date": nextReviewDate,
	}
	if status == model.StatusMastered {
		updates["mastered_at"] = time.Now()
		updates["revive_check_date"] = time.Now().AddDate(0, 0, 30)
	}
	return r.db.WithContext(ctx).Model(&model.Question{}).Where("id = ?", id).Updates(updates).Error
}

// ResetReviewPlan 重置复习计划（复活失败时）
func (r *QuestionRepository) ResetReviewPlan(ctx context.Context, id int64, nextReviewDate time.Time) error {
	return r.db.WithContext(ctx).Model(&model.Question{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":                model.StatusReviewing,
		"review_round":          1,
		"master_count":          0,
		"next_review_date":      nextReviewDate,
		"mastered_at":           nil,
		"revive_check_date":     nil,
		"revive_check_interval": 30,
	}).Error
}

// MarkPermanentlyMastered 标记永久消灭
func (r *QuestionRepository) MarkPermanentlyMastered(ctx context.Context, id int64) error {
	return r.db.WithContext(ctx).Model(&model.Question{}).Where("id = ?", id).Update("status", model.StatusPermanentlyMastered).Error
}

// UpdateReviveSchedule 更新复活检测计划
func (r *QuestionRepository) UpdateReviveSchedule(ctx context.Context, id int64, interval int, nextDate time.Time) error {
	return r.db.WithContext(ctx).Model(&model.Question{}).Where("id = ?", id).Updates(map[string]interface{}{
		"revive_check_interval": interval,
		"revive_check_date":     nextDate,
	}).Error
}
