package jwt

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrExpiredToken = errors.New("token expired")
)

type Claims struct {
	UserID int64 `json:"user_id"`
	jwt.RegisteredClaims
}

// RegClaims 注册凭证声明：验证码校验通过后签发，用于 /auth/register 补全资料建号。
// 与登录态 Claims 区分：用 Phone + Subject="registration" 标识，复用 accessSecret 签名，
// 短时效（5 分钟），一次性消费（建号后手机号即存在，重放会被 Register 视为"已注册→登录"）。
type RegClaims struct {
	Phone string `json:"phone"`
	jwt.RegisteredClaims
}

type Manager struct {
	accessSecret  []byte
	refreshSecret []byte
	accessExpire  time.Duration
	refreshExpire time.Duration
}

func NewManager(accessSecret, refreshSecret string, accessExpire, refreshExpire time.Duration) *Manager {
	return &Manager{
		accessSecret:  []byte(accessSecret),
		refreshSecret: []byte(refreshSecret),
		accessExpire:  accessExpire,
		refreshExpire: refreshExpire,
	}
}

// GenerateAccessToken 生成访问令牌
func (m *Manager) GenerateAccessToken(userID int64) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(m.accessExpire)),
			Issuer:    "errorhunter",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.accessSecret)
}

// GenerateRefreshToken 生成刷新令牌
func (m *Manager) GenerateRefreshToken(userID int64) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(m.refreshExpire)),
			Issuer:    "errorhunter",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.refreshSecret)
}

// GenerateTokenPair 生成令牌对
func (m *Manager) GenerateTokenPair(userID int64) (accessToken, refreshToken string, err error) {
	accessToken, err = m.GenerateAccessToken(userID)
	if err != nil {
		return "", "", err
	}
	refreshToken, err = m.GenerateRefreshToken(userID)
	if err != nil {
		return "", "", err
	}
	return accessToken, refreshToken, nil
}

// GenerateRegistrationToken 生成注册凭证（验证码已通过后签发，5 分钟有效）。
func (m *Manager) GenerateRegistrationToken(phone string) (string, error) {
	now := time.Now()
	claims := RegClaims{
		Phone: phone,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(5 * time.Minute)),
			Issuer:    "errorhunter",
			Subject:   "registration",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.accessSecret)
}

// ParseRegistrationToken 解析注册凭证，校验签名、有效期与 Subject。
func (m *Manager) ParseRegistrationToken(tokenString string) (*RegClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &RegClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return m.accessSecret, nil
	})
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrExpiredToken
		}
		return nil, ErrInvalidToken
	}
	claims, ok := token.Claims.(*RegClaims)
	if !ok || !token.Valid || claims.Subject != "registration" {
		return nil, ErrInvalidToken
	}
	return claims, nil
}

// ParseAccessToken 解析访问令牌
func (m *Manager) ParseAccessToken(tokenString string) (*Claims, error) {
	return m.parseToken(tokenString, m.accessSecret)
}

// ParseRefreshToken 解析刷新令牌
func (m *Manager) ParseRefreshToken(tokenString string) (*Claims, error) {
	return m.parseToken(tokenString, m.refreshSecret)
}

func (m *Manager) parseToken(tokenString string, secret []byte) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return secret, nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrExpiredToken
		}
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrInvalidToken
	}

	return claims, nil
}

// GetAccessExpire 获取访问令牌过期时间
func (m *Manager) GetAccessExpire() time.Duration {
	return m.accessExpire
}

// GetRefreshExpire 获取刷新令牌过期时间
func (m *Manager) GetRefreshExpire() time.Duration {
	return m.refreshExpire
}
