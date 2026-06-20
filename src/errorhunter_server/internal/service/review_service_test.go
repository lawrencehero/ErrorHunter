package service

import (
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/pkg/scheduler"
	"github.com/stretchr/testify/assert"
)

// TestIsValidSelfRating_Valid 验证有效自评结果
func TestIsValidSelfRating_Valid(t *testing.T) {
	validRatings := []scheduler.SelfRating{
		scheduler.RatingMastered,
		scheduler.RatingPartial,
		scheduler.RatingFailed,
	}

	for _, rating := range validRatings {
		t.Run(string(rating), func(t *testing.T) {
			assert.True(t, isValidSelfRating(rating))
		})
	}
}

// TestIsValidSelfRating_Invalid 验证无效自评结果
func TestIsValidSelfRating_Invalid(t *testing.T) {
	invalidRatings := []scheduler.SelfRating{
		"",
		"INVALID",
		"mastered", // 大小写敏感
		"CORRECT",
		"WRONG",
	}

	for _, rating := range invalidRatings {
		t.Run(string(rating), func(t *testing.T) {
			assert.False(t, isValidSelfRating(rating))
		})
	}
}

// TestReviewQueueResponse_Structure 复习队列响应结构验证
func TestReviewQueueResponse_Structure(t *testing.T) {
	resp := &ReviewQueueResponse{
		ReviewItems:   []ReviewItem{},
		ReviveItems:   []ReviveItem{},
		TotalCount:    0,
		ReviveCount:   0,
		HasMore:       false,
		OverflowCount: 0,
	}

	assert.Equal(t, 0, resp.TotalCount)
	assert.False(t, resp.HasMore)
	assert.Empty(t, resp.ReviewItems)
	assert.Empty(t, resp.ReviveItems)
}

// TestSubmitReviewResponse_Mastered 提交复习结果-掌握状态
func TestSubmitReviewResponse_Mastered(t *testing.T) {
	resp := &SubmitReviewResponse{
		QuestionID:     1,
		NewStatus:      "MASTERED",
		NewReviewRound: 5,
		NewMasterCount: 3,
		JustMastered:   true,
		StreakDays:     7,
	}

	assert.True(t, resp.JustMastered)
	assert.Equal(t, "MASTERED", resp.NewStatus)
	assert.Equal(t, 3, resp.NewMasterCount)
}

// TestSubmitReviewResponse_ReviveFailed 复活失败响应
func TestSubmitReviewResponse_ReviveFailed(t *testing.T) {
	resp := &SubmitReviewResponse{
		QuestionID:       2,
		NewStatus:        "REVIEWING",
		NewReviewRound:   1,
		NewMasterCount:   0,
		IsReviveFailed:   true,
		EncourageMessage: "这道题需要再巩固一下哦！加油",
	}

	assert.True(t, resp.IsReviveFailed)
	assert.NotEmpty(t, resp.EncourageMessage)
	assert.Equal(t, 1, resp.NewReviewRound)
	assert.Equal(t, 0, resp.NewMasterCount)
}
