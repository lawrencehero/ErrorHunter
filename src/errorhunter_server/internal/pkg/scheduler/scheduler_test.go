package scheduler

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// TestEbbinghausIntervals 验证艾宾浩斯间隔天数
func TestEbbinghausIntervals(t *testing.T) {
	expected := [5]int{1, 2, 4, 7, 16}
	assert.Equal(t, expected, EbbinghausIntervals)
}

// TestGetIntervalDays_ValidRounds 验证有效轮次的间隔天数
func TestGetIntervalDays_ValidRounds(t *testing.T) {
	s := &EbbinghausStrategy{}

	tests := []struct {
		round    int
		expected int
	}{
		{1, 1},
		{2, 2},
		{3, 4},
		{4, 7},
		{5, 16},
	}

	for _, tt := range tests {
		t.Run("round", func(t *testing.T) {
			assert.Equal(t, tt.expected, s.GetIntervalDays(tt.round))
		})
	}
}

// TestGetIntervalDays_InvalidRounds 无效轮次返回0
func TestGetIntervalDays_InvalidRounds(t *testing.T) {
	s := &EbbinghausStrategy{}

	assert.Equal(t, 0, s.GetIntervalDays(0))
	assert.Equal(t, 0, s.GetIntervalDays(-1))
	assert.Equal(t, 0, s.GetIntervalDays(6))
	assert.Equal(t, 0, s.GetIntervalDays(100))
}

// TestCalcNextReview_Mastered 自评掌握：masterCount+1，进入下一轮
func TestCalcNextReview_Mastered(t *testing.T) {
	s := &EbbinghausStrategy{}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	plan := ReviewPlan{
		QuestionID:   1,
		UserID:       1,
		CurrentRound: 1,
		MasterCount:  0,
	}

	nextDate, newRound, newMasterCount := s.CalcNextReview(plan, RatingMastered)

	assert.Equal(t, 1, newMasterCount)
	assert.Equal(t, 2, newRound)
	assert.Equal(t, today.AddDate(0, 0, 2), nextDate) // round 2 interval = 2 days
}

// TestCalcNextReview_Mastered_FinalRound 最后一轮掌握后无下次复习
func TestCalcNextReview_Mastered_FinalRound(t *testing.T) {
	s := &EbbinghausStrategy{}

	plan := ReviewPlan{
		QuestionID:   1,
		UserID:       1,
		CurrentRound: 5,
		MasterCount:  2,
	}

	nextDate, newRound, newMasterCount := s.CalcNextReview(plan, RatingMastered)

	assert.Equal(t, 3, newMasterCount)
	assert.Equal(t, 6, newRound)
	assert.True(t, nextDate.IsZero()) // 完成所有轮次
}

// TestCalcNextReview_Partial 部分记得：masterCount不变，当前轮次重复
func TestCalcNextReview_Partial(t *testing.T) {
	s := &EbbinghausStrategy{}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	plan := ReviewPlan{
		QuestionID:   1,
		UserID:       1,
		CurrentRound: 3,
		MasterCount:  1,
	}

	nextDate, newRound, newMasterCount := s.CalcNextReview(plan, RatingPartial)

	assert.Equal(t, 1, newMasterCount) // 不变
	assert.Equal(t, 3, newRound)       // 不变
	assert.Equal(t, today.AddDate(0, 0, 4), nextDate) // round 3 interval = 4
}

// TestCalcNextReview_Failed 完全忘记：masterCount归零，回到第1轮
func TestCalcNextReview_Failed(t *testing.T) {
	s := &EbbinghausStrategy{}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	plan := ReviewPlan{
		QuestionID:   1,
		UserID:       1,
		CurrentRound: 4,
		MasterCount:  2,
	}

	nextDate, newRound, newMasterCount := s.CalcNextReview(plan, RatingFailed)

	assert.Equal(t, 0, newMasterCount) // 归零
	assert.Equal(t, 1, newRound)       // 回到第1轮
	assert.Equal(t, today.AddDate(0, 0, 1), nextDate) // round 1 interval = 1
}

// TestIsCompleted 判断是否满足消灭条件
func TestIsCompleted(t *testing.T) {
	s := &EbbinghausStrategy{}

	tests := []struct {
		name     string
		plan     ReviewPlan
		expected bool
	}{
		{"已完成", ReviewPlan{CurrentRound: 6, MasterCount: 3}, true},
		{"轮次不够", ReviewPlan{CurrentRound: 5, MasterCount: 3}, false},
		{"计数不够", ReviewPlan{CurrentRound: 6, MasterCount: 2}, false},
		{"都不够", ReviewPlan{CurrentRound: 3, MasterCount: 1}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, s.IsCompleted(tt.plan))
		})
	}
}

// TestApplyDailyLimit_UnderLimit 题目数未超限全部返回today
func TestApplyDailyLimit_UnderLimit(t *testing.T) {
	candidates := []ReviewCandidate{
		{QuestionID: 1, ReviewRound: 1},
		{QuestionID: 2, ReviewRound: 2},
	}

	today, deferred := ApplyDailyLimit(candidates, 5)
	assert.Len(t, today, 2)
	assert.Nil(t, deferred)
}

// TestApplyDailyLimit_OverLimit 超限时按优先级截断
func TestApplyDailyLimit_OverLimit(t *testing.T) {
	candidates := []ReviewCandidate{
		{QuestionID: 1, ReviewRound: 1, CreatedAt: 100},
		{QuestionID: 2, ReviewRound: 3, CreatedAt: 200},
		{QuestionID: 3, ReviewRound: 5, CreatedAt: 300},
		{QuestionID: 4, ReviewRound: 2, CreatedAt: 50},
		{QuestionID: 5, ReviewRound: 4, CreatedAt: 150},
	}

	today, deferred := ApplyDailyLimit(candidates, 3)
	assert.Len(t, today, 3)
	assert.Len(t, deferred, 2)

	// 优先级：轮次高优先 → 应该包含 round 5, 4, 3
	todayIDs := make(map[int64]bool)
	for _, c := range today {
		todayIDs[c.QuestionID] = true
	}
	assert.True(t, todayIDs[3]) // round 5
	assert.True(t, todayIDs[5]) // round 4
	assert.True(t, todayIDs[2]) // round 3
}

// TestApplyDailyLimit_ExactlyAtLimit 恰好等于限制
func TestApplyDailyLimit_ExactlyAtLimit(t *testing.T) {
	candidates := []ReviewCandidate{
		{QuestionID: 1, ReviewRound: 1},
		{QuestionID: 2, ReviewRound: 2},
		{QuestionID: 3, ReviewRound: 3},
	}

	today, deferred := ApplyDailyLimit(candidates, 3)
	assert.Len(t, today, 3)
	assert.Nil(t, deferred)
}

// TestGetNextReviveInterval 复活检测间隔递进
func TestGetNextReviveInterval(t *testing.T) {
	tests := []struct {
		current  int
		expected int
	}{
		{30, 60},
		{60, 90},
		{90, 0},  // 永久消灭
		{0, 0},   // 未知值
		{15, 0},  // 非标准值
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			assert.Equal(t, tt.expected, GetNextReviveInterval(tt.current))
		})
	}
}

// TestSortBacklog 积压排序：消灭计数高 > 间隔时间长 > 录入时间早
func TestSortBacklog(t *testing.T) {
	candidates := []BacklogCandidate{
		{QuestionID: 1, MasterCount: 0, IntervalDays: 1, CreatedAt: 100},
		{QuestionID: 2, MasterCount: 2, IntervalDays: 4, CreatedAt: 200},
		{QuestionID: 3, MasterCount: 2, IntervalDays: 7, CreatedAt: 300},
		{QuestionID: 4, MasterCount: 1, IntervalDays: 2, CreatedAt: 50},
	}

	sorted := SortBacklog(candidates)

	// 优先级：MasterCount desc → IntervalDays desc → CreatedAt asc
	assert.Equal(t, int64(3), sorted[0].QuestionID) // MC=2, ID=7
	assert.Equal(t, int64(2), sorted[1].QuestionID) // MC=2, ID=4
	assert.Equal(t, int64(4), sorted[2].QuestionID) // MC=1, ID=2
	assert.Equal(t, int64(1), sorted[3].QuestionID) // MC=0, ID=1
}

// TestEbbinghausStrategy_Name 策略名称
func TestEbbinghausStrategy_Name(t *testing.T) {
	s := &EbbinghausStrategy{}
	assert.Equal(t, "ebbinghaus", s.Name())
}
