package service

import (
	"context"
	"log"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/pkg/scheduler"
	"github.com/errorhunter/errorhunter-server/internal/repository"
)

// ReviewService 复习服务
type ReviewService struct {
	questionRepo *repository.QuestionRepository
	reviewRepo   *repository.ReviewRecordRepository
	userRepo     *repository.UserRepository
	strategy     scheduler.ScheduleStrategy
}

func NewReviewService(
	questionRepo *repository.QuestionRepository,
	reviewRepo *repository.ReviewRecordRepository,
	userRepo *repository.UserRepository,
) *ReviewService {
	return &ReviewService{
		questionRepo: questionRepo,
		reviewRepo:   reviewRepo,
		userRepo:     userRepo,
		strategy:     &scheduler.EbbinghausStrategy{},
	}
}

// ReviewQueueResponse 复习队列响应
//
// review_items / revive_items 均直接返回完整 model.Question（与错题列表 API 的
// 题目序列化结构一致），客户端 QuestionModel.fromJson 无需特殊映射即可解析。
// 复活检测题的 status 为 MASTERED（GetReviveCandidates 取 StatusMastered），
// 客户端 ReviewBloc._isReviveCheck 据此识别。
type ReviewQueueResponse struct {
	ReviewItems   []*model.Question `json:"review_items"`
	ReviveItems   []*model.Question `json:"revive_items"`
	TotalCount    int               `json:"total_count"`
	ReviveCount   int               `json:"revive_count"`
	HasMore       bool              `json:"has_more"`
	OverflowCount int               `json:"overflow_count"`
}

// GetReviewQueue 获取今日复习队列
//
// questionIDs 非空时为单题/指定题复习入口：仅返回这些题（不限 due、不限每日上限、
// 不取复活检测题），供错题详情页"开始复习此题"使用。提交走 SubmitReview 正常推进计划。
func (s *ReviewService) GetReviewQueue(ctx context.Context, userID int64, dailyLimit int, questionIDs []int64) (*ReviewQueueResponse, error) {
	// 单题复习入口：按指定 ID 取可复习题，跳过 due 判定与每日上限。
	if len(questionIDs) > 0 {
		questions, err := s.questionRepo.GetReviewableByIDs(ctx, userID, questionIDs)
		if err != nil {
			return nil, errcode.EInternalServer
		}
		reviewItems := make([]*model.Question, 0, len(questions))
		for i := range questions {
			reviewItems = append(reviewItems, &questions[i])
		}
		fillTotalReviewRoundsPtrs(reviewItems)
		fillReviewCountPtrs(s.reviewRepo, reviewItems)
		return &ReviewQueueResponse{
			ReviewItems: reviewItems,
			ReviveItems: []*model.Question{},
			TotalCount:  len(reviewItems),
			ReviveCount: 0,
			HasMore:     false,
			OverflowCount: 0,
		}, nil
	}

	today := time.Now()

	// 获取待复习题目
	dueQuestions, err := s.questionRepo.GetDueQuestions(ctx, userID, today)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	// 应用每日上限
	overflowCount := 0
	if len(dueQuestions) > dailyLimit {
		overflowCount = len(dueQuestions) - dailyLimit
		dueQuestions = dueQuestions[:dailyLimit]
	}

	// 直接复用 model.Question（已 Preload KnowledgePoints），序列化结构与错题列表 API 一致
	reviewItems := make([]*model.Question, 0, len(dueQuestions))
	for i := range dueQuestions {
		reviewItems = append(reviewItems, &dueQuestions[i])
	}

	// 获取复活检测题目（最多3道，status=MASTERED）
	reviveQuestions, err := s.questionRepo.GetReviveCandidates(ctx, userID, today, 3)
	if err != nil {
		return nil, errcode.EInternalServer
	}
	reviveItems := make([]*model.Question, 0, len(reviveQuestions))
	for i := range reviveQuestions {
		reviveItems = append(reviveItems, &reviveQuestions[i])
	}

	// 显式填充复习总轮次，避免前端依赖默认值（review_items / revive_items 均为 *model.Question）
	fillTotalReviewRoundsPtrs(reviewItems)
	fillTotalReviewRoundsPtrs(reviveItems)
	// 填充累计复习次数，供复习卡与错题本一致展示。
	fillReviewCountPtrs(s.reviewRepo, reviewItems)
	fillReviewCountPtrs(s.reviewRepo, reviveItems)

	return &ReviewQueueResponse{
		ReviewItems:   reviewItems,
		ReviveItems:   reviveItems,
		TotalCount:    len(reviewItems) + len(reviveItems),
		ReviveCount:   len(reviveItems),
		HasMore:       overflowCount > 0,
		OverflowCount: overflowCount,
	}, nil
}

// TodaySummaryResponse 今日复习汇总响应（首页"查看复习"用）。
// 字段与前端 ReviewReportModel 对齐：今日复习各评级数、用时（分钟）、
// 连续打卡天数、本轮消灭数。今日未复习时各项为 0（前端展示空报告）。
type TodaySummaryResponse struct {
	TotalCount      int    `json:"total_count"`
	MasteredCount   int    `json:"mastered_count"`
	PartialCount    int    `json:"partial_count"`
	FailedCount     int    `json:"failed_count"`
	DurationMinutes int    `json:"duration_minutes"`
	StreakDays      int    `json:"streak_days"`
	EliminatedCount int    `json:"eliminated_count"`
}

// GetTodaySummary 聚合用户今日复习汇总。
// streak 取 users.streak_days（与 SubmitReview 同源），失败回退 0。
func (s *ReviewService) GetTodaySummary(ctx context.Context, userID int64) (*TodaySummaryResponse, error) {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	end := start.Add(24 * time.Hour)

	summary, err := s.reviewRepo.GetTodaySummary(ctx, userID, start, end)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	streakDays := 0
	if user, err := s.userRepo.FindByID(ctx, userID); err == nil {
		streakDays = user.StreakDays
	}

	return &TodaySummaryResponse{
		TotalCount:      summary.TotalCount,
		MasteredCount:   summary.MasteredCount,
		PartialCount:    summary.PartialCount,
		FailedCount:     summary.FailedCount,
		DurationMinutes: summary.DurationSec / 60,
		StreakDays:      streakDays,
		EliminatedCount: summary.EliminatedCount,
	}, nil
}

// SubmitReviewRequest 提交复习结果请求
type SubmitReviewRequest struct {
	QuestionID        int64  `json:"question_id" binding:"required"`
	SelfRating        string `json:"self_rating" binding:"required"`
	ReviewDurationSec *int   `json:"review_duration_sec"`
	IsReviveCheck     bool   `json:"is_revive_check"`
	ReviveResult      string `json:"revive_result"` // REMEMBERED / FORGOTTEN
}

// SubmitReviewResponse 提交复习结果响应
type SubmitReviewResponse struct {
	QuestionID      int64  `json:"question_id"`
	NewStatus       string `json:"new_status"`
	NewReviewRound  int    `json:"new_review_round"`
	NewMasterCount  int    `json:"new_master_count"`
	NextReviewDate  string `json:"next_review_date,omitempty"`
	JustMastered    bool   `json:"just_mastered"`
	StreakDays      int    `json:"streak_days"`
	IsReviveFailed  bool   `json:"is_revive_failed,omitempty"`
	EncourageMessage string `json:"encourage_message,omitempty"`
}

// SubmitReview 提交复习结果
func (s *ReviewService) SubmitReview(ctx context.Context, userID int64, req SubmitReviewRequest) (*SubmitReviewResponse, error) {
	// 验证自评结果
	rating := scheduler.SelfRating(req.SelfRating)
	if !isValidSelfRating(rating) {
		return nil, errcode.ESelfRatingInvalid
	}

	// 检查复习用时
	if req.ReviewDurationSec != nil && *req.ReviewDurationSec < 0 {
		return nil, errcode.EReviewDurationNeg
	}

	// 处理复活检测
	if req.IsReviveCheck {
		return s.handleReviveCheck(ctx, userID, req)
	}

	// 获取错题
	question, err := s.questionRepo.FindByID(ctx, req.QuestionID)
	if err != nil {
		return nil, errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return nil, errcode.EQuestionBelongsToOther
	}

	// 检查是否今日已复习
	today := time.Now()
	existing, _ := s.reviewRepo.FindByQuestionAndDate(ctx, req.QuestionID, userID, today)
	if existing != nil {
		return nil, errcode.EReviewAlreadyDone
	}

	// 计算新的复习计划
	plan := scheduler.ReviewPlan{
		QuestionID:   question.ID,
		UserID:       userID,
		CurrentRound: question.ReviewRound,
		MasterCount:  question.MasterCount,
	}

	nextDate, newRound, newMasterCount := s.strategy.CalcNextReview(plan, rating)

	// 确定新状态
	newStatus := model.StatusReviewing
	justMastered := false

	if newMasterCount >= 3 {
		newStatus = model.StatusMastered
		justMastered = true
	} else if question.Status == model.StatusNotStarted {
		newStatus = model.StatusReviewing
	}

	// 更新错题
	if err := s.questionRepo.UpdateReviewPlan(ctx, question.ID, newStatus, newRound, newMasterCount, nextDate); err != nil {
		return nil, errcode.EInternalServer
	}

	// 创建复习记录
	record := &model.ReviewRecord{
		QuestionID:        question.ID,
		UserID:            userID,
		ReviewRound:       question.ReviewRound,
		SelfRating:        model.SelfRating(req.SelfRating),
		MasterCountAfter:  newMasterCount,
		ReviewDurationSec: req.ReviewDurationSec,
	}
	if err := s.reviewRepo.Create(ctx, record); err != nil {
		return nil, errcode.EInternalServer
	}

	// 更新打卡天数：原子更新（单条 SQL，当天只 +1 一次，并发不叠加）。
	// streak 更新失败不应让整个 SubmitReview 失败，回退用旧值并记录日志。
	streakDays := 0
	if newStreak, err := s.userRepo.UpdateStreakOnActivity(ctx, userID); err != nil {
		log.Printf("[WARN] UpdateStreakOnActivity failed for user %d: %v", userID, err)
		if user, ferr := s.userRepo.FindByID(ctx, userID); ferr == nil {
			streakDays = user.StreakDays
		}
	} else {
		streakDays = newStreak
	}

	resp := &SubmitReviewResponse{
		QuestionID:     question.ID,
		NewStatus:      string(newStatus),
		NewReviewRound: newRound,
		NewMasterCount: newMasterCount,
		JustMastered:   justMastered,
		StreakDays:     streakDays,
	}
	if !nextDate.IsZero() {
		resp.NextReviewDate = nextDate.Format("2006-01-02")
	}

	return resp, nil
}

func (s *ReviewService) handleReviveCheck(ctx context.Context, userID int64, req SubmitReviewRequest) (*SubmitReviewResponse, error) {
	if req.ReviveResult == "" {
		return nil, errcode.EReviveResultRequired
	}
	if req.ReviveResult != "REMEMBERED" && req.ReviveResult != "FORGOTTEN" {
		return nil, errcode.EReviveResultInvalid
	}

	question, err := s.questionRepo.FindByID(ctx, req.QuestionID)
	if err != nil {
		return nil, errcode.EQuestionNotFound
	}
	if question.UserID != userID {
		return nil, errcode.EQuestionBelongsToOther
	}
	if question.Status != model.StatusMastered {
		return nil, errcode.New(errcode.ErrReviveCheckNotAllowed, "该错题不需要复活检测", 400)
	}

	currentInterval := 30
	if question.ReviveCheckInterval != nil {
		currentInterval = *question.ReviveCheckInterval
	}

	if req.ReviveResult == "REMEMBERED" {
		nextInterval := scheduler.GetNextReviveInterval(currentInterval)
		if nextInterval == 0 {
			// 永久消灭
			s.questionRepo.MarkPermanentlyMastered(ctx, question.ID)
			// 复活检测同样写 ReviewRecord，保证复习历史/weekly_completed 反映复活检测。
			// REMEMBERED → 自评 MASTERED，master_count_after 保持 3（已消灭）。
			s.createReviveReviewRecord(ctx, question, userID, req, model.RatingMastered, 3)
			return s.applyStreakUpdate(ctx, userID, &SubmitReviewResponse{
				QuestionID:     question.ID,
				NewStatus:      string(model.StatusPermanentlyMastered),
				NewMasterCount: 3,
				JustMastered:   false,
			}), nil
		}
		nextDate := time.Now().AddDate(0, 0, nextInterval)
		s.questionRepo.UpdateReviveSchedule(ctx, question.ID, nextInterval, nextDate)
		s.createReviveReviewRecord(ctx, question, userID, req, model.RatingMastered, 3)
		return s.applyStreakUpdate(ctx, userID, &SubmitReviewResponse{
			QuestionID:     question.ID,
			NewStatus:      string(model.StatusMastered),
			NewMasterCount: 3,
			NextReviewDate: nextDate.Format("2006-01-02"),
		}), nil
	} else {
		// 复活失败
		nextDate := time.Now().AddDate(0, 0, 1)
		s.questionRepo.ResetReviewPlan(ctx, question.ID, nextDate)
		// 复活失败 → 自评 FAILED，master_count_after 归 0（复习计划已重置）。
		s.createReviveReviewRecord(ctx, question, userID, req, model.RatingFailed, 0)
		return s.applyStreakUpdate(ctx, userID, &SubmitReviewResponse{
			QuestionID:       question.ID,
			NewStatus:        string(model.StatusReviewing),
			NewReviewRound:   1,
			NewMasterCount:   0,
			NextReviewDate:   nextDate.Format("2006-01-02"),
			IsReviveFailed:   true,
			EncourageMessage: "这道题需要再巩固一下哦！加油",
		}), nil
	}
}

// createReviveReviewRecord 为复活检测创建一条 ReviewRecord，与正常 SubmitReview
// 路径一致（含 review_duration_sec / self_rating / review_round / master_count_after）。
// 复习记录写入失败不应阻断复活检测主流程（题状态已更新），仅记日志——
// 与 streak 更新的容错策略保持一致，避免因记录写入失败回滚已生效的消灭/复活。
func (s *ReviewService) createReviveReviewRecord(
	ctx context.Context,
	question *model.Question,
	userID int64,
	req SubmitReviewRequest,
	rating model.SelfRating,
	masterCountAfter int,
) {
	record := buildReviveReviewRecord(question, userID, req, rating, masterCountAfter)
	if err := s.reviewRepo.Create(ctx, record); err != nil {
		log.Printf("[WARN] create revive ReviewRecord failed for question %d: %v", question.ID, err)
	}
}

// buildReviveReviewRecord 纯函数：构造复活检测的 ReviewRecord。
// 抽出便于单测（无需 DB），保证字段与正常 SubmitReview 路径一致：
//   - QuestionID / UserID / ReviewRound 取自 question（复活复习的轮次=已消灭时的轮次）
//   - SelfRating：REMEMBERED→MASTERED，FORGOTTEN→FAILED
//   - MasterCountAfter：REMEMBERED→3，FORGOTTEN→0
//   - ReviewDurationSec：透传请求里的复习用时
func buildReviveReviewRecord(
	question *model.Question,
	userID int64,
	req SubmitReviewRequest,
	rating model.SelfRating,
	masterCountAfter int,
) *model.ReviewRecord {
	return &model.ReviewRecord{
		QuestionID:        question.ID,
		UserID:            userID,
		ReviewRound:       question.ReviewRound,
		SelfRating:        rating,
		MasterCountAfter:  masterCountAfter,
		ReviewDurationSec: req.ReviewDurationSec,
	}
}

// applyStreakUpdate 复活检测/复习活跃后更新打卡天数并填回响应。
// streak 更新失败不阻断主流程，回退用旧 StreakDays（复活复习同样计活跃）。
func (s *ReviewService) applyStreakUpdate(ctx context.Context, userID int64, resp *SubmitReviewResponse) *SubmitReviewResponse {
	if newStreak, err := s.userRepo.UpdateStreakOnActivity(ctx, userID); err != nil {
		log.Printf("[WARN] UpdateStreakOnActivity failed for user %d (revive): %v", userID, err)
		if user, ferr := s.userRepo.FindByID(ctx, userID); ferr == nil {
			resp.StreakDays = user.StreakDays
		}
	} else {
		resp.StreakDays = newStreak
	}
	return resp
}

// GetReviewHistory 获取复习历史
func (s *ReviewService) GetReviewHistory(ctx context.Context, userID int64, page, pageSize int) ([]model.ReviewRecord, int64, error) {
	return s.reviewRepo.ListByUser(ctx, userID, page, pageSize)
}

func isValidSelfRating(rating scheduler.SelfRating) bool {
	switch rating {
	case scheduler.RatingMastered, scheduler.RatingPartial, scheduler.RatingFailed:
		return true
	default:
		return false
	}
}
