package service

import (
	"context"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	jwtPkg "github.com/errorhunter/errorhunter-server/internal/pkg/jwt"
	"github.com/errorhunter/errorhunter-server/internal/pkg/sms"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestGradeMapping_ValidGrades 验证所有有效年级的映射正确性
func TestGradeMapping_ValidGrades(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected model.Grade
	}{
		{"小学三年级", "3", model.Grade31},
		{"小学四年级", "4", model.Grade32},
		{"小学五年级", "5", model.Grade33},
		{"小学六年级", "6", model.Grade34},
		{"初中一年级", "7", model.Grade71},
		{"初中二年级", "8", model.Grade72},
		{"初中三年级", "9", model.Grade73},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			grade, err := mapFrontendGrade(tt.input)
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, grade)
		})
	}
}

// TestGradeMapping_InvalidGrades 验证无效年级返回错误
func TestGradeMapping_InvalidGrades(t *testing.T) {
	invalidInputs := []string{"", "0", "1", "2", "10", "abc", "-1", "3.5"}

	for _, input := range invalidInputs {
		t.Run("invalid_"+input, func(t *testing.T) {
			_, err := mapFrontendGrade(input)
			assert.Error(t, err)
			assert.Contains(t, err.Error(), "invalid grade")
		})
	}
}

// newTestAuthService 构造一个用于单测的 AuthService。
// - userRepo 传 nil（VerifyDeactivateCode/RevokeTokens 不需要它）
// - redis 指向不可达地址：RevokeTokens 里的 Del/Set 会失败但被安全吞掉，不 panic
// - bypassPhones 非空：VerifyDeactivateCode 走白名单分支，跳过真实短信校验
func newTestAuthService(bypass ...string) *AuthService {
	jwtMgr := jwtPkg.NewManager("access-secret", "refresh-secret", 60, 60)
	rc := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1"}) // 不可达，单测仅触发错误路径
	return &AuthService{
		userRepo:    (*repository.UserRepository)(nil),
		redis:       rc,
		jwtMgr:      jwtMgr,
		otpConfig:   config.OTPConfig{Expire: 300, ResendInterval: 60, DailyLimit: 10, BypassPhones: bypass},
		smsProvider: &sms.MockProvider{},
	}
}

// ===== VerifyDeactivateCode 测试 =====

func TestVerifyDeactivateCode_BypassPhone_AnyCodeAccepted(t *testing.T) {
	// 白名单手机号 → 任意验证码通过（不调用短信商）
	s := newTestAuthService("13800138000")

	err := s.VerifyDeactivateCode(context.Background(), "13800138000", "000000")
	assert.NoError(t, err, "白名单手机号任意码应通过")
}

func TestVerifyDeactivateCode_BypassPhone_NormalizedMatch(t *testing.T) {
	// 归一化后匹配白名单（+86 前缀）
	s := newTestAuthService("13800138000")

	err := s.VerifyDeactivateCode(context.Background(), "+8613800138000", "123456")
	assert.NoError(t, err, "归一化后匹配白名单应通过")
}

func TestVerifyDeactivateCode_NonBypass_WrongCode(t *testing.T) {
	// 非白名单 + MockProvider（固定码 888888）→ 错误码返回 EVerifyCodeInvalid
	s := newTestAuthService() // 无白名单

	err := s.VerifyDeactivateCode(context.Background(), "13900139000", "000000")
	require.Error(t, err)
	appErr, ok := err.(*errcode.AppError)
	require.True(t, ok, "应返回 *AppError")
	assert.Equal(t, errcode.ErrVerifyCodeInvalid, appErr.Code)
}

func TestVerifyDeactivateCode_NonBypass_CorrectCode(t *testing.T) {
	// 非白名单 + MockProvider 固定码 888888 → 通过
	s := newTestAuthService()

	err := s.VerifyDeactivateCode(context.Background(), "13900139000", "888888")
	assert.NoError(t, err)
}

// ===== RevokeTokens 测试 =====

func TestRevokeTokens_EmptyAccessToken_NoPanic(t *testing.T) {
	// 空 access token → 只删 refresh key（redis 不可达，Del 失败被吞），不 panic
	s := newTestAuthService("13800138000")

	assert.NotPanics(t, func() {
		s.RevokeTokens(context.Background(), 42, "")
	})
}

func TestRevokeTokens_InvalidAccessToken_NoPanic(t *testing.T) {
	// 无效 access token → ParseAccessToken 失败，直接 return，不 panic
	s := newTestAuthService("13800138000")

	assert.NotPanics(t, func() {
		s.RevokeTokens(context.Background(), 42, "not.a.valid.token")
	})
}

func TestRevokeTokens_ValidAccessToken_NoPanic(t *testing.T) {
	// 有效 access token → 尝试 Set 黑名单（redis 不可达，失败仅 log），不 panic
	s := newTestAuthService("13800138000")
	token, err := s.jwtMgr.GenerateAccessToken(42)
	require.NoError(t, err)

	assert.NotPanics(t, func() {
		s.RevokeTokens(context.Background(), 42, token)
	})
}
