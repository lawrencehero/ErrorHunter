package handler

import (
	"strconv"
	"strings"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
)

// QuestionHandler 错题处理器
type QuestionHandler struct {
	questionService *service.QuestionService
}

func NewQuestionHandler(questionService *service.QuestionService) *QuestionHandler {
	return &QuestionHandler{questionService: questionService}
}

// List 获取错题列表
// GET /questions
func (h *QuestionHandler) List(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// 解析查询参数
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	// 越界保护：page<1 会让 offset 变成负数，pageSize<=0 会让 LIMIT 异常；
	// pageSize 过大拖垮 DB。统一钳制到合法区间。
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}
	if pageSize > 50 {
		pageSize = 50
	}

	// 搜索关键词：前端 searchQuestions 发的是 `q`，列表筛选也可能传 `keyword`，
	// 两者都接受，`q` 优先（更贴近搜索语义），避免前端搜不到结果。
	keyword := c.Query("q")
	if keyword == "" {
		keyword = c.Query("keyword")
	}

	filter := service.ListFilter{
		Page:     page,
		PageSize: pageSize,
		Keyword:  keyword,
		SortBy:   c.DefaultQuery("sort_by", "created_at"),
		SortOrder: c.DefaultQuery("sort_order", "desc"),
	}

	// 状态筛选
	if status := c.Query("status"); status != "" {
		filter.Status = strings.Split(status, ",")
	}

	// 错因筛选
	if cat := c.Query("error_category"); cat != "" {
		filter.ErrorCategory = &cat
	}

	// 知识点筛选
	if kpID := c.Query("knowledge_point_id"); kpID != "" {
		id, _ := strconv.Atoi(kpID)
		filter.KnowledgePointID = &id
	}

	// 日期筛选
	if startDate := c.Query("start_date"); startDate != "" {
		filter.StartDate = &startDate
	}
	if endDate := c.Query("end_date"); endDate != "" {
		filter.EndDate = &endDate
	}

	// 自定义标签筛选
	if tag := c.Query("tag"); tag != "" {
		filter.Tag = &tag
	}

	result, err := h.questionService.List(c.Request.Context(), userID, filter)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, result)
}

// GetTags 获取当前用户错题的去重自定义标签列表
// GET /questions/tags
func (h *QuestionHandler) GetTags(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	tags, err := h.questionService.ListTags(c.Request.Context(), userID)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, gin.H{"tags": tags})
}

// Create 创建错题
// POST /questions
func (h *QuestionHandler) Create(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	var req service.CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	// 至少一个知识点（knowledge_point_ids 或 knowledge_points）
	if len(req.KnowledgePointIDs) == 0 && len(req.KnowledgePoints) == 0 {
		respondError(c, errcode.EParamValidation.WithData("knowledge_point_ids or knowledge_points is required"))
		return
	}

	question, err := h.questionService.Create(c.Request.Context(), userID, req)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondCreated(c, question)
}

// GetByID 获取错题详情
// GET /questions/:id
func (h *QuestionHandler) GetByID(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	question, err := h.questionService.GetByID(c.Request.Context(), id, userID)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, question)
}

// Update 更新错题
// PUT /questions/:id
func (h *QuestionHandler) Update(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	var req service.UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	question, err := h.questionService.Update(c.Request.Context(), id, userID, req)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, question)
}

// Delete 软删除错题
// DELETE /questions/:id
func (h *QuestionHandler) Delete(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	if err := h.questionService.SoftDelete(c.Request.Context(), id, userID); err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, gin.H{"message": "删除成功，30天内可在回收站恢复"})
}

// ListRecycleBin 回收站列表
// GET /questions/recycle-bin
func (h *QuestionHandler) ListRecycleBin(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	// 越界保护，与 List 一致
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}
	if pageSize > 50 {
		pageSize = 50
	}

	result, err := h.questionService.ListRecycleBin(c.Request.Context(), userID, page, pageSize)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, result)
}

// Restore 恢复错题
// POST /questions/:id/restore
func (h *QuestionHandler) Restore(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	if err := h.questionService.Restore(c.Request.Context(), id, userID); err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, gin.H{"message": "恢复成功"})
}

// PermanentDelete 永久删除
// DELETE /questions/:id/permanent
func (h *QuestionHandler) PermanentDelete(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	if err := h.questionService.PermanentDelete(c.Request.Context(), id, userID); err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, gin.H{"message": "永久删除成功"})
}

// ClearRecycleBin 清空回收站
// DELETE /questions/recycle-bin/clear
func (h *QuestionHandler) ClearRecycleBin(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// 需要二次确认
	var req struct {
		Confirm bool `json:"confirm"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || !req.Confirm {
		respondError(c, errcode.ERecycleBinConfirm)
		return
	}

	count, err := h.questionService.ClearRecycleBin(c.Request.Context(), userID)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, gin.H{"deleted_count": count})
}
