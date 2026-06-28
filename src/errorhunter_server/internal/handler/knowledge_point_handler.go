package handler

import (
	"encoding/json"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/gin-gonic/gin"
)

// 当前知识点版本（与 seeder / configs/knowledge_points.yaml 一致）
const kpVersion = "2026A"

var validKpGrades = map[string]bool{
	"31": true, "32": true, "33": true, "34": true,
	"71": true, "72": true, "73": true,
}

// KnowledgePointHandler 知识点处理器
type KnowledgePointHandler struct {
	kpRepo *repository.KnowledgePointRepository
}

func NewKnowledgePointHandler(kpRepo *repository.KnowledgePointRepository) *KnowledgePointHandler {
	return &KnowledgePointHandler{kpRepo: kpRepo}
}

// knowledgePointResponse 知识点响应 DTO
type knowledgePointResponse struct {
	ID            int    `json:"id"`
	Name          string `json:"name"`
	Subject       string `json:"subject"`
	ParentID      string `json:"parent_id"` // 领域：num/geo/stat/custom
	IsRecommended bool   `json:"is_recommended"`
}

// List 查询知识点
// GET /v1/knowledge-points?grade=31&subject=数学
func (h *KnowledgePointHandler) List(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	grade := c.Query("grade")
	if !validKpGrades[grade] {
		respondError(c, errcode.EParamValidation.WithData("invalid grade"))
		return
	}
	subject := c.DefaultQuery("subject", "数学")

	points, err := h.kpRepo.ListByGradeAndSubject(c.Request.Context(), grade, subject, kpVersion)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	items := make([]knowledgePointResponse, 0, len(points))
	for _, p := range points {
		dto := knowledgePointResponse{
			ID:   p.ID,
			Name: p.Name,
		}
		// 从 keywords JSONB 解析 subject/domain/is_recommended
		if !p.Keywords.IsNull() {
			var kw map[string]interface{}
			if err := json.Unmarshal(p.Keywords, &kw); err == nil {
				if v, ok := kw["subject"].(string); ok {
					dto.Subject = v
				}
				if v, ok := kw["domain"].(string); ok {
					dto.ParentID = v
				}
				if v, ok := kw["is_recommended"].(bool); ok {
					dto.IsRecommended = v
				}
			}
		}
		if dto.Subject == "" {
			dto.Subject = subject
		}
		items = append(items, dto)
	}

	respondSuccess(c, gin.H{"items": items})
}
