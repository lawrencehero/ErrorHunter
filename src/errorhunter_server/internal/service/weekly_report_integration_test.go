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

	// 第一次生成时上一周周报不存在 → prev 字段为 nil（含新增的 review_count / accuracy）
	assert.Nil(t, report1.PrevWeekNew, "无上周周报时 PrevWeekNew 应为 nil")
	assert.Nil(t, report1.PrevWeekMastered, "无上周周报时 PrevWeekMastered 应为 nil")
	assert.Nil(t, report1.PrevWeekReviewCount, "无上周周报时 PrevWeekReviewCount 应为 nil")
	assert.Nil(t, report1.PrevWeekAccuracy, "无上周周报时 PrevWeekAccuracy 应为 nil")

	// 成就：本周 new=3/mastered=1/review=4/accuracy=50/streak=1，均不达标 → 空数组
	achSlice, achErr := report1.Achievements.ToStringSlice()
	require.NoError(t, achErr, "Achievements 应为合法 JSON 数组")
	assert.Empty(t, achSlice, "本周各项均不达标时应无成就")

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

	// 在上一周补一道题 + 2 条复习记录（1 MASTERED + 1 FAILED，accuracy=50），
	// 再删掉周报重新生成，让上周 NewQuestions=1, ReviewCount=2, ReviewAccuracy=50.00。
	// （直接构造数据 + 删周报重生成，验证 prev 取值）
	wrTestDB.Where("user_id = ? AND week_start = ?", userID, prevWeekStart).Delete(&model.WeeklyReport{})
	prevQ := &model.Question{
		UserID: userID, Status: model.StatusReviewing, ImageURL: "http://x/p1",
		ErrorCategory: model.ErrorKnowledge, NextReviewDate: prevWeekStart.AddDate(0, 0, 1),
		CreatedAt: prevWeekStart.AddDate(0, 0, 2),
	}
	require.NoError(t, wrTestDB.Create(prevQ).Error)
	prevWeekMid := prevWeekStart.AddDate(0, 0, 3)
	prevRecords := []*model.ReviewRecord{
		{QuestionID: prevQ.ID, UserID: userID, ReviewRound: 1, SelfRating: model.RatingMastered, MasterCountAfter: 1, ReviewedAt: prevWeekMid},
		{QuestionID: prevQ.ID, UserID: userID, ReviewRound: 2, SelfRating: model.RatingFailed, MasterCountAfter: 0, ReviewedAt: prevWeekMid},
	}
	for i := range prevRecords {
		require.NoError(t, wrTestDB.Create(prevRecords[i]).Error, "创建上周复习记录失败")
	}
	prevReport, err = svc.GenerateWeeklyReport(ctx, userID, prevWeekStart)
	require.NoError(t, err)
	assert.Equal(t, 1, prevReport.NewQuestions, "上周 NewQuestions 应为 1")
	assert.Equal(t, 0, prevReport.MasteredQuestions, "上周 MasteredQuestions 应为 0")
	assert.Equal(t, 2, prevReport.ReviewCount, "上周 ReviewCount 应为 2")
	assert.InDelta(t, 50.0, prevReport.ReviewAccuracy, 0.01, "上周 ReviewAccuracy 应为 50.00")

	// 生成本周周报，prev 字段应取上周 row（含新增的 review_count / accuracy）
	thisReport, err := svc.GenerateWeeklyReport(ctx, userID, weekStart)
	require.NoError(t, err)
	require.NotNil(t, thisReport.PrevWeekNew, "PrevWeekNew 不应为 nil")
	require.NotNil(t, thisReport.PrevWeekMastered, "PrevWeekMastered 不应为 nil")
	assert.Equal(t, 1, *thisReport.PrevWeekNew, "PrevWeekNew 应取上周 NewQuestions=1")
	assert.Equal(t, 0, *thisReport.PrevWeekMastered, "PrevWeekMastered 应取上周 MasteredQuestions=0")
	require.NotNil(t, thisReport.PrevWeekReviewCount, "PrevWeekReviewCount 不应为 nil")
	assert.Equal(t, 2, *thisReport.PrevWeekReviewCount, "PrevWeekReviewCount 应取上周 ReviewCount=2")
	require.NotNil(t, thisReport.PrevWeekAccuracy, "PrevWeekAccuracy 不应为 nil")
	assert.InDelta(t, 50.0, *thisReport.PrevWeekAccuracy, 0.01, "PrevWeekAccuracy 应取上周 ReviewAccuracy=50.00")

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

// TestGenerateWeeklyReport_Achievements 验证基于本周统计自动生成成就文案，
// 且成就落库为 JSONB []string，可被前端反序列化。
//
// 构造：本周 6 道新增错题（new=6 ≥5 → 勤勉录入），1 道 mastered_at 落本周
// （mastered=1 <10，不触发消灭能手），21 条复习记录（review=21 ≥20 → 复习达人）
// 其中 16 条 MASTERED（accuracy=16/21*100≈76.19 ≥75 → 高正确率）；复习记录
// 落在本周周一~周五共 5 个不同日期（streak=5 ≥5 → 连续打卡达人，但 <7 不触发全勤）。
func TestGenerateWeeklyReport_Achievements(t *testing.T) {
	ctx := context.Background()
	weekStart := LastCompletedWeekStart(time.Now())

	phone := fmt.Sprintf("139%08d", (time.Now().UnixNano()/3)%100000000)
	user := &model.User{Phone: phone, Grade: model.Grade33, DailyReviewLimit: 30}
	require.NoError(t, wrTestDB.Create(user).Error)
	userID := user.ID

	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})

	// 本周 6 道新增错题
	weekMid := weekStart.AddDate(0, 0, 3)
	questions := make([]*model.Question, 0, 6)
	for i := 0; i < 6; i++ {
		q := &model.Question{
			UserID: userID, Status: model.StatusReviewing, ImageURL: fmt.Sprintf("http://x/ach%d", i),
			ErrorCategory: model.ErrorKnowledge, NextReviewDate: weekMid, CreatedAt: weekMid,
		}
		require.NoError(t, wrTestDB.Create(q).Error)
		questions = append(questions, q)
	}

	// 让第 1 道题本周消灭（mastered_at 落本周）
	require.NoError(t, wrTestDB.Model(&model.Question{}).
		Where("id = ?", questions[0].ID).
		Updates(map[string]interface{}{"mastered_at": weekMid, "status": model.StatusMastered}).Error)

	// 21 条复习记录：16 MASTERED + 5 FAILED，accuracy=16/21*100≈76.19（≥75 → 高正确率）
	// 分布在周一~周五 5 个不同日期（每天至少 1 条），streak=5（≥5 → 连续打卡达人，<7 不触发全勤）
	// 周一~周四各 4 条 = 16 条，周五 5 条 = 5 条，共 21 条；前 16 条取 MASTERED，后 5 条取 FAILED。
	records := make([]*model.ReviewRecord, 0, 21)
	masteredRemaining := 16
	failedRemaining := 5
	for day := 0; day < 5; day++ {
		reviewDay := weekStart.AddDate(0, 0, day)
		dayCount := 4
		if day == 4 {
			dayCount = 5
		}
		for i := 0; i < dayCount; i++ {
			var rating model.SelfRating
			if masteredRemaining > 0 {
				rating = model.RatingMastered
				masteredRemaining--
			} else if failedRemaining > 0 {
				rating = model.RatingFailed
				failedRemaining--
			} else {
				rating = model.RatingMastered
			}
			records = append(records, &model.ReviewRecord{
				QuestionID: questions[0].ID, UserID: userID, ReviewRound: 1,
				SelfRating: rating, MasterCountAfter: 1, ReviewedAt: reviewDay,
			})
		}
	}
	for i := range records {
		require.NoError(t, wrTestDB.Create(records[i]).Error, "创建复习记录失败")
	}

	reportRepo := repository.NewWeeklyReportRepository(wrTestDB)
	questionRepo := repository.NewQuestionRepository(wrTestDB)
	reviewRepo := repository.NewReviewRecordRepository(wrTestDB)
	userRepo := repository.NewUserRepository(wrTestDB)
	svc := NewWeeklyReportService(reportRepo, questionRepo, reviewRepo, userRepo, wrTestDB)

	report, err := svc.GenerateWeeklyReport(ctx, userID, weekStart)
	require.NoError(t, err)
	assert.Equal(t, 6, report.NewQuestions, "NewQuestions 应为 6")
	assert.Equal(t, 1, report.MasteredQuestions, "MasteredQuestions 应为 1")
	assert.Equal(t, 21, report.ReviewCount, "ReviewCount 应为 21")
	assert.InDelta(t, 76.19, report.ReviewAccuracy, 0.01, "ReviewAccuracy 应为 76.19")

	// 成就应包含：勤勉录入(new≥5)、复习达人(review≥20)、高正确率(accuracy≥75)、连续打卡达人(streak≥5)
	// 不含：消灭能手(mastered=1<10)、全勤王者(streak=5<7)
	ach, achErr := report.Achievements.ToStringSlice()
	require.NoError(t, achErr, "Achievements 应为合法 JSON 数组")
	assert.Contains(t, ach, "勤勉录入")
	assert.Contains(t, ach, "复习达人")
	assert.Contains(t, ach, "高正确率")
	assert.Contains(t, ach, "连续打卡达人")
	assert.NotContains(t, ach, "消灭能手", "mastered=1 不应触发消灭能手")
	assert.NotContains(t, ach, "全勤王者", "streak=5 不应触发全勤王者")
	assert.Len(t, ach, 4, "应恰好 4 条成就")

	// 清理
	wrTestDB.Where("user_id = ?", userID).Delete(&model.ReviewRecord{})
	wrTestDB.Where("user_id = ?", userID).Delete(&model.Question{})
	wrTestDB.Where("user_id = ?", userID).Delete(&model.WeeklyReport{})
	wrTestDB.Delete(&model.User{}, userID)
}

func ptrString(s string) *string { return &s }
