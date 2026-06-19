package handler

import (
	"strconv"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/gin-gonic/gin"
)

// ReportHandler 报告处理器
type ReportHandler struct {
	reportRepo *repository.WeeklyReportRepository
}

func NewReportHandler(reportRepo *repository.WeeklyReportRepository) *ReportHandler {
	return &ReportHandler{reportRepo: reportRepo}
}

// GetDashboard 获取Dashboard概览
// GET /reports
func (h *ReportHandler) GetDashboard(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	// TODO: 实现完整的Dashboard数据聚合
	// 目前返回简化版本
	respondSuccess(c, gin.H{
		"greeting": gin.H{
			"nickname":    "用户",
			"streak_days": 0,
		},
		"today_task": gin.H{
			"pending_review_count": 0,
			"has_overflow":         false,
			"overflow_count":       0,
		},
		"statistics": gin.H{
			"total_questions":   0,
			"mastered_count":    0,
			"elimination_rate":  0.0,
		},
		"error_distribution": []gin.H{},
		"weekly_trend":       []gin.H{},
		"weak_knowledge_top": []gin.H{},
	})
}

// GetWeeklyReports 获取周报列表
// GET /reports/weekly
func (h *ReportHandler) GetWeeklyReports(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	if pageSize > 20 {
		pageSize = 20
	}

	reports, total, err := h.reportRepo.ListByUser(c.Request.Context(), userID, page, pageSize)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, gin.H{
		"list": reports,
		"pagination": gin.H{
			"page":      page,
			"page_size": pageSize,
			"total":     total,
		},
	})
}

// GetWeeklyReportDetail 获取周报详情
// GET /reports/weekly/:id
func (h *ReportHandler) GetWeeklyReportDetail(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	report, err := h.reportRepo.FindByID(c.Request.Context(), id)
	if err != nil {
		respondError(c, errcode.EReportNotFound)
		return
	}

	if report.UserID != userID {
		respondError(c, errcode.EForbidden)
		return
	}

	respondSuccess(c, report)
}
