package service

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	jwtPkg "github.com/errorhunter/errorhunter-server/internal/pkg/jwt"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/redis/go-redis/v9"
)

// AuthService 认证服务
type AuthService struct {
	userRepo    *repository.UserRepository
	redis       *redis.Client
	jwtMgr      *jwtPkg.Manager
	otpConfig   config.OTPConfig
}

func NewAuthService(
	userRepo *repository.UserRepository,
	redisClient *redis.Client,
	jwtMgr *jwtPkg.Manager,
	otpConfig config.OTPConfig,
) *AuthService {
	return &AuthService{
		userRepo:  userRepo,
		redis:     redisClient,
		jwtMgr:    jwtMgr,
		otpConfig: otpConfig,
	}
}

// SendOTPRequest 发送验证码请求
type SendOTPRequest struct {
	Phone string `json:"phone" binding:"required"`
	Scene string `json:"scene" binding:"required"` // REGISTER, LOGIN
}

// SendOTPResponse 发送验证码响应
type SendOTPResponse struct {
	ExpireIn    int `json:"expire_in"`
	ResendAfter int `json:"resend_after"`
}

// SendOTP 发送验证码
func (s *AuthService) SendOTP(ctx context.Context, req SendOTPRequest) (*SendOTPResponse, error) {
	// 检查频率限制
	resendKey := fmt.Sprintf("otp:resend:%s", req.Phone)
	if exists, _ := s.redis.Exists(ctx, resendKey).Result(); exists > 0 {
		return nil, errcode.ESendCodeTooFrequent
	}

	// 检查每日限制
	dailyKey := fmt.Sprintf("otp:daily:%s", req.Phone)
	dailyCount, _ := s.redis.Get(ctx, dailyKey).Int()
	if dailyCount >= s.otpConfig.DailyLimit {
		return nil, errcode.ESendCodeDailyLimit
	}

	// 生成6位验证码
	code, err := generateOTP()
	if err != nil {
		return nil, errcode.EInternalServer
	}

	// 存储验证码到Redis
	otpKey := fmt.Sprintf("otp:code:%s:%s", req.Scene, req.Phone)
	expireDuration := time.Duration(s.otpConfig.Expire) * time.Second
	s.redis.Set(ctx, otpKey, code, expireDuration)

	// 设置重发间隔
	s.redis.Set(ctx, resendKey, 1, time.Duration(s.otpConfig.ResendInterval)*time.Second)

	// 增加每日计数
	s.redis.Incr(ctx, dailyKey)
	s.redis.Expire(ctx, dailyKey, 24*time.Hour)

	// TODO: 实际发送短信（调用短信服务商API）
	// 开发环境打印到日志
	fmt.Printf("[DEV] OTP for %s (%s): %s\n", req.Phone, req.Scene, code)

	return &SendOTPResponse{
		ExpireIn:    s.otpConfig.Expire,
		ResendAfter: s.otpConfig.ResendInterval,
	}, nil
}

// VerifyOTPRequest 验证验证码请求
type VerifyOTPRequest struct {
	Phone      string `json:"phone" binding:"required"`
	Code       string `json:"code" binding:"required"`
	Scene      string `json:"scene" binding:"required"`
	Grade      string `json:"grade,omitempty"`      // 注册时必填
	Nickname   string `json:"nickname,omitempty"`   // 注册时可选
	DeviceName string `json:"device_name,omitempty"` // 登录时必填
	DeviceType string `json:"device_type,omitempty"` // 登录时必填
	PushToken  string `json:"push_token,omitempty"`  // 登录时可选
}

// AuthResponse 认证响应
type AuthResponse struct {
	UserID       int64      `json:"user_id"`
	AccessToken  string     `json:"access_token"`
	RefreshToken string     `json:"refresh_token"`
	ExpiresIn    int        `json:"expires_in"`
	User         *UserInfo  `json:"user"`
}

// UserInfo 用户信息
type UserInfo struct {
	ID                int64  `json:"id"`
	Phone             string `json:"phone"`
	Nickname          string `json:"nickname"`
	Grade             string `json:"grade"`
	AvatarURL         string `json:"avatar_url,omitempty"`
	StreakDays        int    `json:"streak_days"`
	ReminderEnabled   bool   `json:"reminder_enabled"`
	MasteredAnimation bool   `json:"mastered_animation"`
	DailyReviewLimit  int    `json:"daily_review_limit"`
}

// VerifyOTP 验证验证码并返回JWT
func (s *AuthService) VerifyOTP(ctx context.Context, req VerifyOTPRequest) (*AuthResponse, error) {
	// 检查是否被锁定
	lockKey := fmt.Sprintf("otp:lock:%s", req.Phone)
	if exists, _ := s.redis.Exists(ctx, lockKey).Result(); exists > 0 {
		return nil, errcode.EVerifyCodeLocked
	}

	// 验证验证码
	otpKey := fmt.Sprintf("otp:code:%s:%s", req.Scene, req.Phone)
	storedCode, err := s.redis.Get(ctx, otpKey).Result()
	if err == redis.Nil || storedCode != req.Code {
		// 增加错误计数
		retryKey := fmt.Sprintf("otp:retry:%s", req.Phone)
		retryCount, _ := s.redis.Incr(ctx, retryKey).Result()
		s.redis.Expire(ctx, retryKey, time.Duration(s.otpConfig.LockoutDuration)*time.Second)

		if retryCount >= int64(s.otpConfig.MaxRetry) {
			s.redis.Set(ctx, lockKey, 1, time.Duration(s.otpConfig.LockoutDuration)*time.Second)
			return nil, errcode.EVerifyCodeLocked
		}
		return nil, errcode.EVerifyCodeInvalid
	}

	// 删除已使用的验证码
	s.redis.Del(ctx, otpKey)
	s.redis.Del(ctx, fmt.Sprintf("otp:retry:%s", req.Phone))

	var user *model.User

	switch req.Scene {
	case "REGISTER":
		user, err = s.registerUser(ctx, req)
	case "LOGIN":
		user, err = s.loginUser(ctx, req)
	default:
		return nil, errcode.EParamValidation
	}

	if err != nil {
		return nil, err
	}

	// 生成令牌对
	accessToken, refreshToken, err := s.jwtMgr.GenerateTokenPair(user.ID)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	// 存储refresh token到Redis（用于登出撤销）
	refreshKey := fmt.Sprintf("token:refresh:%d", user.ID)
	s.redis.Set(ctx, refreshKey, refreshToken, s.jwtMgr.GetRefreshExpire())

	return &AuthResponse{
		UserID:       user.ID,
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int(s.jwtMgr.GetAccessExpire().Seconds()),
		User:         toUserInfo(user),
	}, nil
}

// mapFrontendGrade 将前端传来的年级数字转换为数据库 enum 值
// 前端: "3"→"31", "4"→"32", "5"→"33", "6"→"34"
//       "7"→"71", "8"→"72", "9"→"73"
func mapFrontendGrade(frontendGrade string) (model.Grade, error) {
	mapping := map[string]model.Grade{
		// 前端数字格式（3-9）
		"3": model.Grade31, // 小学三年级
		"4": model.Grade32, // 小学四年级
		"5": model.Grade33, // 小学五年级
		"6": model.Grade34, // 小学六年级
		"7": model.Grade71, // 初中一年级
		"8": model.Grade72, // 初中二年级
		"9": model.Grade73, // 初中三年级
		// 数据库 enum 格式（直接透传）
		"31": model.Grade31,
		"32": model.Grade32,
		"33": model.Grade33,
		"34": model.Grade34,
		"71": model.Grade71,
		"72": model.Grade72,
		"73": model.Grade73,
	}

	grade, ok := mapping[frontendGrade]
	if !ok {
		return "", fmt.Errorf("invalid grade: %s, must be one of 3-9 or 31-34/71-73", frontendGrade)
	}
	return grade, nil
}

func (s *AuthService) registerUser(ctx context.Context, req VerifyOTPRequest) (*model.User, error) {
	// 检查手机号是否已注册
	existing, _ := s.userRepo.FindByPhone(ctx, req.Phone)
	if existing != nil {
		return nil, errcode.EPhoneAlreadyRegistered
	}

	// 将前端年级数字映射为数据库 enum 值
	dbGrade, err := mapFrontendGrade(req.Grade)
	if err != nil {
		return nil, errcode.EParamValidation
	}

	// 创建新用户
	nickname := req.Nickname
	if nickname == "" {
		nickname = fmt.Sprintf("用户%s", req.Phone[7:])
	}

	user := &model.User{
		Phone:              req.Phone,
		Nickname:           &nickname,
		Grade:              dbGrade,
		StorageUsed:        0,
		StorageLimit:       5368709120, // 5GB
		StreakDays:         0,
		ReviewReminderTime: "19:00:00",
		ReminderEnabled:    true,
		MasteredAnimation:  true,
		DailyReviewLimit:   20,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, errcode.EInternalServer
	}

	return user, nil
}

func (s *AuthService) loginUser(ctx context.Context, req VerifyOTPRequest) (*model.User, error) {
	user, err := s.userRepo.FindByPhone(ctx, req.Phone)
	if err != nil {
		return nil, errcode.EUserNotFound
	}

	if user.DeletedAt != nil {
		return nil, errcode.EAccountDeleted
	}

	// 更新最后活跃时间
	s.userRepo.UpdateLastActive(ctx, user.ID)

	return user, nil
}

// RefreshToken 刷新令牌
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*AuthResponse, error) {
	claims, err := s.jwtMgr.ParseRefreshToken(refreshToken)
	if err != nil {
		return nil, errcode.ERefreshTokenExpired
	}

	// 检查token是否在Redis中（防止已登出的token被使用）
	refreshKey := fmt.Sprintf("token:refresh:%d", claims.UserID)
	storedToken, err := s.redis.Get(ctx, refreshKey).Result()
	if err != nil || storedToken != refreshToken {
		return nil, errcode.ERefreshTokenExpired
	}

	// 获取用户信息
	user, err := s.userRepo.FindByID(ctx, claims.UserID)
	if err != nil {
		return nil, errcode.EUserNotFound
	}

	// 生成新令牌对
	newAccessToken, newRefreshToken, err := s.jwtMgr.GenerateTokenPair(user.ID)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	// 更新Redis中的refresh token
	s.redis.Set(ctx, refreshKey, newRefreshToken, s.jwtMgr.GetRefreshExpire())

	return &AuthResponse{
		UserID:       user.ID,
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		ExpiresIn:    int(s.jwtMgr.GetAccessExpire().Seconds()),
		User:         toUserInfo(user),
	}, nil
}

// Logout 登出
func (s *AuthService) Logout(ctx context.Context, userID int64) error {
	refreshKey := fmt.Sprintf("token:refresh:%d", userID)
	return s.redis.Del(ctx, refreshKey).Err()
}

func generateOTP() (string, error) {
	var code string
	for i := 0; i < 6; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		code += fmt.Sprintf("%d", n.Int64())
	}
	return code, nil
}

func toUserInfo(user *model.User) *UserInfo {
	info := &UserInfo{
		ID:                user.ID,
		Phone:             user.MaskPhone(),
		Grade:             string(user.Grade),
		StreakDays:        user.StreakDays,
		ReminderEnabled:   user.ReminderEnabled,
		MasteredAnimation: user.MasteredAnimation,
		DailyReviewLimit:  user.DailyReviewLimit,
	}
	if user.Nickname != nil {
		info.Nickname = *user.Nickname
	}
	if user.AvatarURL != nil {
		info.AvatarURL = *user.AvatarURL
	}
	return info
}
