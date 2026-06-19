package scheduler

import (
	"sort"
	"time"
)

// EbbinghausIntervals 艾宾浩斯5轮间隔天数
var EbbinghausIntervals = [5]int{1, 2, 4, 7, 16}

// ReviewPlan 复习计划
type ReviewPlan struct {
	QuestionID     int64
	UserID         int64
	CurrentRound   int       // 当前轮次 1-5
	MasterCount    int       // 消灭计数 0-3
	NextReviewDate time.Time
}

// SelfRating 自评结果
type SelfRating string

const (
	RatingMastered SelfRating = "MASTERED"
	RatingPartial  SelfRating = "PARTIAL"
	RatingFailed   SelfRating = "FAILED"
)

// ScheduleStrategy 调度策略接口（策略模式）
type ScheduleStrategy interface {
	Name() string
	CalcNextReview(plan ReviewPlan, rating SelfRating) (nextDate time.Time, newRound int, newMasterCount int)
	IsCompleted(plan ReviewPlan) bool
	GetIntervalDays(round int) int
}

// EbbinghausStrategy 艾宾浩斯策略
type EbbinghausStrategy struct{}

func (s *EbbinghausStrategy) Name() string { return "ebbinghaus" }

func (s *EbbinghausStrategy) GetIntervalDays(round int) int {
	if round < 1 || round > 5 {
		return 0
	}
	return EbbinghausIntervals[round-1]
}

// CalcNextReview 核心调度逻辑
func (s *EbbinghausStrategy) CalcNextReview(
	plan ReviewPlan, rating SelfRating,
) (nextDate time.Time, newRound int, newMasterCount int) {
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	switch rating {
	case RatingMastered:
		newMasterCount = plan.MasterCount + 1
		newRound = plan.CurrentRound + 1
		if newRound > 5 {
			nextDate = time.Time{} // 完成所有轮次
		} else {
			nextDate = today.AddDate(0, 0, s.GetIntervalDays(newRound))
		}
	case RatingPartial:
		newMasterCount = plan.MasterCount
		newRound = plan.CurrentRound
		nextDate = today.AddDate(0, 0, s.GetIntervalDays(newRound))
	case RatingFailed:
		newMasterCount = 0
		newRound = 1
		nextDate = today.AddDate(0, 0, s.GetIntervalDays(1))
	default:
		newMasterCount = plan.MasterCount
		newRound = plan.CurrentRound
		nextDate = today.AddDate(0, 0, s.GetIntervalDays(newRound))
	}
	return
}

// IsCompleted 判断是否满足消灭条件
func (s *EbbinghausStrategy) IsCompleted(plan ReviewPlan) bool {
	return plan.CurrentRound > 5 && plan.MasterCount >= 3
}

// DefaultDailyLimit 默认每日复习上限
const DefaultDailyLimit = 20

// ReviewCandidate 复习候选
type ReviewCandidate struct {
	QuestionID     int64
	ReviewRound    int
	IntervalDays   int
	CreatedAt      int64
	NextReviewDate string
}

// ApplyDailyLimit 应用每日上限，优先级：轮次高 > 间隔长 > 录入早
func ApplyDailyLimit(candidates []ReviewCandidate, limit int) (today, deferred []ReviewCandidate) {
	sort.Slice(candidates, func(i, j int) bool {
		a, b := candidates[i], candidates[j]
		if a.ReviewRound != b.ReviewRound {
			return a.ReviewRound > b.ReviewRound
		}
		if a.IntervalDays != b.IntervalDays {
			return a.IntervalDays > b.IntervalDays
		}
		return a.CreatedAt < b.CreatedAt
	})
	if len(candidates) <= limit {
		return candidates, nil
	}
	return candidates[:limit], candidates[limit:]
}

// BacklogThreshold 积压阈值
const BacklogThreshold = 50

// BacklogCandidate 积压候选
type BacklogCandidate struct {
	QuestionID   int64
	MasterCount  int // 越高越优先（接近消灭的不放弃）
	IntervalDays int // 越长越优先（逾期久更紧急）
	CreatedAt    int64
	ReviewRound  int
}

// SortBacklog 积压排序，优先级：消灭计数高 > 间隔时间长 > 录入时间早
func SortBacklog(candidates []BacklogCandidate) []BacklogCandidate {
	sort.Slice(candidates, func(i, j int) bool {
		a, b := candidates[i], candidates[j]
		if a.MasterCount != b.MasterCount {
			return a.MasterCount > b.MasterCount
		}
		if a.IntervalDays != b.IntervalDays {
			return a.IntervalDays > b.IntervalDays
		}
		return a.CreatedAt < b.CreatedAt
	})
	return candidates
}

// ReviveIntervals 复活检测间隔：30->60->90天
var ReviveIntervals = []int{30, 60, 90}

// GetNextReviveInterval 获取下一个复活检测间隔
func GetNextReviveInterval(current int) int {
	for i, v := range ReviveIntervals {
		if current == v {
			if i+1 < len(ReviveIntervals) {
				return ReviveIntervals[i+1]
			}
			return 0 // 永久消灭
		}
	}
	return 0
}
