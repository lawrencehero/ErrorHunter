package handler

import (
	"strconv"
	"strings"

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
// GET /reviews/queue?question_ids=1,2,3
// question_ids 非空时为单题/指定题复习入口：仅返回这些题（不限 due、不限每日上限），
// 供错题详情页"开始复习此题"使用。提交仍走 POST /reviews/result，正常推进艾宾浩斯计划。
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

	// 解析 question_ids（逗号分隔），非法片段忽略。仅单题复习入口使用。
	var questionIDs []int64
	if idsStr := c.Query("question_ids"); idsStr != "" {
		for _, part := range strings.Split(idsStr, ",") {
			part = strings.TrimSpace(part)
			if part == "" {
				continue
			}
			if id, err := strconv.ParseInt(part, 10, 64); err == nil {
				questionIDs = append(questionIDs, id)
			}
		}
	}

	queue, err := h.reviewService.GetReviewQueue(c.Request.Context(), userID, dailyLimit, questionIDs)
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

// GetTodaySummary 获取今日复习汇总
// GET /reviews/today-summary
// 供首页"查看复习"展示今日真实复习结果数据（而非空报告全零）。
func (h *ReviewHandler) GetTodaySummary(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	summary, err := h.reviewService.GetTodaySummary(c.Request.Context(), userID)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	respondSuccess(c, summary)
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
