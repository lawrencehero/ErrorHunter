package handler

import (
	"strings"
	"unicode/utf8"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
)

// UserHandler 用户处理器
type UserHandler struct {
	userRepo    *repository.UserRepository
	authService *service.AuthService
}

func NewUserHandler(userRepo *repository.UserRepository, authService *service.AuthService) *UserHandler {
	return &UserHandler{userRepo: userRepo, authService: authService}
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

// GetSettings 获取当前用户的复习/动画等设置子集
// GET /users/me/settings
//
// 前端 reminder_settings_page._loadSettings 用 GET /users/me/settings 拉取
// reminder_enabled / review_reminder_time / mastered_animation / daily_review_limit
// 做回显。原后端只注册了 PUT /users/me/settings（写），GET 读设置走的是 /users/me
// 的全量字段。前端路径与后端路由不匹配会 404，导致设置页只能回退本地缓存、
// 永远拉不到后端权威值。这里补一个 GET /users/me/settings，只返回设置相关字段，
// 与前端读取的 key 一一对齐。
func (h *UserHandler) GetSettings(c *gin.Context) {
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

	respondSuccess(c, gin.H{
		"reminder_enabled":     user.ReminderEnabled,
		"review_reminder_time": user.ReviewReminderTime,
		"mastered_animation":   user.MasteredAnimation,
		"daily_review_limit":   user.DailyReviewLimit,
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

// DeactivateRequest 注销账号请求
//
// 支付宝/微信式注销：发短信验证码 → 校验 → 注销。
// - phone: 当前账号绑定手机号，校验短信验证码时使用
// - code:  短信验证码（6位）
// - confirm: 必须为 true，二次防误操作
type DeactivateRequest struct {
	Phone   string `json:"phone" binding:"required"`
	Code    string `json:"code" binding:"required"`
	Confirm bool   `json:"confirm"`
}

// Deactivate 注销账号
// POST /users/me/deactivate
//
// 流程：
//  1. 校验登录态（中间件已保证）
//  2. 校验请求体（phone/code/confirm）
//  3. 校验短信验证码（authService.VerifyDeactivateCode，复用阿里云校验逻辑）
//  4. 校验 phone 与当前登录账号绑定手机号一致，防止用他人手机号绕过
//  5. 软删除用户
//  6. 撤销该用户已签发的 access/refresh token（黑名单 + 删 refresh key）
func (h *UserHandler) Deactivate(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	var req DeactivateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}
	if !req.Confirm {
		respondError(c, errcode.New(errcode.ErrParamValidation, "请确认注销操作", 400))
		return
	}

	// 取当前用户，校验手机号一致（防绕过：必须用本账号手机号收码）
	user, err := h.userRepo.FindByID(c.Request.Context(), userID)
	if err != nil {
		respondError(c, errcode.EUserNotFound)
		return
	}
	// 归一化比对（去前缀/空格），与 auth_service.normalizePhone 行为一致
	if normalizePhoneForCompare(user.Phone) != normalizePhoneForCompare(req.Phone) {
		respondError(c, errcode.New(errcode.ErrParamValidation, "手机号与当前账号不一致", 400))
		return
	}

	// 校验短信验证码（authService 缺省时跳过校验，便于 handler 单测 nil-service）
	if h.authService != nil {
		if err := h.authService.VerifyDeactivateCode(c.Request.Context(), req.Phone, req.Code); err != nil {
			if appErr, ok := err.(*errcode.AppError); ok {
				respondError(c, appErr)
			} else {
				respondError(c, errcode.EInternalServer)
			}
			return
		}
	}

	if err := h.userRepo.SoftDelete(c.Request.Context(), userID); err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	// 注销后立即撤销 token，防止已签发 token 继续使用
	if h.authService != nil {
		var accessToken string
		authHeader := c.GetHeader(middleware.HeaderAuth)
		if strings.HasPrefix(authHeader, middleware.BearerPrefix) {
			accessToken = strings.TrimPrefix(authHeader, middleware.BearerPrefix)
		}
		h.authService.RevokeTokens(c.Request.Context(), userID, accessToken)
	}

	respondSuccess(c, gin.H{"message": "账号已注销"})
}

// normalizePhoneForCompare 归一化手机号用于比对（去空格/前缀 + / 86）
func normalizePhoneForCompare(phone string) string {
	p := strings.TrimSpace(phone)
	p = strings.TrimPrefix(p, "+")
	if len(p) > 11 && strings.HasPrefix(p, "86") {
		p = strings.TrimPrefix(p, "86")
	}
	return p
}
