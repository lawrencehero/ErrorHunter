package service

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/errorhunter/errorhunter-server/internal/pkg/scheduler"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
		ReviewItems:   []*model.Question{},
		ReviveItems:   []*model.Question{},
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

// TestReviewQueueResponse_JSONKeys 守护修复1的 JSON 契约：复习队列响应必须含
// review_items / revive_items 两个 key（而非历史的 items），且每项为完整 Question 形状。
// 若有人把 ReviewItems/ReviveItems 改回 items 命名，或改成自定义精简结构体，
// 本测试会立即失败——这是"复习队列恒空"bug 的核心回退守护。
func TestReviewQueueResponse_JSONKeys(t *testing.T) {
	// 构造含一题的复习队列响应（复活项留空，重点验证 review_items）
	now := time.Now()
	q := &model.Question{
		ID:           42,
		UserID:       7,
		Status:       model.StatusReviewing,
		ImageURL:     "http://example.com/v1/files/questions/7/abc.jpg",
		ErrorCategory: model.ErrorKnowledge,
		ReviewRound:  2,
		MasterCount:  1,
		CreatedAt:    now,
		// 后端在返回题目前由 service 填充 TotalReviewRounds = len(EbbinghausIntervals)
		TotalReviewRounds: len(scheduler.EbbinghausIntervals),
		KnowledgePoints: []model.KnowledgePoint{
			{ID: 1, Name: "加减法", Level: 1},
		},
	}
	resp := &ReviewQueueResponse{
		ReviewItems:   []*model.Question{q},
		ReviveItems:   []*model.Question{},
		TotalCount:    1,
		ReviveCount:   0,
		HasMore:       false,
		OverflowCount: 0,
	}

	raw, err := json.Marshal(resp)
	require.NoError(t, err, "ReviewQueueResponse 应可序列化")
	jsonStr := string(raw)

	// 1) 守护：必须存在 review_items / revive_items key（前端 QuestionModel.fromJson 依赖）
	assert.True(t, strings.Contains(jsonStr, `"review_items"`),
		"响应 JSON 必须含 review_items key，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"revive_items"`),
		"响应 JSON 必须含 revive_items key，got: %s", jsonStr)

	// 2) 守护：必须不存在 items key（回退到旧命名会立即失败）
	assert.False(t, strings.Contains(jsonStr, `"items"`),
		"响应 JSON 不得含 items key（应为 review_items/revive_items），got: %s", jsonStr)

	// 3) 守护：review_items 内的题目必须是完整 Question 形状，
	// 覆盖前端 QuestionModel.fromJson 依赖的字段。
	assert.True(t, strings.Contains(jsonStr, `"image_url"`),
		"review_items 题目应序列化出 image_url，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"status"`),
		"review_items 题目应序列化出 status，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"created_at"`),
		"review_items 题目应序列化出 created_at，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"knowledge_points"`),
		"review_items 题目应序列化出 knowledge_points，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"error_category"`),
		"review_items 题目应序列化出 error_category，got: %s", jsonStr)

	// 4) 文档化现状（非 bug，是既有字段名不匹配的固化）：
	//    后端 Question.ReviewRound 的 JSON tag 是 review_round，
	//    而前端 QuestionModel.fromJson 期望 current_review_round。
	//    若未来治理此不匹配（任一侧改名），更新下方断言；在此之前该不匹配被如实记录。
	assert.True(t, strings.Contains(jsonStr, `"review_round"`),
		"后端序列化复习轮次字段名为 review_round（现状固化），got: %s", jsonStr)
	assert.False(t, strings.Contains(jsonStr, `"current_review_round"`),
		"后端序列化不含 current_review_round（前端期望字段名，现状为不匹配），got: %s", jsonStr)

	// 5) 守护：后端显式返回 total_review_rounds（= len(EbbinghausIntervals)），
	//    不再依赖前端默认值。omitted 时前端可回退默认 5，但 service 返回前应赋值。
	assert.True(t, strings.Contains(jsonStr, `"total_review_rounds":5`),
		"review_items 题目应显式序列化 total_review_rounds=5（=艾宾浩斯总轮次），got: %s", jsonStr)
}

// TestBuildReviveReviewRecord_Remembered 复活检测 REMEMBERED 路径生成的 ReviewRecord
// 字段正确（#9 修复守护）：自评 MASTERED，master_count_after=3，轮次取自 question，
// 用时透传。复活检测历史上一条记录都不写，导致复习用时/历史丢失。
func TestBuildReviveReviewRecord_Remembered(t *testing.T) {
	duration := 45
	question := &model.Question{
		ID:          42,
		UserID:      7,
		ReviewRound: 5,
		Status:      model.StatusMastered,
	}
	req := SubmitReviewRequest{
		QuestionID:        42,
		ReviveResult:      "REMEMBERED",
		ReviewDurationSec: &duration,
	}

	rec := buildReviveReviewRecord(question, 7, req, model.RatingMastered, 3)

	assert.Equal(t, int64(42), rec.QuestionID)
	assert.Equal(t, int64(7), rec.UserID)
	assert.Equal(t, 5, rec.ReviewRound, "复活复习轮次取自 question.ReviewRound")
	assert.Equal(t, model.RatingMastered, rec.SelfRating, "REMEMBERED → MASTERED")
	assert.Equal(t, 3, rec.MasterCountAfter, "已消灭题 master_count_after 保持 3")
	require.NotNil(t, rec.ReviewDurationSec)
	assert.Equal(t, 45, *rec.ReviewDurationSec, "复习用时透传到记录")
}

// TestBuildReviveReviewRecord_Forgotten 复活检测 FORGOTTEN 路径生成的 ReviewRecord
// 字段正确（#9 修复守护）：自评 FAILED，master_count_after=0（复习计划已重置）。
func TestBuildReviveReviewRecord_Forgotten(t *testing.T) {
	question := &model.Question{
		ID:          42,
		UserID:      7,
		ReviewRound: 4,
		Status:      model.StatusMastered,
	}
	req := SubmitReviewRequest{
		QuestionID:   42,
		ReviveResult: "FORGOTTEN",
		// ReviewDurationSec 为 nil（前端未传用时）
	}

	rec := buildReviveReviewRecord(question, 7, req, model.RatingFailed, 0)

	assert.Equal(t, model.RatingFailed, rec.SelfRating, "FORGOTTEN → FAILED")
	assert.Equal(t, 0, rec.MasterCountAfter, "复活失败 → master_count 归 0")
	assert.Equal(t, 4, rec.ReviewRound)
	assert.Nil(t, rec.ReviewDurationSec, "未传用时记录里也应是 nil")
}

// TestBuildReviveReviewRecord_FieldParityWithNormalPath 守护：复活检测生成的记录
// 字段集合与正常 SubmitReview 路径一致（同一 ReviewRecord model），保证
// weekly_completed / 复习历史统计能正确反映复活检测。
func TestBuildReviveReviewRecord_FieldParityWithNormalPath(t *testing.T) {
	duration := 30
	question := &model.Question{ID: 1, UserID: 2, ReviewRound: 3}
	req := SubmitReviewRequest{ReviewDurationSec: &duration}

	rec := buildReviveReviewRecord(question, 2, req, model.RatingPartial, 1)

	// 与 review_service.go SubmitReview 正常路径构造的 record 字段一一对应
	assert.Equal(t, question.ID, rec.QuestionID)
	assert.Equal(t, question.UserID, rec.UserID)
	assert.Equal(t, question.ReviewRound, rec.ReviewRound)
	assert.Equal(t, model.RatingPartial, rec.SelfRating)
	assert.Equal(t, 1, rec.MasterCountAfter)
	assert.Equal(t, &duration, rec.ReviewDurationSec)
}
