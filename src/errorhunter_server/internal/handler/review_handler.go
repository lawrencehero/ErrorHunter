package handler

import (
	"strconv"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
)

// ReviewHandler 复习处理器
type ReviewHandler struct {
	reviewService *service.ReviewService
	userRepo      *repository.UserRepository
}

func NewReviewHandler(reviewService *service.ReviewService, userRepo *repository.UserRepository) *ReviewHandler {
	return &ReviewHandler{reviewService: reviewService, userRepo: userRepo}
}

// GetQueue 获取今日复习队列
// GET /reviews/queue
func (h *ReviewHandler) GetQueue(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// 从用户设置读取每日复习上限（users.daily_review_limit，10-30）。
	// 原实现硬编码 20，导致用户在「我的-设置」里改了上限后复习队列不生效，
	// 且与 dashboard 的 overflow_count（用 user.DailyReviewLimit 算）口径不一致。
	// 取不到用户（已软删等）时回退 20，保持原有兜底行为不回归。
	dailyLimit := 20
	if user, err := h.userRepo.FindByID(c.Request.Context(), userID); err == nil {
		if user.DailyReviewLimit >= 10 && user.DailyReviewLimit <= 30 {
			dailyLimit = user.DailyReviewLimit
		}
	}

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
	// 越界保护：page<1 → offset 负数；pageSize<=0 → LIMIT 异常。
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

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
