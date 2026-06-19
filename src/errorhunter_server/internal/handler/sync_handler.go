package handler

import (
	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
)

// SyncHandler 同步处理器（V1.1 桩实现）
type SyncHandler struct{}

func NewSyncHandler() *SyncHandler {
	return &SyncHandler{}
}

// Push 推送本地变更
// POST /sync/push
func (h *SyncHandler) Push(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// V1.1 桩实现
	var req struct {
		Items []struct {
			LocalID    string      `json:"local_id"`
			EntityType string      `json:"entity_type"`
			Operation  string      `json:"operation"`
			Payload    interface{} `json:"payload"`
		} `json:"items"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.ESyncPayloadInvalid)
		return
	}

	if len(req.Items) > 50 {
		respondError(c, errcode.ESyncBatchExceeded)
		return
	}

	// TODO: 实际处理同步逻辑
	results := make([]gin.H, len(req.Items))
	for i, item := range req.Items {
		results[i] = gin.H{
			"local_id":  item.LocalID,
			"status":    "SUCCESS",
			"remote_id": i + 1,
		}
	}

	respondSuccess(c, gin.H{
		"results":       results,
		"success_count": len(results),
		"fail_count":    0,
	})
}

// Pull 拉取远端变更
// GET /sync/pull
func (h *SyncHandler) Pull(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// V1.1 桩实现
	lastSync := c.Query("last_sync_at")

	respondSuccess(c, gin.H{
		"changes":     []interface{}{},
		"has_more":    false,
		"server_time": "2026-06-19T00:00:00Z",
		"last_sync":   lastSync,
	})
}
