package service

import (
	"context"
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
type ReviewQueueResponse struct {
	ReviewItems   []ReviewItem `json:"review_items"`
	ReviveItems   []ReviveItem `json:"revive_items"`
	TotalCount    int          `json:"total_count"`
	ReviveCount   int          `json:"revive_count"`
	HasMore       bool         `json:"has_more"`
	OverflowCount int          `json:"overflow_count"`
}

// ReviewItem 复习项
type ReviewItem struct {
	ID               int64                 `json:"id"`
	Type             string                `json:"type"` // NORMAL
	ImageURL         string                `json:"image_url"`
	OcrText          string                `json:"ocr_text,omitempty"`
	CorrectAnswer    string                `json:"correct_answer,omitempty"`
	MyAnswer         string                `json:"my_answer,omitempty"`
	SolutionSteps    []string              `json:"solution_steps,omitempty"`
	ErrorCategory    string                `json:"error_category"`
	ErrorSubCategory string                `json:"error_sub_category,omitempty"`
	ReviewRound      int                   `json:"review_round"`
	KnowledgePoints  []KnowledgePointBrief `json:"knowledge_points"`
}

// ReviveItem 复活检测项
type ReviveItem struct {
	ID                  int64  `json:"id"`
	Type                string `json:"type"` // REVIVE_CHECK
	Label               string `json:"label"`
	ImageURL            string `json:"image_url"`
	OcrText             string `json:"ocr_text,omitempty"`
	CorrectAnswer       string `json:"correct_answer,omitempty"`
	MasteredAt          string `json:"mastered_at"`
	ReviveCheckInterval int    `json:"revive_check_interval"`
}

// KnowledgePointBrief 知识点简要
type KnowledgePointBrief struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Level int16  `json:"level"`
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
	var reviewItems []ReviewItem
	overflowCount := 0
	if len(dueQuestions) > dailyLimit {
		overflowCount = len(dueQuestions) - dailyLimit
		dueQuestions = dueQuestions[:dailyLimit]
	}

	for _, q := range dueQuestions {
		item := ReviewItem{
			ID:            q.ID,
			Type:          "NORMAL",
			ImageURL:      q.ImageURL,
			ReviewRound:   q.ReviewRound,
			ErrorCategory: string(q.ErrorCategory),
		}
		if q.OcrText != nil {
			item.OcrText = *q.OcrText
		}
		if q.CorrectAnswer != nil {
			item.CorrectAnswer = *q.CorrectAnswer
		}
		if q.MyAnswer != nil {
			item.MyAnswer = *q.MyAnswer
		}
		if q.ErrorSubCategory != nil {
			item.ErrorSubCategory = *q.ErrorSubCategory
		}
		steps, _ := q.SolutionSteps.ToStringSlice()
		item.SolutionSteps = steps

		for _, kp := range q.KnowledgePoints {
			item.KnowledgePoints = append(item.KnowledgePoints, KnowledgePointBrief{
				ID:    kp.ID,
				Name:  kp.Name,
				Level: kp.Level,
			})
		}
		reviewItems = append(reviewItems, item)
	}

	// 获取复活检测题目（最多3道）
	reviveQuestions, err := s.questionRepo.GetReviveCandidates(ctx, userID, today, 3)
	if err != nil {
		return nil, errcode.EInternalServer
	}

	var reviveItems []ReviveItem
	for _, q := range reviveQuestions {
		interval := 30
		if q.ReviveCheckInterval != nil {
			interval = *q.ReviveCheckInterval
		}
		item := ReviveItem{
			ID:                  q.ID,
			Type:                "REVIVE_CHECK",
			Label:               "复习巩固",
			ImageURL:            q.ImageURL,
			ReviveCheckInterval: interval,
		}
		if q.OcrText != nil {
			item.OcrText = *q.OcrText
		}
		if q.CorrectAnswer != nil {
			item.CorrectAnswer = *q.CorrectAnswer
		}
		if q.MasteredAt != nil {
			item.MasteredAt = q.MasteredAt.Format(time.RFC3339)
		}
		reviveItems = append(reviveItems, item)
	}

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

	// 更新打卡天数（简化处理）
	user, _ := s.userRepo.FindByID(ctx, userID)
	streakDays := user.StreakDays

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
			return &SubmitReviewResponse{
				QuestionID:     question.ID,
				NewStatus:      string(model.StatusPermanentlyMastered),
				NewMasterCount: 3,
				JustMastered:   false,
			}, nil
		}
		nextDate := time.Now().AddDate(0, 0, nextInterval)
		s.questionRepo.UpdateReviveSchedule(ctx, question.ID, nextInterval, nextDate)
		return &SubmitReviewResponse{
			QuestionID:     question.ID,
			NewStatus:      string(model.StatusMastered),
			NewMasterCount: 3,
			NextReviewDate: nextDate.Format("2006-01-02"),
		}, nil
	} else {
		// 复活失败
		nextDate := time.Now().AddDate(0, 0, 1)
		s.questionRepo.ResetReviewPlan(ctx, question.ID, nextDate)
		return &SubmitReviewResponse{
			QuestionID:       question.ID,
			NewStatus:        string(model.StatusReviewing),
			NewReviewRound:   1,
			NewMasterCount:   0,
			NextReviewDate:   nextDate.Format("2006-01-02"),
			IsReviveFailed:   true,
			EncourageMessage: "这道题需要再巩固一下哦！加油",
		}, nil
	}
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
