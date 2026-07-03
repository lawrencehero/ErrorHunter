package handler

import (
	"net/http"
	"strings"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
)

// AuthHandler 认证处理器
type AuthHandler struct {
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

// SendOTP 发送验证码
// POST /auth/otp/send
func (h *AuthHandler) SendOTP(c *gin.Context) {
	var req service.SendOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	resp, err := h.authService.SendOTP(c.Request.Context(), req)
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

// VerifyOTP 验证验证码
// POST /auth/otp/verify
//   - 老用户：code=0，data=AuthResponse（登录态）
//   - 新用户：code=10017（ErrRegistrationProfileRequired），data={is_new_user,registration_token}
//     前端据此弹出年级+协议补全页，再调 /auth/register。
func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var req service.VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	result, err := h.authService.VerifyOTP(c.Request.Context(), req)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	if result.NeedProfile {
		c.JSON(http.StatusOK, gin.H{
			"code":    errcode.ErrRegistrationProfileRequired,
			"message": "请补全注册资料",
			"data": gin.H{
				"is_new_user":       true,
				"registration_token": result.RegistrationToken,
			},
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    0,
		"message": "success",
		"data":    result.AuthResponse,
	})
}

// Register 凭注册凭证补全年级+协议并建号
// POST /auth/register
func (h *AuthHandler) Register(c *gin.Context) {
	var req service.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation.WithData(err.Error()))
		return
	}

	resp, err := h.authService.Register(c.Request.Context(), req)
	if err != nil {
		if appErr, ok := err.(*errcode.AppError); ok {
			respondError(c, appErr)
		} else {
			respondError(c, errcode.EInternalServer)
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    0,
		"message": "success",
		"data":    resp,
	})
}

// RefreshToken 刷新令牌
// POST /auth/refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	resp, err := h.authService.RefreshToken(c.Request.Context(), req.RefreshToken)
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

// Logout 登出
// POST /auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// 提取当前access token用于加入黑名单
	var accessToken string
	authHeader := c.GetHeader(middleware.HeaderAuth)
	if strings.HasPrefix(authHeader, middleware.BearerPrefix) {
		accessToken = strings.TrimPrefix(authHeader, middleware.BearerPrefix)
	}

	if err := h.authService.Logout(c.Request.Context(), userID, accessToken); err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, nil)
}
