package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
)

// RateLimiter 简单内存限流器（生产环境应使用Redis）
type RateLimiter struct {
	mu       sync.Mutex
	requests map[string][]time.Time
	limit    int
	window   time.Duration
}

// NewRateLimiter 创建限流器
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		requests: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}
}

// RateLimit 限流中间件
func (r *RateLimiter) RateLimit() gin.HandlerFunc {
	return func(c *gin.Context) {
		key := c.ClientIP()

		r.mu.Lock()
		now := time.Now()
		windowStart := now.Add(-r.window)

		// 清理过期记录
		requests := r.requests[key]
		validRequests := make([]time.Time, 0, len(requests))
		for _, t := range requests {
			if t.After(windowStart) {
				validRequests = append(validRequests, t)
			}
		}

		if len(validRequests) >= r.limit {
			r.requests[key] = validRequests
			r.mu.Unlock()
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"code":    errcode.ErrRateLimited,
				"message": errcode.ERateLimited.Message,
				"data":    nil,
			})
			return
		}

		r.requests[key] = append(validRequests, now)
		r.mu.Unlock()

		c.Next()
	}
}

// Cleanup 定期清理过期记录
func (r *RateLimiter) Cleanup(interval time.Duration) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for range ticker.C {
			r.mu.Lock()
			now := time.Now()
			windowStart := now.Add(-r.window)
			for key, requests := range r.requests {
				validRequests := make([]time.Time, 0, len(requests))
				for _, t := range requests {
					if t.After(windowStart) {
						validRequests = append(validRequests, t)
					}
				}
				if len(validRequests) == 0 {
					delete(r.requests, key)
				} else {
					r.requests[key] = validRequests
				}
			}
			r.mu.Unlock()
		}
	}()
}
