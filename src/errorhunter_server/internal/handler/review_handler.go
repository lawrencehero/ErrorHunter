package handler

import (
	"strconv"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
)

// ReviewHandler 复习处理器
type ReviewHandler struct {
	reviewService *service.ReviewService
}

func NewReviewHandler(reviewService *service.ReviewService) *ReviewHandler {
	return &ReviewHandler{reviewService: reviewService}
}

// GetQueue 获取今日复习队列
// GET /reviews/queue
func (h *ReviewHandler) GetQueue(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// 从用户设置获取每日上限，默认20
	dailyLimit := 20 // TODO: 从用户配置获取

	queue, err := h.reviewService.GetReviewQueue(c.Request.Context(), userID, dailyLimit)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, queue)
}

// SubmitResult 提交复习结果
// POST /reviews/result
func (h *ReviewHandler) SubmitResult(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	var req service.SubmitReviewRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	resp, err := h.reviewService.SubmitReview(c.Request.Context(), userID, req)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, resp)
}

// GetHistory 获取复习历史
// GET /reviews
func (h *ReviewHandler) GetHistory(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	records, total, err := h.reviewService.GetReviewHistory(c.Request.Context(), userID, page, pageSize)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, gin.H{
		"list": records,
		"pagination": gin.H{
			"page":      page,
			"page_size": pageSize,
			"total":     total,
		},
	})
}
