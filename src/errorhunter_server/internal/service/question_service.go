package service

import (
	"context"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/pkg/scheduler"
	"github.com/errorhunter/errorhunter-server/internal/repository"
)

// QuestionService 错题服务
type QuestionService struct {
	questionRepo *repository.QuestionRepository
	userRepo     *repository.UserRepository
}

func NewQuestionService(
	questionRepo *repository.QuestionRepository,
	userRepo *repository.UserRepository,
) *QuestionService {
	return &QuestionService{
		questionRepo: questionRepo,
		userRepo:     userRepo,
	}
}

// CreateRequest 创建错题请求
type CreateRequest struct {
	ImageURL         string   `json:"image_url" binding:"required"`
	OcrText          string   `json:"ocr_text"`
	OcrConfirmed     bool     `json:"ocr_confirmed"`
	MyAnswer         string   `json:"my_answer"`
	CorrectAnswer    string   `json:"correct_answer"`
	SolutionSteps    []string `json:"solution_steps"`
	ErrorStepIndex   *int     `json:"error_step_index"`
	ErrorCategory    string   `json:"error_category" binding:"required"`
	ErrorSubCategory string   `json:"error_sub_category"`
	KnowledgePointIDs []int   `json:"knowledge_point_ids" binding:"required,min=1,max=3"`
	CustomTags       []string `json:"custom_tags"`
}

// Create 创建错题
func (s *QuestionService) Create(ctx context.Context, userID int64, req CreateRequest) (*model.Question, error) {
	// 验证错因分类
	errorCat := model.ErrorCategory(req.ErrorCategory)
	if !isValidErrorCategory(errorCat) {
		return nil, errcode.EErrorCategoryInvalid
	}

	// 验证自定义标签数量
	if len(req.CustomTags) > 5 {
		return nil, errcode.ECustomTagsMax
	}

	// 构建错题对象
	now := time.Now()
	tomorrow := now.AddDate(0, 0, 1)

	question := &model.Question{
		UserID:           userID,
		Status:           model.StatusNotStarted,
		ImageURL:         req.ImageURL,
		OcrConfirmed:     req.OcrConfirmed,
		ErrorCategory:    errorCat,
		MasterCount:      0,
		ReviewRound:      1,
		NextReviewDate:   tomorrow,
	}

	if req.OcrText != "" {
		question.OcrText = &req.OcrText
	}
	if req.MyAnswer != "" {
		question.MyAnswer = &req.MyAnswer
	}
	if req.CorrectAnswer != "" {
		question.CorrectAnswer = &req.CorrectAnswer
	}
	if req.ErrorSubCategory != "" {
		question.ErrorSubCategory = &req.ErrorSubCategory
	}
	if req.ErrorStepIndex != nil {
		question.ErrorStepIndex = req.ErrorStepIndex
	}
	if len(req.SolutionSteps) > 0 {
		question.SolutionSteps = model.JSONBFromSlice(req.SolutionSteps)
	}
	if len(req.CustomTags) > 0 {
		question.CustomTags = model.JSONBFromSlice(req.CustomTags)
	}

	// 关联知识点（简化处理，实际需要查询并验证）
	for _, kpID := range req.KnowledgePointIDs {
		question.KnowledgePoints = append(question.KnowledgePoints, model.KnowledgePoint{ID: kpID})
	}

	if err := s.questionRepo.Create(ctx, question); err != nil {
		return nil, errcode.EInternalServer
	}

	return question, nil
}

// GetByID 获取错题详情
func (s *QuestionService) GetByID(ctx context.Context, id, userID int64) (*model.Question, error) {
	question, err := s.questionRepo.FindByID(ctx, id)
	if err != nil {
		return nil, errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return nil, errcode.EQuestionBelongsToOther
	}
	return question, nil
}

// ListFilter 列表筛选条件
type ListFilter struct {
	Status           []string
	ErrorCategory    *string
	KnowledgePointID *int
	StartDate        *string
	EndDate          *string
	Keyword          string
	SortBy           string
	SortOrder        string
	Page             int
	PageSize         int
}

// ListResult 列表结果
type ListResult struct {
	List       []model.Question `json:"list"`
	Pagination Pagination       `json:"pagination"`
}

// Pagination 分页信息
type Pagination struct {
	Page     int   `json:"page"`
	PageSize int   `json:"page_size"`
	Total    int64 `json:"total"`
}

// List 获取错题列表
func (s *QuestionService) List(ctx context.Context, userID int64, filter ListFilter) (*ListResult, error) {
	repoFilter := repository.ListFilter{
		UserID:    userID,
		Page:      filter.Page,
		PageSize:  filter.PageSize,
		Keyword:   filter.Keyword,
		SortBy:    filter.SortBy,
		SortOrder: filter.SortOrder,
	}

	// 转换状态筛选
	if len(filter.Status) > 0 {
		for _, st := range filter.Status {
			repoFilter.Status = append(repoFilter.Status, model.QuestionStatus(st))
		}
	}

	// 转换错因筛选
	if filter.ErrorCategory != nil {
		cat := model.ErrorCategory(*filter.ErrorCategory)
		repoFilter.ErrorCategory = &cat
	}

	repoFilter.KnowledgePointID = filter.KnowledgePointID

	result, err := s.questionRepo.List(ctx, repoFilter)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	return &ListResult{
		List: result.List,
		Pagination: Pagination{
			Page:     filter.Page,
			PageSize: filter.PageSize,
			Total:    result.Total,
		},
	}, nil
}

// UpdateRequest 更新错题请求
type UpdateRequest struct {
	OcrText          *string  `json:"ocr_text"`
	OcrConfirmed     *bool    `json:"ocr_confirmed"`
	MyAnswer         *string  `json:"my_answer"`
	CorrectAnswer    *string  `json:"correct_answer"`
	SolutionSteps    []string `json:"solution_steps"`
	ErrorStepIndex   *int     `json:"error_step_index"`
	ErrorCategory    *string  `json:"error_category"`
	ErrorSubCategory *string  `json:"error_sub_category"`
	KnowledgePointIDs []int   `json:"knowledge_point_ids"`
	CustomTags       []string `json:"custom_tags"`
}

// Update 更新错题
func (s *QuestionService) Update(ctx context.Context, id, userID int64, req UpdateRequest) (*model.Question, error) {
	question, err := s.questionRepo.FindByID(ctx, id)
	if err != nil {
		return nil, errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return nil, errcode.EQuestionBelongsToOther
	}

	// 应用更新
	if req.OcrText != nil {
		question.OcrText = req.OcrText
	}
	if req.OcrConfirmed != nil {
		question.OcrConfirmed = *req.OcrConfirmed
	}
	if req.MyAnswer != nil {
		question.MyAnswer = req.MyAnswer
	}
	if req.CorrectAnswer != nil {
		question.CorrectAnswer = req.CorrectAnswer
	}
	if req.ErrorStepIndex != nil {
		question.ErrorStepIndex = req.ErrorStepIndex
	}
	if req.ErrorCategory != nil {
		question.ErrorCategory = model.ErrorCategory(*req.ErrorCategory)
	}
	if req.ErrorSubCategory != nil {
		question.ErrorSubCategory = req.ErrorSubCategory
	}
	if req.SolutionSteps != nil {
		question.SolutionSteps = model.JSONBFromSlice(req.SolutionSteps)
	}
	if req.CustomTags != nil {
		if len(req.CustomTags) > 5 {
			return nil, errcode.ECustomTagsMax
		}
		question.CustomTags = model.JSONBFromSlice(req.CustomTags)
	}

	if err := s.questionRepo.Update(ctx, question); err != nil {
		return nil, errcode.EInternalServer
	}

	return question, nil
}

// SoftDelete 软删除
func (s *QuestionService) SoftDelete(ctx context.Context, id, userID int64) error {
	question, err := s.questionRepo.FindByID(ctx, id)
	if err != nil {
		return errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return errcode.EQuestionBelongsToOther
	}
	return s.questionRepo.SoftDelete(ctx, id)
}

// Restore 恢复错题
func (s *QuestionService) Restore(ctx context.Context, id, userID int64) error {
	question, err := s.questionRepo.FindByIDWithDeleted(ctx, id)
	if err != nil {
		return errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return errcode.EQuestionBelongsToOther
	}
	if question.DeletedAt == nil {
		return nil // 未删除，无需恢复
	}
	return s.questionRepo.Restore(ctx, id)
}

// PermanentDelete 永久删除
func (s *QuestionService) PermanentDelete(ctx context.Context, id, userID int64) error {
	question, err := s.questionRepo.FindByIDWithDeleted(ctx, id)
	if err != nil {
		return errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return errcode.EQuestionBelongsToOther
	}
	return s.questionRepo.PermanentDelete(ctx, id)
}

// ListRecycleBin 回收站列表
func (s *QuestionService) ListRecycleBin(ctx context.Context, userID int64, page, pageSize int) (*ListResult, error) {
	result, err := s.questionRepo.ListRecycleBin(ctx, userID, page, pageSize)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	return &ListResult{
		List: result.List,
		Pagination: Pagination{
			Page:     page,
			PageSize: pageSize,
			Total:    result.Total,
		},
	}, nil
}

// ClearRecycleBin 清空回收站
func (s *QuestionService) ClearRecycleBin(ctx context.Context, userID int64) (int64, error) {
	return s.questionRepo.ClearRecycleBin(ctx, userID)
}

func isValidErrorCategory(cat model.ErrorCategory) bool {
	switch cat {
	case model.ErrorKnowledge, model.ErrorSkill, model.ErrorPsychology, model.ErrorHabit, model.ErrorUnknown:
		return true
	default:
		return false
	}
}

// GetDueQuestions 获取今日待复习题目
func (s *QuestionService) GetDueQuestions(ctx context.Context, userID int64) ([]model.Question, error) {
	today := time.Now()
	return s.questionRepo.GetDueQuestions(ctx, userID, today)
}

// ApplyDailyLimit 应用每日上限
func (s *QuestionService) ApplyDailyLimit(questions []model.Question, limit int) (today, deferred []model.Question) {
	candidates := make([]scheduler.ReviewCandidate, len(questions))
	for i, q := range questions {
		candidates[i] = scheduler.ReviewCandidate{
			QuestionID:  q.ID,
			ReviewRound: q.ReviewRound,
			CreatedAt:   q.CreatedAt.Unix(),
		}
	}

	todayCandidates, deferredCandidates := scheduler.ApplyDailyLimit(candidates, limit)

	todayMap := make(map[int64]bool)
	for _, c := range todayCandidates {
		todayMap[c.QuestionID] = true
	}

	for _, q := range questions {
		if todayMap[q.ID] {
			today = append(today, q)
		} else {
			deferred = append(deferred, q)
		}
	}
	return
}
