package middleware

import (
	"context"
	"fmt"
	"strings"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	jwtPkg "github.com/errorhunter/errorhunter-server/internal/pkg/jwt"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

const (
	ContextKeyUserID = "user_id"
	HeaderAuth       = "Authorization"
	BearerPrefix     = "Bearer "
)

// Auth JWT认证中间件
func Auth(jwtMgr *jwtPkg.Manager, redisClient *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader(HeaderAuth)
		if authHeader == "" {
			handleAuthError(c, errcode.EUnauthorized)
			return
		}

		if !strings.HasPrefix(authHeader, BearerPrefix) {
			handleAuthError(c, errcode.EUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, BearerPrefix)
		claims, err := jwtMgr.ParseAccessToken(tokenString)
		if err != nil {
			if err == jwtPkg.ErrExpiredToken {
				handleAuthError(c, errcode.ERefreshTokenExpired)
			} else {
				handleAuthError(c, errcode.EUnauthorized)
			}
			return
		}

		// 检查token是否在黑名单中（已登出的token）
		if redisClient != nil {
			blacklistKey := fmt.Sprintf("token:blacklist:%d:%d", claims.UserID, claims.ExpiresAt.Unix())
			exists, _ := redisClient.Exists(context.Background(), blacklistKey).Result()
			if exists > 0 {
				handleAuthError(c, errcode.EUnauthorized)
				return
			}
		}

		c.Set(ContextKeyUserID, claims.UserID)
		c.Next()
	}
}

// OptionalAuth 可选认证中间件（不强制要求登录）
func OptionalAuth(jwtMgr *jwtPkg.Manager, redisClient *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader(HeaderAuth)
		if authHeader == "" {
			c.Next()
			return
		}

		if strings.HasPrefix(authHeader, BearerPrefix) {
			tokenString := strings.TrimPrefix(authHeader, BearerPrefix)
			claims, err := jwtMgr.ParseAccessToken(tokenString)
			if err == nil {
				// 检查黑名单
				if redisClient != nil {
					blacklistKey := fmt.Sprintf("token:blacklist:%d:%d", claims.UserID, claims.ExpiresAt.Unix())
					exists, _ := redisClient.Exists(context.Background(), blacklistKey).Result()
					if exists > 0 {
						c.Next()
						return
					}
				}
				c.Set(ContextKeyUserID, claims.UserID)
			}
		}

		c.Next()
	}
}

func handleAuthError(c *gin.Context, appErr *errcode.AppError) {
	c.AbortWithStatusJSON(appErr.HTTPStatus, gin.H{
		"code":    appErr.Code,
		"message": appErr.Message,
		"data":    nil,
	})
}

// GetUserID 从上下文获取用户ID
func GetUserID(c *gin.Context) int64 {
	userID, exists := c.Get(ContextKeyUserID)
	if !exists {
		return 0
	}
	id, ok := userID.(int64)
	if !ok {
		return 0
	}
	return id
}
