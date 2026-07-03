package service

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	jwtPkg "github.com/errorhunter/errorhunter-server/internal/pkg/jwt"
	"github.com/errorhunter/errorhunter-server/internal/pkg/sms"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/redis/go-redis/v9"
)

// AuthService 认证服务
type AuthService struct {
	userRepo    *repository.UserRepository
	redis       *redis.Client
	jwtMgr      *jwtPkg.Manager
	otpConfig   config.OTPConfig
	smsProvider sms.Provider
}

func NewAuthService(
	userRepo *repository.UserRepository,
	redisClient *redis.Client,
	jwtMgr *jwtPkg.Manager,
	otpConfig config.OTPConfig,
	smsProvider sms.Provider,
) *AuthService {
	return &AuthService{
		userRepo:    userRepo,
		redis:       redisClient,
		jwtMgr:      jwtMgr,
		otpConfig:   otpConfig,
		smsProvider: smsProvider,
	}
}

// normalizePhone 归一化手机号：去空格、去前缀 "+" 与 "86"，便于白名单比对
func normalizePhone(phone string) string {
	p := strings.TrimSpace(phone)
	p = strings.TrimPrefix(p, "+")
	if len(p) > 11 && strings.HasPrefix(p, "86") {
		p = strings.TrimPrefix(p, "86")
	}
	return p
}

// isBypassPhone 是否为验证码白名单手机号（任意验证码可通过，跳过真实短信）
func (s *AuthService) isBypassPhone(phone string) bool {
	target := normalizePhone(phone)
	if target == "" {
		return false
	}
	for _, p := range s.otpConfig.BypassPhones {
		if normalizePhone(p) == target {
			return true
		}
	}
	return false
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
// 使用阿里云号码认证服务（Dypnsapi），验证码由阿里云自动生成和托管
func (s *AuthService) SendOTP(ctx context.Context, req SendOTPRequest) (*SendOTPResponse, error) {
	// 白名单号码：跳过真实短信发送，验证时任意码可通过
	if s.isBypassPhone(req.Phone) {
		log.Printf("[INFO] OTP bypass (whitelist) for %s, skip SMS send", req.Phone)
		return &SendOTPResponse{
			ExpireIn:    int(s.otpConfig.Expire),
			ResendAfter: s.otpConfig.ResendInterval,
		}, nil
	}

	// 检查每日限制（安全兜底，Dypnsapi 自带频率限制）
	dailyKey := fmt.Sprintf("otp:daily:%s", req.Phone)
	dailyCount, _ := s.redis.Get(ctx, dailyKey).Int()
	if dailyCount >= s.otpConfig.DailyLimit {
		return nil, errcode.ESendCodeDailyLimit
	}

	// 发送验证码（阿里云自动生成 + 短信发送 + 托管存储）
	if err := s.smsProvider.SendCode(ctx, req.Phone); err != nil {
		log.Printf("[WARN] SMS send failed for %s: %v", req.Phone, err)
		return nil, errcode.EInternalServer
	}

	// 增加每日计数
	s.redis.Incr(ctx, dailyKey)
	s.redis.Expire(ctx, dailyKey, 24*time.Hour)

	return &SendOTPResponse{
		ExpireIn:    int(s.otpConfig.Expire),
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

// VerifyOTPResult 验证验证码结果。
//   - AuthResponse != nil：已登录（老用户）。
//   - NeedProfile=true：新用户验证码已通过，需前端补全年级+协议后调 /auth/register；
//     RegistrationToken 为一次性注册凭证（5 分钟）。验证码仅在此校验一次，不重复消费
//     （阿里云 CheckSmsVerifyCode 成功即消费，故新用户不在 Register 中二次校验）。
type VerifyOTPResult struct {
	AuthResponse      *AuthResponse
	NeedProfile       bool
	RegistrationToken string
}

// VerifyOTP 验证验证码：新老用户统一先校验一次验证码，通过后区分：
//   - 老用户：直接签发登录令牌。
//   - 新用户：签发注册凭证，告知前端补全年级+协议（验证码不重复校验）。
//
// 注册/登录入口合一：用户无需也不应在前端自选"登录/注册"，由手机号是否存在决定。
func (s *AuthService) VerifyOTP(ctx context.Context, req VerifyOTPRequest) (*VerifyOTPResult, error) {
	// 1. 校验验证码（新老用户统一走一次）
	if s.isBypassPhone(req.Phone) {
		log.Printf("[INFO] OTP bypass (whitelist) for %s, any code accepted", req.Phone)
	} else {
		valid, err := s.smsProvider.VerifyCode(ctx, req.Phone, req.Code)
		if err != nil {
			log.Printf("[WARN] SMS verify failed for %s: %v", req.Phone, err)
			return nil, errcode.EInternalServer
		}
		if !valid {
			return nil, errcode.EVerifyCodeInvalid
		}
	}

	// 2. 区分新老用户
	existing, _ := s.userRepo.FindByPhone(ctx, req.Phone)
	if existing != nil {
		// 老用户 → 登录
		if existing.DeletedAt != nil {
			return nil, errcode.EAccountDeleted
		}
		s.userRepo.UpdateLastActive(ctx, existing.ID)
		resp, err := s.buildAuthResponse(ctx, existing)
		if err != nil {
			return nil, err
		}
		return &VerifyOTPResult{AuthResponse: resp}, nil
	}

	// 3. 新用户 → 签发注册凭证，告知前端补全资料
	regToken, err := s.jwtMgr.GenerateRegistrationToken(req.Phone)
	if err != nil {
		log.Printf("[WARN] generate registration token failed for %s: %v", req.Phone, err)
		return nil, errcode.EInternalServer
	}
	log.Printf("[INFO] new user %s verified, registration token issued", req.Phone)
	return &VerifyOTPResult{NeedProfile: true, RegistrationToken: regToken}, nil
}

// RegisterRequest 补全注册资料请求（验证码已通过，凭 registration_token 建号）。
type RegisterRequest struct {
	RegistrationToken string `json:"registration_token" binding:"required"`
	Grade             string `json:"grade" binding:"required"`
	AgreementAccepted bool   `json:"agreement_accepted"`
	Nickname          string `json:"nickname,omitempty"`
}

// Register 凭注册凭证补全年级+协议并创建用户，返回登录态。
//   - 凭证无效/过期 → EInvalidRegistrationToken
//   - 凭证对应手机号已注册（凭证重放/重复提交）→ 幂等，直接登录
//   - 未勾选协议 → EAgreementRequired（协议仅新用户注册时要求，老用户不涉及）
//   - 年级/昵称非法 → 复用 registerUser 的 errcode
func (s *AuthService) Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error) {
	// 1. 校验注册凭证
	claims, err := s.jwtMgr.ParseRegistrationToken(req.RegistrationToken)
	if err != nil {
		return nil, errcode.EInvalidRegistrationToken
	}
	phone := claims.Phone

	// 2. 凭证对应手机号已注册 → 幂等直接登录（防凭证重放/重复提交）
	if existing, _ := s.userRepo.FindByPhone(ctx, phone); existing != nil {
		if existing.DeletedAt != nil {
			return nil, errcode.EAccountDeleted
		}
		s.userRepo.UpdateLastActive(ctx, existing.ID)
		return s.buildAuthResponse(ctx, existing)
	}

	// 3. 协议勾选校验（仅新用户注册时要求）
	if !req.AgreementAccepted {
		return nil, errcode.EAgreementRequired
	}

	// 4. 校验年级 + 建用户（复用 registerUser：年级映射、昵称校验、Create）
	user, err := s.registerUser(ctx, VerifyOTPRequest{Phone: phone, Grade: req.Grade, Nickname: req.Nickname})
	if err != nil {
		return nil, err
	}

	// 5. 签发登录态
	return s.buildAuthResponse(ctx, user)
}

// buildAuthResponse 为已存在用户签发令牌对并写 refresh token 到 Redis。
func (s *AuthService) buildAuthResponse(ctx context.Context, user *model.User) (*AuthResponse, error) {
	accessToken, refreshToken, err := s.jwtMgr.GenerateTokenPair(user.ID)
	if err != nil {
		return nil, errcode.EInternalServer
	}
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
	// 将前端年级数字映射为数据库 enum 值
	dbGrade, err := mapFrontendGrade(req.Grade)
	if err != nil {
		return nil, errcode.EParamValidation
	}

	// 创建新用户
	nickname := req.Nickname
	if nickname == "" {
		nickname = fmt.Sprintf("用户%s", req.Phone[7:])
	} else {
		// 昵称长度校验（按 Unicode 字符数，与 user_handler 保持一致）
		nickLen := utf8.RuneCountInString(nickname)
		if nickLen < 2 || nickLen > 12 {
			return nil, errcode.ENicknameInvalid
		}
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
func (s *AuthService) Logout(ctx context.Context, userID int64, accessToken string) error {
	// 删除refresh token
	refreshKey := fmt.Sprintf("token:refresh:%d", userID)
	s.redis.Del(ctx, refreshKey)

	// 将access token加入黑名单，TTL为token剩余有效期
	if accessToken != "" {
		claims, err := s.jwtMgr.ParseAccessToken(accessToken)
		if err == nil && claims.ExpiresAt != nil {
			remaining := time.Until(claims.ExpiresAt.Time)
			if remaining > 0 {
				blacklistKey := fmt.Sprintf("token:blacklist:%d:%d", claims.UserID, claims.ExpiresAt.Unix())
				if err := s.redis.Set(ctx, blacklistKey, 1, remaining).Err(); err != nil {
					log.Printf("[WARN] Failed to blacklist access token for user %d: %v", userID, err)
				}
			}
		}
	}

	return nil
}

// VerifyDeactivateCode 仅校验注销场景下的短信验证码，不做登录/注册副作用。
//
// 注销是高风险操作（支付宝/微信式体验：先发码→校验码→再注销），
// 复用 VerifyOTP 内部的阿里云校验逻辑，但不创建/登录用户、不签发 token。
// 校验通过返回 nil，失败返回 EVerifyCodeInvalid。
// 白名单号码（otpConfig.BypassPhones）任意码可通过，便于测试。
func (s *AuthService) VerifyDeactivateCode(ctx context.Context, phone, code string) error {
	if s.isBypassPhone(phone) {
		log.Printf("[INFO] OTP bypass (whitelist) for deactivate %s, any code accepted", phone)
		return nil
	}
	valid, err := s.smsProvider.VerifyCode(ctx, phone, code)
	if err != nil {
		log.Printf("[WARN] SMS verify failed (deactivate) for %s: %v", phone, err)
		return errcode.EInternalServer
	}
	if !valid {
		return errcode.EVerifyCodeInvalid
	}
	return nil
}

// RevokeTokens 撤销指定用户的 refresh token 并将 access token 加入黑名单。
// 注销账号时调用，确保注销后该用户已签发的 token 立即失效。
func (s *AuthService) RevokeTokens(ctx context.Context, userID int64, accessToken string) {
	refreshKey := fmt.Sprintf("token:refresh:%d", userID)
	s.redis.Del(ctx, refreshKey)

	if accessToken == "" {
		return
	}
	claims, err := s.jwtMgr.ParseAccessToken(accessToken)
	if err != nil || claims.ExpiresAt == nil {
		return
	}
	remaining := time.Until(claims.ExpiresAt.Time)
	if remaining <= 0 {
		return
	}
	blacklistKey := fmt.Sprintf("token:blacklist:%d:%d", claims.UserID, claims.ExpiresAt.Unix())
	if err := s.redis.Set(ctx, blacklistKey, 1, remaining).Err(); err != nil {
		log.Printf("[WARN] Failed to blacklist access token for user %d: %v", userID, err)
	}
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
