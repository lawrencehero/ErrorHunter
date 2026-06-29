package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"gorm.io/gorm"
)

// 上海时区。服务部署 TZ=Asia/Shanghai，DB 会话时区同。
// 显式载入 location 保证 weekStart/weekEnd 边界计算与"上一完整周"判定稳定，
// 不依赖容器 TZ 环境变量。
var shanghaiLoc *time.Location

func init() {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		// 兜底：LoadLocation 在极简镜像（无 zoneinfo）下可能失败，用 +08:00 固定偏移。
		loc = time.FixedZone("CST", 8*3600)
	}
	shanghaiLoc = loc
}

// WeeklyReportService 周报生成服务。
// 聚合指定一周（周一 00:00 ~ 周日 23:59:59，上海时区）的统计数据并落库，
// 幂等：同一 (user_id, week_start) 只生成一次，已存在则直接返回旧行。
type WeeklyReportService struct {
	reportRepo   *repository.WeeklyReportRepository
	questionRepo *repository.QuestionRepository
	reviewRepo   *repository.ReviewRecordRepository
	userRepo     *repository.UserRepository
	db           *gorm.DB
}

func NewWeeklyReportService(
	reportRepo *repository.WeeklyReportRepository,
	questionRepo *repository.QuestionRepository,
	reviewRepo *repository.ReviewRecordRepository,
	userRepo *repository.UserRepository,
	db *gorm.DB,
) *WeeklyReportService {
	return &WeeklyReportService{
		reportRepo:   reportRepo,
		questionRepo: questionRepo,
		reviewRepo:   reviewRepo,
		userRepo:     userRepo,
		db:           db,
	}
}

// weakKnowledgeItem 薄弱知识点项（落库到 weak_knowledge_top JSONB）。
type weakKnowledgeItem struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Count int64  `json:"count"`
}

// GenerateWeeklyReport 聚合并生成指定一周的周报。
//
// weekStart 期望为该周周一 00:00（上海时区）；若传入的日期不是周一，
// 内部会回溯到所在周的周一，保证边界正确。
// 幂等：若该 (user_id, week_start) 已存在周报，直接返回旧行，不重新计算/覆盖。
func (s *WeeklyReportService) GenerateWeeklyReport(ctx context.Context, userID int64, weekStart time.Time) (*model.WeeklyReport, error) {
	// 规范化到所在周周一 00:00（上海时区）
	weekStart = normalizeToMonday(weekStart)
	weekEnd := weekStart.AddDate(0, 0, 7) // 周一 00:00 ~ 下周一 00:00（半开区间，便于 BETWEEN）

	// 幂等：已存在则直接返回
	if existing, err := s.reportRepo.FindByUserAndWeek(ctx, userID, weekStart); err == nil {
		return existing, nil
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("查重周报失败: %w", err)
	}

	// 周编号：ISO 周数 year*100+week（与 init-db.sql 注释 YYYYWW 一致）
	isoYear, isoWeek := weekStart.ISOWeek()
	weekNumber := isoYear*100 + isoWeek

	// 1. NewQuestions：本周新建错题数（未删除）
	var newQuestions int64
	if err := s.db.WithContext(ctx).
		Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NULL AND created_at >= ? AND created_at < ?", userID, weekStart, weekEnd).
		Count(&newQuestions).Error; err != nil {
		return nil, fmt.Errorf("统计本周新增错题失败: %w", err)
	}

	// 2. MasteredQuestions：本周新消灭错题数（mastered_at 落在本周）
	var masteredQuestions int64
	if err := s.db.WithContext(ctx).
		Model(&model.Question{}).
		Where("user_id = ? AND deleted_at IS NULL AND mastered_at IS NOT NULL AND mastered_at >= ? AND mastered_at < ?", userID, weekStart, weekEnd).
		Count(&masteredQuestions).Error; err != nil {
		return nil, fmt.Errorf("统计本周消灭错题失败: %w", err)
	}

	// 3. ReviewCount + 4. ReviewAccuracy：本周复习记录数与正确率
	//    accuracy = MASTERED 占比 * 100，保留 2 位小数；无复习则 0。
	var reviewCount int64
	var masteredReviewCount int64
	if err := s.db.WithContext(ctx).
		Model(&model.ReviewRecord{}).
		Where("user_id = ? AND reviewed_at >= ? AND reviewed_at < ?", userID, weekStart, weekEnd).
		Count(&reviewCount).Error; err != nil {
		return nil, fmt.Errorf("统计本周复习次数失败: %w", err)
	}
	if reviewCount > 0 {
		if err := s.db.WithContext(ctx).
			Model(&model.ReviewRecord{}).
			Where("user_id = ? AND reviewed_at >= ? AND reviewed_at < ? AND self_rating = ?", userID, weekStart, weekEnd, model.RatingMastered).
			Count(&masteredReviewCount).Error; err != nil {
			return nil, fmt.Errorf("统计本周复习正确数失败: %w", err)
		}
	}
	var reviewAccuracy float64
	if reviewCount > 0 {
		reviewAccuracy = float64(masteredReviewCount) / float64(reviewCount) * 100
		// 保留 2 位小数
		reviewAccuracy = float64(int(reviewAccuracy*100+0.5)) / 100
	}

	// 5. TopErrorCategory + TopErrorCategoryPercentage：
	//    本周新建错题中 error_category 众数，及该众数占本周新建错题总数的比例(%)。
	//    占比 = top count / newQuestions * 100，保留 2 位小数；本周无题则 0。
	type catStat struct {
		Category model.ErrorCategory
		Count    int64
	}
	var topCat catStat
	topErrCat := (*model.ErrorCategory)(nil)
	topErrCatPct := 0.0
	if err := s.db.WithContext(ctx).
		Model(&model.Question{}).
		Select("error_category as category, COUNT(*) as count").
		Where("user_id = ? AND deleted_at IS NULL AND created_at >= ? AND created_at < ?", userID, weekStart, weekEnd).
		Group("error_category").
		Order("COUNT(*) DESC").
		Limit(1).
		Scan(&topCat).Error; err == nil && topCat.Category != "" {
		cat := topCat.Category
		topErrCat = &cat
		if newQuestions > 0 {
			pct := float64(topCat.Count) / float64(newQuestions) * 100
			// 保留 2 位小数（四舍五入）
			topErrCatPct = float64(int(pct*100+0.5)) / 100
		}
	} else if err != nil {
		return nil, fmt.Errorf("统计本周错因众数失败: %w", err)
	}

	// 6. WeakKnowledgeTop：本周新建错题关联的知识点 Top3（按出现次数）
	weakTop, err := s.getWeakKnowledgeTopForWeek(ctx, userID, weekStart, weekEnd)
	if err != nil {
		return nil, fmt.Errorf("统计本周薄弱知识点失败: %w", err)
	}
	var weakJSON model.JSONB
	if len(weakTop) == 0 {
		weakJSON = model.JSONB("[]")
	} else {
		b, mErr := json.Marshal(weakTop)
		if mErr != nil {
			return nil, fmt.Errorf("序列化薄弱知识点失败: %w", mErr)
		}
		weakJSON = model.JSONB(b)
	}

	// 7. PrevWeekNew / PrevWeekMastered / PrevWeekReviewCount / PrevWeekAccuracy：
	//    取上一周周报 row 的对应字段；没有则 nil
	prevWeekStart := weekStart.AddDate(0, 0, -7)
	var prevWeekNew, prevWeekMastered, prevWeekReviewCount *int
	var prevWeekAccuracy *float64
	if prev, pErr := s.reportRepo.FindByUserAndWeek(ctx, userID, prevWeekStart); pErr == nil && prev != nil {
		n := prev.NewQuestions
		m := prev.MasteredQuestions
		rc := prev.ReviewCount
		ra := prev.ReviewAccuracy
		prevWeekNew = &n
		prevWeekMastered = &m
		prevWeekReviewCount = &rc
		prevWeekAccuracy = &ra
	} else if pErr != nil && !errors.Is(pErr, gorm.ErrRecordNotFound) {
		log.Printf("weekly_report: 查询上周周报失败 user=%d week=%v: %v", userID, prevWeekStart, pErr)
		// 不阻断本周生成，prev 字段保持 nil
	}

	// 8. Achievements：基于本周统计生成成就文案列表（JSONB []string）。
	streakDays := 0
	if sd, sErr := s.getReviewStreakInWeek(ctx, userID, weekStart, weekEnd); sErr == nil {
		streakDays = sd
	} else if sErr != nil {
		log.Printf("weekly_report: 统计本周连续打卡失败 user=%d week=%v: %v", userID, weekStart, sErr)
		// 不阻断生成，按 streak=0 处理
	}
	achieveJSON := buildAchievementsJSONB(int(newQuestions), int(masteredQuestions), int(reviewCount), reviewAccuracy, streakDays)

	report := &model.WeeklyReport{
		UserID:            userID,
		WeekNumber:        weekNumber,
		WeekStart:         weekStart,
		WeekEnd:           weekStart.AddDate(0, 0, 6), // 周日 00:00（DATE 列存日期；统计区间用半开 [weekStart, weekEnd+1day)）
		NewQuestions:      int(newQuestions),
		MasteredQuestions: int(masteredQuestions),
		ReviewCount:       int(reviewCount),
		ReviewAccuracy:    reviewAccuracy,
		PrevWeekNew:               prevWeekNew,
		PrevWeekMastered:          prevWeekMastered,
		PrevWeekReviewCount:       prevWeekReviewCount,
		PrevWeekAccuracy:          prevWeekAccuracy,
		Achievements:              achieveJSON,
		TopErrorCategory:           topErrCat,
		TopErrorCategoryPercentage: topErrCatPct,
		WeakKnowledgeTop:           weakJSON,
	}

	if err := s.reportRepo.Create(ctx, report); err != nil {
		// 并发场景下另一 goroutine 可能已插入；再查一次兜底
		if existing, qErr := s.reportRepo.FindByUserAndWeek(ctx, userID, weekStart); qErr == nil {
			return existing, nil
		}
		return nil, fmt.Errorf("创建周报失败: %w", err)
	}
	return report, nil
}

// getWeakKnowledgeTopForWeek 本周新建错题关联的知识点 Top3（按出现次数降序）。
// 复用 report_repository.GetWeakKnowledgeTop 的 JOIN 思路，但限定 created_at 在本周范围，
// 且不按 status 过滤（只统计本周新增错题的错因分布，与"薄弱"语义一致）。
func (s *WeeklyReportService) getWeakKnowledgeTopForWeek(ctx context.Context, userID int64, weekStart, weekEnd time.Time) ([]weakKnowledgeItem, error) {
	items := make([]weakKnowledgeItem, 0)
	err := s.db.WithContext(ctx).
		Table("question_knowledge").
		Select("knowledge_points.id as id, knowledge_points.name as name, COUNT(*) as count").
		Joins("JOIN questions ON questions.id = question_knowledge.question_id").
		Joins("JOIN knowledge_points ON knowledge_points.id = question_knowledge.knowledge_point_id").
		Where("questions.user_id = ? AND questions.deleted_at IS NULL AND questions.created_at >= ? AND questions.created_at < ?",
			userID, weekStart, weekEnd).
		Group("knowledge_points.id, knowledge_points.name").
		Order("count DESC").
		Limit(3).
		Scan(&items).Error
	return items, err
}

// normalizeToMonday 将任意时刻回溯到所在周周一 00:00（上海时区）。
// Go 的 Weekday：Sunday=0, Monday=1 ... Saturday=6。
func normalizeToMonday(t time.Time) time.Time {
	t = t.In(shanghaiLoc)
	weekday := int(t.Weekday())
	if weekday == 0 {
		weekday = 7 // 周日归为 7，使周一=1 的偏移计算正确
	}
	monday := t.AddDate(0, 0, -(weekday - 1))
	return time.Date(monday.Year(), monday.Month(), monday.Day(), 0, 0, 0, 0, shanghaiLoc)
}

// getReviewStreakInWeek 统计本周（weekStart..weekEnd，半开区间）内连续打卡天数。
// 「打卡」= 当天至少有 1 条 review_record。从本周周一往后连续计数，遇到第一个无记录的
// 日子即停止（不要求打到周日）。空周返回 0。
func (s *WeeklyReportService) getReviewStreakInWeek(ctx context.Context, userID int64, weekStart, weekEnd time.Time) (int, error) {
	var days []time.Time
	if err := s.db.WithContext(ctx).
		Model(&model.ReviewRecord{}).
		Select("DISTINCT DATE(reviewed_at) AS d").
		Where("user_id = ? AND reviewed_at >= ? AND reviewed_at < ?", userID, weekStart, weekEnd).
		Order("d ASC").
		Scan(&days).Error; err != nil {
		return 0, err
	}
	if len(days) == 0 {
		return 0, nil
	}
	// 用 set 加速查找
	have := make(map[string]bool, len(days))
	for _, d := range days {
		// days 来自 DATE(reviewed_at)，Postgres 返回 time.Time（00:00 UTC），
		// 这里统一取日期部分字符串（按上海时区）做 key。
		have[d.In(shanghaiLoc).Format("2006-01-02")] = true
	}
	streak := 0
	for i := 0; i < 7; i++ {
		day := weekStart.AddDate(0, 0, i).In(shanghaiLoc).Format("2006-01-02")
		if have[day] {
			streak++
		} else {
			break
		}
	}
	return streak, nil
}

// buildAchievementsJSONB 基于本周统计生成成就文案列表，落库为 JSONB []string。
//
// 成就规则（自主定义，参考优秀学习 App）：
//  1. 连续打卡 ≥5 天      → "连续打卡达人"（坚持复习，养成习惯）
//  2. 本周消灭 ≥10 题     → "消灭能手"（mastered_questions 达标）
//  3. 本周正确率 ≥75%     → "高正确率"（review_accuracy 达标，且至少有 1 次复习）
//  4. 本周新增 ≥5 题      → "勤勉录入"（new_questions 达标）
//  5. 本周复习 ≥20 次     → "复习达人"（review_count 达标）
//  6. 全勤复习 7 天       → "全勤王者"（连续打卡 = 7）
//
// 规则独立判定，可叠加多条。无任何达标则返回空数组 []。
func buildAchievementsJSONB(newQuestions, masteredQuestions, reviewCount int, reviewAccuracy float64, streakDays int) model.JSONB {
	achievements := make([]string, 0, 6)
	if streakDays >= 7 {
		achievements = append(achievements, "全勤王者")
	} else if streakDays >= 5 {
		achievements = append(achievements, "连续打卡达人")
	}
	if masteredQuestions >= 10 {
		achievements = append(achievements, "消灭能手")
	}
	if reviewCount > 0 && reviewAccuracy >= 75.0 {
		achievements = append(achievements, "高正确率")
	}
	if newQuestions >= 5 {
		achievements = append(achievements, "勤勉录入")
	}
	if reviewCount >= 20 {
		achievements = append(achievements, "复习达人")
	}
	if len(achievements) == 0 {
		return model.JSONB("[]")
	}
	b, _ := json.Marshal(achievements)
	return model.JSONB(b)
}

// LastCompletedWeekStart 返回"最近一个已结束完整周"的周一 00:00（上海时区）。
//
// 判定逻辑：以当前上海时刻 now 为基准。
//   - 若今天是周一且已过 00:00，则上一完整周为 now-7 天所在周。
//   - 一般情况：当前所在周的"上一周"即为最近一个已结束的完整周。
//
// 即：now 所在周的上一周的周一。这样保证只生成 weekEnd <= now 的周，不生成未结束的当前周。
func LastCompletedWeekStart(now time.Time) time.Time {
	now = now.In(shanghaiLoc)
	thisMonday := normalizeToMonday(now)
	return thisMonday.AddDate(0, 0, -7)
}

// GenerateForAllActiveUsers 为所有未软删用户生成"上一完整周"的周报。
// 供后台定时任务调用；已生成的用户自动跳过（幂等）。
// 返回成功生成数与首个遇到的错误（错误不中断整体流程，仅记录）。
func (s *WeeklyReportService) GenerateForAllActiveUsers(ctx context.Context, weekStart time.Time) (generated int, firstErr error) {
	userIDs, err := s.userRepo.ListActiveUserIDs(ctx)
	if err != nil {
		return 0, fmt.Errorf("列出活跃用户失败: %w", err)
	}

	for _, uid := range userIDs {
		_, gErr := s.GenerateWeeklyReport(ctx, uid, weekStart)
		if gErr != nil {
			log.Printf("weekly_report: 生成失败 user=%d week=%v: %v", uid, weekStart, gErr)
			if firstErr == nil {
				firstErr = gErr
			}
			continue
		}
		generated++
	}
	return generated, firstErr
}
