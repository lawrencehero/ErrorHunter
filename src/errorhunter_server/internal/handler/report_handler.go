package handler

import (
	"math"
	"strconv"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/gin-gonic/gin"
)

// ReportHandler 报告处理器
type ReportHandler struct {
	reportRepo *repository.WeeklyReportRepository
	userRepo   *repository.UserRepository
}

func NewReportHandler(reportRepo *repository.WeeklyReportRepository, userRepo *repository.UserRepository) *ReportHandler {
	return &ReportHandler{reportRepo: reportRepo, userRepo: userRepo}
}

// GetDashboard 获取Dashboard概览
// GET /reports
func (h *ReportHandler) GetDashboard(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	ctx := c.Request.Context()

	// 获取用户信息（昵称、打卡天数）
	user, err := h.userRepo.FindByID(ctx, userID)
	if err != nil {
		respondError(c, errcode.EUserNotFound)
		return
	}

	nickname := "用户"
	if user.Nickname != nil {
		nickname = *user.Nickname
	}

	// 获取统计数据
	stats, err := h.reportRepo.GetDashboardStats(ctx, userID)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	// 计算消灭率
	var eliminationRate float64
	if stats.TotalQuestions > 0 {
		eliminationRate = math.Round(float64(stats.MasteredCount)/float64(stats.TotalQuestions)*1000) / 10
	}

	// 获取错因分布
	errorDist, _ := h.reportRepo.GetErrorDistribution(ctx, userID)
	errorDistData := make([]gin.H, 0, len(errorDist))
	for _, item := range errorDist {
		errorDistData = append(errorDistData, gin.H{
			"category": item.Category,
			"count":    item.Count,
		})
	}

	// 获取周趋势
	weeklyTrend, _ := h.reportRepo.GetWeeklyTrend(ctx, userID)
	weeklyTrendData := make([]gin.H, 0, len(weeklyTrend))
	for _, item := range weeklyTrend {
		weeklyTrendData = append(weeklyTrendData, gin.H{
			"date":           item.Date,
			"new_questions":  item.NewQuestions,
			"mastered_count": item.MasteredCount,
		})
	}

	// 获取薄弱知识点Top3
	weakKnowledge, _ := h.reportRepo.GetWeakKnowledgeTop(ctx, userID)
	weakKnowledgeData := make([]gin.H, 0, len(weakKnowledge))
	for _, item := range weakKnowledge {
		weakKnowledgeData = append(weakKnowledgeData, gin.H{
			"id":    item.ID,
			"name":  item.Name,
			"count": item.Count,
		})
	}

	// 本周打卡（周一至周日，只有当天存在 review_records 复习记录才视为打卡；
	// 录题不计入，与 streak 语义一致；今天未复习为 false；今天之后未来天为 false）
	weeklyCompleted, _ := h.reportRepo.GetWeeklyCompleted(ctx, userID)

	respondSuccess(c, gin.H{
		"greeting": gin.H{
			"nickname":    nickname,
			"streak_days": user.StreakDays,
		},
		"today_task": gin.H{
			"pending_review_count": stats.PendingReview,
			"has_overflow":         stats.PendingReview > int64(user.DailyReviewLimit),
			"overflow_count":       maxInt64(0, stats.PendingReview-int64(user.DailyReviewLimit)),
		},
		"statistics": gin.H{
			"total_questions":  stats.TotalQuestions,
			"mastered_count":   stats.MasteredCount,
			"elimination_rate": eliminationRate,
		},
		"error_distribution": errorDistData,
		"weekly_trend":       weeklyTrendData,
		"weak_knowledge_top": weakKnowledgeData,
		"weekly_completed":   weeklyCompleted,
	})
}

func maxInt64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
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
	// 越界保护：page<1 → offset 负数；pageSize<=0 → LIMIT 异常。
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 20 {
		pageSize = 20
	}

	reports, total, err := h.reportRepo.ListByUser(c.Request.Context(), userID, page, pageSize)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, gin.H{
		"items": reports,
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
