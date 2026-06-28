//go:build integration

package service

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// 本集成测试需要 Docker Compose 测试环境（PostgreSQL）：
//   docker compose -f deploy/docker-compose.test.yml up -d
//   go test -tags=integration -v -count=1 -run TestWeeklyReport ./internal/service/

var wrTestDB *gorm.DB

func TestMain(m *testing.M) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		getEnvOr("EH_DATABASE_HOST", "localhost"),
		getEnvOr("EH_DATABASE_PORT", "5432"),
		getEnvOr("EH_DATABASE_USER", "errorhunter"),
		getEnvOr("EH_DATABASE_PASSWORD", "errorhunter_dev"),
		getEnvOr("EH_DATABASE_DBNAME", "errorhunter_test"),
		getEnvOr("EH_DATABASE_SSLMODE", "disable"),
	)
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Printf("weekly_report integration test: connect DB failed: %v\n", err)
		os.Exit(1)
	}
	wrTestDB = db
	os.Exit(m.Run())
}

func getEnvOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// TestGenerateWeeklyReport_AggregationAndIdempotent 验证周报聚合正确且重复生成幂等。
//
// 构造：用户 U，本周内创建 3 道错题（2 道 KNOWLEDGE、1 道 SKILL），
// 其中 1 道 mastered_at 落本周；本周 4 条 review_record（2 条 MASTERED、1 条 PARTIAL、1 条 FAILED）。
// 期望：
//   NewQuestions      = 3
//   MasteredQuestions = 1
//   ReviewCount       = 4
//   ReviewAccuracy    = 50.00（2/4*100）
//   TopErrorCategory  = KNOWLEDGE（众数）
//   重复生成：返回同一行（ID 相同），不新增 row
func TestGenerateWeeklyReport_AggregationAndIdempotent(t *testing.T) {
	ctx := context.Background()

	// 选定"上一完整周"作为测试周，保证不会与今天的数据混入
	weekStart := LastCompletedWeekStart(time.Now())

	// 唯一手机号，避免与其它测试冲突；同时清理可能的旧数据
	phone := fmt.Sprintf("139%08d", time.Now().UnixNano()%100000000)
	user := &model.User{
		Phone:            phone,
		Grade:            model.Grade33,
		Nickname:         ptrString("周报测试用户"),
		StreakDays:       0,
		DailyReviewLimit: 20,
	}
	require.NoError(t, wrTestDB.Create(user).Error, "创建测试用户失败")
	userID := user.ID

	// 清理本测试可能遗留的周报（幂等重跑友好）
	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})

	// 本周内创建 3 道错题
	weekMid := weekStart.AddDate(0, 0, 3) // 周四
	questions := []*model.Question{
		{UserID: userID, Status: model.StatusReviewing, ImageURL: "http://x/q1", ErrorCategory: model.ErrorKnowledge, NextReviewDate: weekMid, CreatedAt: weekMid},
		{UserID: userID, Status: model.StatusReviewing, ImageURL: "http://x/q2", ErrorCategory: model.ErrorKnowledge, NextReviewDate: weekMid, CreatedAt: weekMid},
		{UserID: userID, Status: model.StatusReviewing, ImageURL: "http://x/q3", ErrorCategory: model.ErrorSkill, NextReviewDate: weekMid, CreatedAt: weekMid},
	}
	for i := range questions {
		require.NoError(t, wrTestDB.Create(questions[i]).Error, "创建错题失败")
	}

	// 让第 1 道题本周消灭（mastered_at 落本周）
	masteredAt := weekMid
	require.NoError(t, wrTestDB.Model(&model.Question{}).
		Where("id = ?", questions[0].ID).
		Updates(map[string]interface{}{"mastered_at": masteredAt, "status": model.StatusMastered}).Error, "更新 mastered_at 失败")

	// 本周 4 条复习记录：2 MASTERED + 1 PARTIAL + 1 FAILED
	records := []*model.ReviewRecord{
		{QuestionID: questions[0].ID, UserID: userID, ReviewRound: 1, SelfRating: model.RatingMastered, MasterCountAfter: 1, ReviewedAt: weekMid},
		{QuestionID: questions[1].ID, UserID: userID, ReviewRound: 1, SelfRating: model.RatingMastered, MasterCountAfter: 1, ReviewedAt: weekMid},
		{QuestionID: questions[1].ID, UserID: userID, ReviewRound: 2, SelfRating: model.RatingPartial, MasterCountAfter: 1, ReviewedAt: weekMid},
		{QuestionID: questions[2].ID, UserID: userID, ReviewRound: 1, SelfRating: model.RatingFailed, MasterCountAfter: 0, ReviewedAt: weekMid},
	}
	for i := range records {
		require.NoError(t, wrTestDB.Create(records[i]).Error, "创建复习记录失败")
	}

	// 实例化 service
	reportRepo := repository.NewWeeklyReportRepository(wrTestDB)
	questionRepo := repository.NewQuestionRepository(wrTestDB)
	reviewRepo := repository.NewReviewRecordRepository(wrTestDB)
	userRepo := repository.NewUserRepository(wrTestDB)
	svc := NewWeeklyReportService(reportRepo, questionRepo, reviewRepo, userRepo, wrTestDB)

	// 第一次生成
	report1, err := svc.GenerateWeeklyReport(ctx, userID, weekStart)
	require.NoError(t, err, "第一次生成周报失败")
	require.NotNil(t, report1)

	assert.Equal(t, 3, report1.NewQuestions, "NewQuestions 应为 3")
	assert.Equal(t, 1, report1.MasteredQuestions, "MasteredQuestions 应为 1")
	assert.Equal(t, 4, report1.ReviewCount, "ReviewCount 应为 4")
	assert.InDelta(t, 50.0, report1.ReviewAccuracy, 0.01, "ReviewAccuracy 应为 50.00")
	require.NotNil(t, report1.TopErrorCategory, "TopErrorCategory 不应为 nil")
	assert.Equal(t, model.ErrorKnowledge, *report1.TopErrorCategory, "TopErrorCategory 应为 KNOWLEDGE（众数）")
	// KNOWLEDGE 2 道 / 共 3 道 = 66.67%（保留 2 位小数）
	assert.InDelta(t, 66.67, report1.TopErrorCategoryPercentage, 0.01, "TopErrorCategoryPercentage 应为 66.67")

	// week_number 口径：ISO year*100+week
	isoYear, isoWeek := weekStart.ISOWeek()
	assert.Equal(t, isoYear*100+isoWeek, report1.WeekNumber, "WeekNumber 应为 ISO year*100+week")

	// 第一次生成时上一周周报不存在 → prev 字段为 nil
	assert.Nil(t, report1.PrevWeekNew, "无上周周报时 PrevWeekNew 应为 nil")
	assert.Nil(t, report1.PrevWeekMastered, "无上周周报时 PrevWeekMastered 应为 nil")

	// 第二次生成（幂等）：应返回同一行，不新增
	report2, err := svc.GenerateWeeklyReport(ctx, userID, weekStart)
	require.NoError(t, err, "第二次生成周报（幂等）失败")
	assert.Equal(t, report1.ID, report2.ID, "幂等：重复生成应返回同一行 ID")
	assert.Equal(t, 3, report2.NewQuestions, "幂等：字段应一致")

	// 数据库中该 (user, week) 仅 1 行
	var count int64
	wrTestDB.Model(&model.WeeklyReport{}).Where("user_id = ? AND week_start = ?", userID, weekStart).Count(&count)
	assert.Equal(t, int64(1), count, "幂等：数据库应仅 1 行周报")

	// 清理
	wrTestDB.Where("user_id = ?", userID).Delete(&model.ReviewRecord{})
	wrTestDB.Where("user_id = ?", userID).Delete(&model.Question{})
	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})
	wrTestDB.Delete(&model.User{}, userID)
}

// TestGenerateWeeklyReport_PrevWeekFromExistingRow 验证 PrevWeekNew/PrevWeekMastered
// 取自上一周已生成的周报行。
func TestGenerateWeeklyReport_PrevWeekFromExistingRow(t *testing.T) {
	ctx := context.Background()
	weekStart := LastCompletedWeekStart(time.Now())
	prevWeekStart := weekStart.AddDate(0, 0, -7)

	phone := fmt.Sprintf("139%08d", (time.Now().UnixNano()/7)%100000000)
	user := &model.User{Phone: phone, Grade: model.Grade33, DailyReviewLimit: 20}
	require.NoError(t, wrTestDB.Create(user).Error)
	userID := user.ID

	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})

	reportRepo := repository.NewWeeklyReportRepository(wrTestDB)
	questionRepo := repository.NewQuestionRepository(wrTestDB)
	reviewRepo := repository.NewReviewRecordRepository(wrTestDB)
	userRepo := repository.NewUserRepository(wrTestDB)
	svc := NewWeeklyReportService(reportRepo, questionRepo, reviewRepo, userRepo, wrTestDB)

	// 先生成上一周周报（prev week，无数据 → NewQuestions=0）
	prevReport, err := svc.GenerateWeeklyReport(ctx, userID, prevWeekStart)
	require.NoError(t, err)
	assert.Equal(t, 0, prevReport.NewQuestions)

	// 在上一周补一道题，再删掉周报重新生成，让上周 NewQuestions=1, MasteredQuestions=0
	// （直接构造数据 + 删周报重生成，验证 prev 取值）
	wrTestDB.Where("user_id = ? AND week_start = ?", userID, prevWeekStart).Delete(&model.WeeklyReport{})
	prevQ := &model.Question{
		UserID: userID, Status: model.StatusReviewing, ImageURL: "http://x/p1",
		ErrorCategory: model.ErrorKnowledge, NextReviewDate: prevWeekStart.AddDate(0, 0, 1),
		CreatedAt: prevWeekStart.AddDate(0, 0, 2),
	}
	require.NoError(t, wrTestDB.Create(prevQ).Error)
	prevReport, err = svc.GenerateWeeklyReport(ctx, userID, prevWeekStart)
	require.NoError(t, err)
	assert.Equal(t, 1, prevReport.NewQuestions, "上周 NewQuestions 应为 1")
	assert.Equal(t, 0, prevReport.MasteredQuestions, "上周 MasteredQuestions 应为 0")

	// 生成本周周报，prev 字段应取上周 row
	thisReport, err := svc.GenerateWeeklyReport(ctx, userID, weekStart)
	require.NoError(t, err)
	require.NotNil(t, thisReport.PrevWeekNew, "PrevWeekNew 不应为 nil")
	require.NotNil(t, thisReport.PrevWeekMastered, "PrevWeekMastered 不应为 nil")
	assert.Equal(t, 1, *thisReport.PrevWeekNew, "PrevWeekNew 应取上周 NewQuestions=1")
	assert.Equal(t, 0, *thisReport.PrevWeekMastered, "PrevWeekMastered 应取上周 MasteredQuestions=0")

	// 清理
	wrTestDB.Where("user_id = ?", userID).Delete(&model.ReviewRecord{})
	wrTestDB.Where("user_id = ?", userID).Delete(&model.Question{})
	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})
	wrTestDB.Delete(&model.User{}, userID)
}

// TestGenerateWeeklyReport_EmptyWeek 空数据周：所有计数为 0，accuracy 为 0，
// TopErrorCategory 为 nil，WeakKnowledgeTop 为 []。
func TestGenerateWeeklyReport_EmptyWeek(t *testing.T) {
	ctx := context.Background()
	weekStart := LastCompletedWeekStart(time.Now())

	phone := fmt.Sprintf("139%08d", (time.Now().UnixNano()/13)%100000000)
	user := &model.User{Phone: phone, Grade: model.Grade33, DailyReviewLimit: 20}
	require.NoError(t, wrTestDB.Create(user).Error)
	userID := user.ID

	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})

	reportRepo := repository.NewWeeklyReportRepository(wrTestDB)
	questionRepo := repository.NewQuestionRepository(wrTestDB)
	reviewRepo := repository.NewReviewRecordRepository(wrTestDB)
	userRepo := repository.NewUserRepository(wrTestDB)
	svc := NewWeeklyReportService(reportRepo, questionRepo, reviewRepo, userRepo, wrTestDB)

	report, err := svc.GenerateWeeklyReport(ctx, userID, weekStart)
	require.NoError(t, err)
	assert.Equal(t, 0, report.NewQuestions)
	assert.Equal(t, 0, report.MasteredQuestions)
	assert.Equal(t, 0, report.ReviewCount)
	assert.InDelta(t, 0.0, report.ReviewAccuracy, 0.001)
	assert.Nil(t, report.TopErrorCategory, "空周 TopErrorCategory 应为 nil")
	assert.InDelta(t, 0.0, report.TopErrorCategoryPercentage, 0.001, "空周 TopErrorCategoryPercentage 应为 0")
	// WeakKnowledgeTop 应为 JSON 空数组
	assert.Equal(t, "[]", string(report.WeakKnowledgeTop), "空周 WeakKnowledgeTop 应为 []")

	// 清理
	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})
	wrTestDB.Delete(&model.User{}, userID)
}

func ptrString(s string) *string { return &s }
