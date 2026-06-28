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
func (s *ReviewService) GetReviewQueue(ctx context.Context, userID int64, dailyLimit int) (*ReviewQueueResponse, error) {
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

	return &ReviewQueueResponse{
		ReviewItems:   reviewItems,
		ReviveItems:   reviveItems,
		TotalCount:    len(reviewItems) + len(reviveItems),
		ReviveCount:   len(reviveItems),
		HasMore:       overflowCount > 0,
		OverflowCount: overflowCount,
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
			return s.applyStreakUpdate(ctx, userID, &SubmitReviewResponse{
				QuestionID:     question.ID,
				NewStatus:      string(model.StatusPermanentlyMastered),
				NewMasterCount: 3,
				JustMastered:   false,
			}), nil
		}
		nextDate := time.Now().AddDate(0, 0, nextInterval)
		s.questionRepo.UpdateReviveSchedule(ctx, question.ID, nextInterval, nextDate)
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
