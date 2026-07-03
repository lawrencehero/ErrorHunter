package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// ===== SendOTP 发送验证码测试 =====

func TestSendOTP_InvalidBody_Empty(t *testing.T) {
	// 空请求体应返回参数校验错误
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.SendOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestSendOTP_InvalidBody_MissingPhone(t *testing.T) {
	// 缺少phone字段
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.SendOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"scene": "LOGIN",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestSendOTP_InvalidBody_MissingScene(t *testing.T) {
	// 缺少scene字段
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.SendOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"phone": "13800138000",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestSendOTP_InvalidBody_NoBody(t *testing.T) {
	// 无请求体
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.SendOTP)

	w := tc.doRequest("POST", "/test", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== VerifyOTP 验证验证码测试 =====

func TestVerifyOTP_InvalidBody_Empty(t *testing.T) {
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.VerifyOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestVerifyOTP_InvalidBody_MissingCode(t *testing.T) {
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.VerifyOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"phone": "13800138000",
		"scene": "LOGIN",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestVerifyOTP_InvalidBody_MissingPhone(t *testing.T) {
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.VerifyOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"code":  "123456",
		"scene": "LOGIN",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestVerifyOTP_InvalidBody_MissingScene(t *testing.T) {
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.VerifyOTP)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"phone": "13800138000",
		"code":  "123456",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== Register 补全注册资料测试 =====

func TestRegister_InvalidBody_Empty(t *testing.T) {
	// 空请求体应返回参数校验错误
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.Register)

	w := tc.doRequest("POST", "/test", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestRegister_InvalidBody_MissingToken(t *testing.T) {
	// 缺 registration_token
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.Register)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"grade":              "33",
		"agreement_accepted": true,
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestRegister_InvalidBody_MissingGrade(t *testing.T) {
	// 缺 grade
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.Register)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"registration_token":  "some-token",
		"agreement_accepted":  true,
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

// ===== RefreshToken 刷新令牌测试 =====

func TestRefreshToken_MissingField(t *testing.T) {
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.RefreshToken)

	w := tc.doRequest("POST", "/test", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestRefreshToken_EmptyToken(t *testing.T) {
	// refresh_token为空字符串（binding:"required"会拒绝）
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.RefreshToken)

	w := tc.doRequest("POST", "/test", map[string]interface{}{
		"refresh_token": "",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestRefreshToken_NoBody(t *testing.T) {
	h := &AuthHandler{}
	tc := newTestCtx().postRoute("/test", h.RefreshToken)

	w := tc.doRequest("POST", "/test", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== Logout 登出测试 =====

func TestLogout_Unauthorized(t *testing.T) {
	// 未登录用户(userID=0)应返回401
	h := &AuthHandler{}
	router := gin.New()
	router.POST("/logout", h.Logout) // 不设置user_id

	var buf bytes.Buffer
	req, _ := http.NewRequest("POST", "/logout", &buf)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestLogout_Authorized_NilService(t *testing.T) {
	// 已认证但service为nil → 调用Logout时panic(因为authService为nil)
	// 验证handler正确获取了userID并尝试调用service
	h := &AuthHandler{}
	tc := newTestCtx().withUser(1).postRoute("/logout", h.Logout)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "nil service应导致panic，说明handler正确走到了service调用")
	}()

	tc.doRequest("POST", "/logout", nil, map[string]string{
		"Authorization": "Bearer test-token",
	})
}

// ===== AuthHandler 构造函数测试 =====

func TestNewAuthHandler(t *testing.T) {
	h := NewAuthHandler(nil)
	assert.NotNil(t, h)
	assert.Nil(t, h.authService)
}
