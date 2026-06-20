package jwt

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newTestManager() *Manager {
	return NewManager(
		"test-access-secret-key-12345",
		"test-refresh-secret-key-67890",
		15*time.Minute,
		7*24*time.Hour,
	)
}

// TestGenerateTokenPair_Success 生成令牌对成功
func TestGenerateTokenPair_Success(t *testing.T) {
	mgr := newTestManager()

	access, refresh, err := mgr.GenerateTokenPair(100)
	require.NoError(t, err)
	assert.NotEmpty(t, access)
	assert.NotEmpty(t, refresh)
	assert.NotEqual(t, access, refresh)
}

// TestParseAccessToken_Valid 解析有效访问令牌
func TestParseAccessToken_Valid(t *testing.T) {
	mgr := newTestManager()
	userID := int64(42)

	token, err := mgr.GenerateAccessToken(userID)
	require.NoError(t, err)

	claims, err := mgr.ParseAccessToken(token)
	require.NoError(t, err)
	assert.Equal(t, userID, claims.UserID)
	assert.Equal(t, "errorhunter", claims.Issuer)
}

// TestParseRefreshToken_Valid 解析有效刷新令牌
func TestParseRefreshToken_Valid(t *testing.T) {
	mgr := newTestManager()
	userID := int64(99)

	token, err := mgr.GenerateRefreshToken(userID)
	require.NoError(t, err)

	claims, err := mgr.ParseRefreshToken(token)
	require.NoError(t, err)
	assert.Equal(t, userID, claims.UserID)
}

// TestParseAccessToken_Expired 过期令牌返回错误
func TestParseAccessToken_Expired(t *testing.T) {
	mgr := NewManager("secret", "refresh-secret", -1*time.Hour, 7*24*time.Hour)

	token, err := mgr.GenerateAccessToken(1)
	require.NoError(t, err)

	_, err = mgr.ParseAccessToken(token)
	assert.ErrorIs(t, err, ErrExpiredToken)
}

// TestParseAccessToken_InvalidSignature 错误签名返回无效
func TestParseAccessToken_InvalidSignature(t *testing.T) {
	mgr1 := NewManager("secret-1", "refresh-1", 15*time.Minute, 7*24*time.Hour)
	mgr2 := NewManager("secret-2", "refresh-2", 15*time.Minute, 7*24*time.Hour)

	token, err := mgr1.GenerateAccessToken(1)
	require.NoError(t, err)

	_, err = mgr2.ParseAccessToken(token)
	assert.ErrorIs(t, err, ErrInvalidToken)
}

// TestParseAccessToken_WrongTokenType 用 access secret 解析 refresh token 应失败
func TestParseAccessToken_WrongTokenType(t *testing.T) {
	mgr := newTestManager()

	refreshToken, err := mgr.GenerateRefreshToken(1)
	require.NoError(t, err)

	// 用 ParseAccessToken（使用 access secret）解析 refresh token 应失败
	_, err = mgr.ParseAccessToken(refreshToken)
	assert.Error(t, err)
}

// TestParseAccessToken_MalformedToken 畸形 token 返回错误
func TestParseAccessToken_MalformedToken(t *testing.T) {
	mgr := newTestManager()

	_, err := mgr.ParseAccessToken("not.a.valid.token")
	assert.Error(t, err)
}

// TestGetExpireDurations 验证获取过期时间
func TestGetExpireDurations(t *testing.T) {
	mgr := newTestManager()

	assert.Equal(t, 15*time.Minute, mgr.GetAccessExpire())
	assert.Equal(t, 7*24*time.Hour, mgr.GetRefreshExpire())
}

// TestGenerateTokenPair_DifferentUsers 不同用户生成的 token 不同
func TestGenerateTokenPair_DifferentUsers(t *testing.T) {
	mgr := newTestManager()

	access1, _, _ := mgr.GenerateTokenPair(1)
	access2, _, _ := mgr.GenerateTokenPair(2)

	assert.NotEqual(t, access1, access2)
}
