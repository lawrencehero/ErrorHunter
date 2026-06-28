package service

import (
	"context"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/pkg/scheduler"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"gorm.io/gorm"
)

// QuestionService 错题服务
type QuestionService struct {
	questionRepo *repository.QuestionRepository
	userRepo     *repository.UserRepository
	db           *gorm.DB
	imageDeleter ImageObjectDeleter
}

// ImageObjectDeleter 删除对象存储中的图片对象（由 handler.UploadHandler 实现）。
// 用于永久删除错题时同步清理 MinIO 图片，避免产生孤儿对象。
type ImageObjectDeleter interface {
	DeleteObject(ctx context.Context, key string) error
}

// objectKeyFromImageURL 从图片 URL 提取 MinIO 对象 key。
// 支持 http://host/v1/files/<key> 代理 URL；本地路径（cropped_*.png）返回空。
func objectKeyFromImageURL(imageURL string) string {
	const marker = "/v1/files/"
	if idx := strings.Index(imageURL, marker); idx >= 0 {
		return imageURL[idx+len(marker):]
	}
	return ""
}

// SetImageDeleter 注入对象存储删除能力，用于永久删除错题时清理 MinIO 图片。
func (s *QuestionService) SetImageDeleter(d ImageObjectDeleter) { s.imageDeleter = d }

// deleteImageBestEffort 尽力删除图片对象，失败仅记日志，不阻断业务流程。
func (s *QuestionService) deleteImageBestEffort(ctx context.Context, imageURL, scene string) {
	if s.imageDeleter == nil {
		return
	}
	key := objectKeyFromImageURL(imageURL)
	if key == "" {
		return
	}
	if err := s.imageDeleter.DeleteObject(ctx, key); err != nil {
		log.Printf("[WARN] %s：清理图片 %s 失败: %v", scene, key, err)
	}
}

func NewQuestionService(
	questionRepo *repository.QuestionRepository,
	userRepo *repository.UserRepository,
	db *gorm.DB,
) *QuestionService {
	return &QuestionService{
		questionRepo: questionRepo,
		userRepo:     userRepo,
		db:           db,
	}
}

// KnowledgePointInput 知识点对象输入（id 可为 int 字符串或自定义非数字 id）
type KnowledgePointInput struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// CreateRequest 创建错题请求
type CreateRequest struct {
	ImageURL          string                 `json:"image_url" binding:"required"`
	OcrText           string                 `json:"ocr_text"`
	OcrConfirmed      bool                   `json:"ocr_confirmed"`
	MyAnswer          string                 `json:"my_answer"`
	CorrectAnswer     string                 `json:"correct_answer"`
	SolutionSteps     []string               `json:"solution_steps"`
	ErrorStepIndex    *int                   `json:"error_step_index"`
	ErrorCategory     string                 `json:"error_category" binding:"required"`
	SubCategories     []string               `json:"sub_categories"`
	KnowledgePointIDs []int                  `json:"knowledge_point_ids" binding:"omitempty,max=10"`
	KnowledgePoints   []KnowledgePointInput  `json:"knowledge_points"`
	CustomTags        []string               `json:"custom_tags"`
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
	// 前端多选细分错因：空切片也照存（多选清空即 []）
	question.SubCategories = model.JSONBFromSlice(req.SubCategories)
	if req.ErrorStepIndex != nil {
		question.ErrorStepIndex = req.ErrorStepIndex
	}
	if len(req.SolutionSteps) > 0 {
		question.SolutionSteps = model.JSONBFromSlice(req.SolutionSteps)
	}
	if len(req.CustomTags) > 0 {
		question.CustomTags = model.JSONBFromSlice(req.CustomTags)
	}

	// 解析知识点 ID（兼容 knowledge_point_ids 与 knowledge_points 两种输入）
	resolvedIDs, err := s.resolveKnowledgePointIDs(ctx, userID, req.KnowledgePointIDs, req.KnowledgePoints)
	if err != nil {
		return nil, err
	}

	// 在事务中创建错题并写入 join table
	var createdQuestion *model.Question
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 创建错题（不关联知识点，避免 GORM upsert 空结构体）
		if err := tx.Create(question).Error; err != nil {
			return err
		}

		// 手动插入 join table
		for _, kpID := range resolvedIDs {
			if err := tx.Exec(
				"INSERT INTO question_knowledge (question_id, knowledge_point_id) VALUES (?, ?)",
				question.ID, kpID,
			).Error; err != nil {
				return fmt.Errorf("insert question_knowledge: %w", err)
			}
		}

		createdQuestion = question
		return nil
	})
	if err != nil {
		return nil, errcode.EInternalServer
	}

	// 回填知识点到返回对象
	var validKPs []model.KnowledgePoint
	if err := s.db.WithContext(ctx).Where("id IN ?", resolvedIDs).Find(&validKPs).Error; err == nil {
		createdQuestion.KnowledgePoints = validKPs
	}

	fillTotalReviewRounds(createdQuestion)
	return createdQuestion, nil
}

// resolveKnowledgePointIDs 解析知识点 ID。
//   - knowledge_point_ids：直收 int id
//   - knowledge_points：对象形式，id 可解析为 int 且存在则用；否则按 name + 用户 stage +
//     version find-or-create（覆盖自定义知识点）
//
// 返回去重后的 id 列表，并校验全部存在、数量 ≤ 10。
func (s *QuestionService) resolveKnowledgePointIDs(
	ctx context.Context,
	userID int64,
	ids []int,
	inputs []KnowledgePointInput,
) ([]int, error) {
	if len(ids) == 0 && len(inputs) == 0 {
		return nil, errcode.EKnowledgePointNotFound
	}

	// 取用户 stage（自定义知识点 find-or-create 用）
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, errcode.EUserNotFound
	}
	stage := user.Grade.Stage()

	resolved := make([]int, 0, len(ids)+len(inputs))
	seen := make(map[int]bool, len(ids)+len(inputs))
	add := func(id int) {
		if id > 0 && !seen[id] {
			seen[id] = true
			resolved = append(resolved, id)
		}
	}

	// 直收的 int id
	for _, id := range ids {
		add(id)
	}

	// 对象形式
	for _, in := range inputs {
		if in.ID == "" && in.Name == "" {
			continue
		}
		// id 能解析为 int 且存在 → 直接用
		if idInt, perr := strconv.Atoi(in.ID); perr == nil && idInt > 0 {
			var exists model.KnowledgePoint
			if qerr := s.db.WithContext(ctx).Select("id").First(&exists, idInt).Error; qerr == nil {
				add(idInt)
				continue
			}
			// 不存在则回退到按 name 解析
		}
		if in.Name == "" {
			continue
		}
		// UTF-8 校验：拒绝含 U+FFFD 替换符（多为 GBK 残片）的自定义知识点名，
		// 防止损坏数据再次入库。仅对非空 name 校验。
		if strings.ContainsRune(in.Name, '�') {
			return nil, errcode.EParamValidation.WithData("invalid knowledge point name")
		}
		// find-or-create by name + stage + version
		var kp model.KnowledgePoint
		qerr := s.db.WithContext(ctx).
			Where("name = ? AND stage = ? AND version = ?", in.Name, stage, "2026A").
			First(&kp).Error
		if qerr == gorm.ErrRecordNotFound {
			kp = model.KnowledgePoint{
				Name:      in.Name,
				Level:     3,
				Stage:     stage,
				Keywords: model.JSONBFromMap(map[string]interface{}{
					"grade":          string(user.Grade),
					"domain":         "custom",
					"subject":        "数学",
					"is_recommended": false,
				}),
				SortOrder: 9999,
				Version:   "2026A",
			}
			if cerr := s.db.WithContext(ctx).Create(&kp).Error; cerr != nil {
				return nil, errcode.EInternalServer
			}
		} else if qerr != nil {
			return nil, errcode.EInternalServer
		}
		add(kp.ID)
	}

	if len(resolved) == 0 {
		return nil, errcode.EKnowledgePointNotFound
	}
	if len(resolved) > 10 {
		return nil, errcode.EKnowledgePointMax
	}

	// 校验全部存在（覆盖显式传入的 int id）
	var existing []model.KnowledgePoint
	if err := s.db.WithContext(ctx).Where("id IN ?", resolved).Find(&existing).Error; err != nil {
		return nil, errcode.EInternalServer
	}
	if len(existing) != len(resolved) {
		return nil, errcode.EKnowledgePointNotFound
	}

	return resolved, nil
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
	fillTotalReviewRounds(question)
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

	fillTotalReviewRoundsBatch(result.List)
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
	OcrText           *string                `json:"ocr_text"`
	OcrConfirmed      *bool                  `json:"ocr_confirmed"`
	MyAnswer          *string                `json:"my_answer"`
	CorrectAnswer     *string                `json:"correct_answer"`
	SolutionSteps     []string               `json:"solution_steps"`
	ErrorStepIndex    *int                   `json:"error_step_index"`
	ErrorCategory     *string                `json:"error_category"`
	SubCategories     []string               `json:"sub_categories"`
	KnowledgePointIDs []int                  `json:"knowledge_point_ids"`
	KnowledgePoints   []KnowledgePointInput  `json:"knowledge_points"`
	CustomTags        []string               `json:"custom_tags"`
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
	// SubCategories 多选语义：nil（JSON 缺省）→ 不更新；显式 [] → 清空
	if req.SubCategories != nil {
		question.SubCategories = model.JSONBFromSlice(req.SubCategories)
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

	fillTotalReviewRounds(question)
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
	// 先删 DB（含关联知识点），成功后再清理 MinIO 图片，避免"图删了题还在"的不一致
	if err := s.questionRepo.PermanentDelete(ctx, id); err != nil {
		return errcode.EInternalServer
	}
	s.deleteImageBestEffort(ctx, question.ImageURL, fmt.Sprintf("永久删除错题 %d", id))
	return nil
}

// ListRecycleBin 回收站列表
func (s *QuestionService) ListRecycleBin(ctx context.Context, userID int64, page, pageSize int) (*ListResult, error) {
	result, err := s.questionRepo.ListRecycleBin(ctx, userID, page, pageSize)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	fillTotalReviewRoundsBatch(result.List)
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
	// 先取回收站图片 URL（DB 删除后即丢失），DB 删除成功后再清理图片，保证一致性
	var urls []string
	if s.imageDeleter != nil {
		urls, _ = s.questionRepo.ListDeletedImageURLs(ctx, userID)
	}
	count, err := s.questionRepo.ClearRecycleBin(ctx, userID)
	if err != nil {
		return 0, err
	}
	for _, u := range urls {
		s.deleteImageBestEffort(ctx, u, "清空回收站")
	}
	return count, nil
}

func isValidErrorCategory(cat model.ErrorCategory) bool {
	switch cat {
	case model.ErrorKnowledge, model.ErrorSkill, model.ErrorPsychology, model.ErrorHabit, model.ErrorUnknown:
		return true
	default:
		return false
	}
}

// fillTotalReviewRounds 给题目的非持久化字段 TotalReviewRounds 赋值 = 艾宾浩斯总轮次。
// 后端显式返回，避免前端依赖默认值。幂等，可在任何返回题目前调用。
func fillTotalReviewRounds(q *model.Question) {
	if q == nil {
		return
	}
	q.TotalReviewRounds = len(scheduler.EbbinghausIntervals)
}

// fillTotalReviewRoundsBatch 批量版本。
func fillTotalReviewRoundsBatch(qs []model.Question) {
	for i := range qs {
		fillTotalReviewRounds(&qs[i])
	}
}

// fillTotalReviewRoundsPtrs 批量指针版本（复习队列用）。
func fillTotalReviewRoundsPtrs(qs []*model.Question) {
	for _, q := range qs {
		fillTotalReviewRounds(q)
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

	todayCandidates, _ := scheduler.ApplyDailyLimit(candidates, limit)

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
