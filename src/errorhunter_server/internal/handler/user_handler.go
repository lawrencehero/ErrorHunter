package handler

import (
	"unicode/utf8"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/gin-gonic/gin"
)

// UserHandler 用户处理器
type UserHandler struct {
	userRepo *repository.UserRepository
}

func NewUserHandler(userRepo *repository.UserRepository) *UserHandler {
	return &UserHandler{userRepo: userRepo}
}

// GetMe 获取当前用户信息
// GET /users/me
func (h *UserHandler) GetMe(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	user, err := h.userRepo.FindByID(c.Request.Context(), userID)
	if err != nil {
		respondError(c, errcode.EUserNotFound)
		return
	}

	storagePercent := float64(user.StorageUsed) / float64(user.StorageLimit) * 100

	respondSuccess(c, gin.H{
		"id":                   user.ID,
		"phone":                user.MaskPhone(),
		"nickname":             user.Nickname,
		"avatar_url":           user.AvatarURL,
		"grade":                user.Grade,
		"storage_used":         user.StorageUsed,
		"storage_limit":        user.StorageLimit,
		"storage_percent":      storagePercent,
		"streak_days":          user.StreakDays,
		"review_reminder_time": user.ReviewReminderTime,
		"reminder_enabled":     user.ReminderEnabled,
		"mastered_animation":   user.MasteredAnimation,
		"daily_review_limit":   user.DailyReviewLimit,
		"created_at":           user.CreatedAt,
	})
}

// UpdateSettingsRequest 更新设置请求
type UpdateSettingsRequest struct {
	Nickname           *string `json:"nickname"`
	AvatarURL          *string `json:"avatar_url"`
	Grade              *string `json:"grade"`
	ReviewReminderTime *string `json:"review_reminder_time"`
	ReminderEnabled    *bool   `json:"reminder_enabled"`
	MasteredAnimation  *bool   `json:"mastered_animation"`
	DailyReviewLimit   *int    `json:"daily_review_limit"`
}

// UpdateSettings 更新用户设置
// PUT /users/me/settings
func (h *UserHandler) UpdateSettings(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	var req UpdateSettingsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	user, err := h.userRepo.FindByID(c.Request.Context(), userID)
	if err != nil {
		respondError(c, errcode.EUserNotFound)
		return
	}

	// 应用更新
	if req.Nickname != nil {
		nickLen := utf8.RuneCountInString(*req.Nickname)
		if nickLen < 2 || nickLen > 12 {
			respondError(c, errcode.ENicknameInvalid)
			return
		}
		user.Nickname = req.Nickname
	}
	if req.AvatarURL != nil {
		user.AvatarURL = req.AvatarURL
	}
	if req.ReviewReminderTime != nil {
		user.ReviewReminderTime = *req.ReviewReminderTime
	}
	if req.ReminderEnabled != nil {
		user.ReminderEnabled = *req.ReminderEnabled
	}
	if req.MasteredAnimation != nil {
		user.MasteredAnimation = *req.MasteredAnimation
	}
	if req.DailyReviewLimit != nil {
		if *req.DailyReviewLimit < 10 || *req.DailyReviewLimit > 30 {
			respondError(c, errcode.EDailyLimitInvalid)
			return
		}
		user.DailyReviewLimit = *req.DailyReviewLimit
	}

	if err := h.userRepo.Update(c.Request.Context(), user); err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, gin.H{"message": "设置已更新"})
}

// Deactivate 注销账号
// POST /users/me/deactivate
func (h *UserHandler) Deactivate(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// 需要确认
	var req struct {
		Confirm bool `json:"confirm"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || !req.Confirm {
		respondError(c, errcode.New(errcode.ErrParamValidation, "请确认注销操作", 400))
		return
	}

	if err := h.userRepo.SoftDelete(c.Request.Context(), userID); err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, gin.H{"message": "账号已注销"})
}
