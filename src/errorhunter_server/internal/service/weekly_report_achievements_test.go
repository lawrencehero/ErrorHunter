package service

import (
	"encoding/json"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/stretchr/testify/assert"
)

// TestBuildAchievementsJSONB_Rules 覆盖成就生成各规则触发/不触发、互斥与组合。
//
// 规则（见 buildAchievementsJSONB 注释）：
//   streak≥7 → "全勤王者"（与 ≥5 互斥，只给王者）
//   streak≥5 → "连续打卡达人"
//   mastered≥10 → "消灭能手"
//   review>0 && accuracy≥75 → "高正确率"
//   new≥5 → "勤勉录入"
//   review≥20 → "复习达人"
func TestBuildAchievementsJSONB_Rules(t *testing.T) {
	t.Run("空周：无任何成就", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 0, 0.0, 0)
		assert.Equal(t, model.JSONB("[]"), got, "空周应返回 []")
	})

	t.Run("全勤王者：streak=7 与 streak≥5 互斥，只给王者", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 0, 0.0, 7)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "全勤王者")
		assert.NotContains(t, s, "连续打卡达人", "streak≥7 时不应再给连续打卡达人")
	})

	t.Run("连续打卡达人：streak=5 但不满 7", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 0, 0.0, 5)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "连续打卡达人")
		assert.NotContains(t, s, "全勤王者")
	})

	t.Run("streak=6 仍为连续打卡达人", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 0, 0.0, 6)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "连续打卡达人")
		assert.NotContains(t, s, "全勤王者")
	})

	t.Run("消灭能手：mastered≥10", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 10, 0, 0.0, 0)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "消灭能手")
	})

	t.Run("消灭能手边界：mastered=9 不触发", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 9, 0, 0.0, 0)
		s := mustStringSlice(t, got)
		assert.NotContains(t, s, "消灭能手")
	})

	t.Run("高正确率：review>0 且 accuracy≥75", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 1, 75.0, 0)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "高正确率")
	})

	t.Run("高正确率不触发：accuracy≥75 但 review=0", func(t *testing.T) {
		// 无复习记录时不算正确率成就，避免空样本误导
		got := buildAchievementsJSONB(0, 0, 0, 100.0, 0)
		s := mustStringSlice(t, got)
		assert.NotContains(t, s, "高正确率")
	})

	t.Run("高正确率边界：accuracy=74.99 不触发", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 1, 74.99, 0)
		s := mustStringSlice(t, got)
		assert.NotContains(t, s, "高正确率")
	})

	t.Run("勤勉录入：new≥5", func(t *testing.T) {
		got := buildAchievementsJSONB(5, 0, 0, 0.0, 0)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "勤勉录入")
	})

	t.Run("勤勉录入边界：new=4 不触发", func(t *testing.T) {
		got := buildAchievementsJSONB(4, 0, 0, 0.0, 0)
		s := mustStringSlice(t, got)
		assert.NotContains(t, s, "勤勉录入")
	})

	t.Run("复习达人：review≥20", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 20, 0.0, 0)
		s := mustStringSlice(t, got)
		assert.Contains(t, s, "复习达人")
	})

	t.Run("复习达人边界：review=19 不触发", func(t *testing.T) {
		got := buildAchievementsJSONB(0, 0, 19, 0.0, 0)
		s := mustStringSlice(t, got)
		assert.NotContains(t, s, "复习达人")
	})
}

// TestBuildAchievementsJSONB_AllCombined 所有规则同时命中：
// "全勤王者"与"连续打卡达人"互斥（streak≥7 只给王者），故 5 条规则全开 = 5 条成就。
func TestBuildAchievementsJSONB_AllCombined(t *testing.T) {
	got := buildAchievementsJSONB(5, 10, 20, 75.0, 7)
	s := mustStringSlice(t, got)
	assert.Len(t, s, 5)
	assert.Contains(t, s, "全勤王者")
	assert.Contains(t, s, "消灭能手")
	assert.Contains(t, s, "高正确率")
	assert.Contains(t, s, "勤勉录入")
	assert.Contains(t, s, "复习达人")
	// streak≥7 不应再叠加"连续打卡达人"
	assert.NotContains(t, s, "连续打卡达人")
}

// TestBuildAchievementsJSONB_AllExceptKing streak=5（非全勤）时其余规则全开：
// 此时"连续打卡达人"生效，"全勤王者"不触发，共 5 条成就。
func TestBuildAchievementsJSONB_AllExceptKing(t *testing.T) {
	got := buildAchievementsJSONB(5, 10, 20, 75.0, 5)
	s := mustStringSlice(t, got)
	assert.Len(t, s, 5)
	assert.Contains(t, s, "连续打卡达人")
	assert.Contains(t, s, "消灭能手")
	assert.Contains(t, s, "高正确率")
	assert.Contains(t, s, "勤勉录入")
	assert.Contains(t, s, "复习达人")
	assert.NotContains(t, s, "全勤王者", "streak=5 不应触发全勤王者")
}

// TestBuildAchievementsJSONB_ReturnsValidJSON 验证返回的是合法 JSON 数组，
// 可被 model.JSONB.ToStringSlice 正确反序列化。
func TestBuildAchievementsJSONB_ReturnsValidJSON(t *testing.T) {
	got := buildAchievementsJSONB(5, 10, 1, 80.0, 5)
	// 应为合法 JSON
	var raw []string
	assert.NoError(t, json.Unmarshal(got, &raw))
	assert.NotEmpty(t, raw)
	// model.JSONB.ToStringSlice 也能解出
	s, err := got.ToStringSlice()
	assert.NoError(t, err)
	assert.Equal(t, raw, s)
}

// TestBuildAchievementsJSONB_EmptyIsJSONArray 空周返回字面量 "[]"，可被反序列化为空切片。
func TestBuildAchievementsJSONB_EmptyIsJSONArray(t *testing.T) {
	got := buildAchievementsJSONB(0, 0, 0, 0.0, 0)
	assert.Equal(t, "[]", string(got))
	var raw []string
	assert.NoError(t, json.Unmarshal(got, &raw))
	assert.Empty(t, raw)
}

func mustStringSlice(t *testing.T, j model.JSONB) []string {
	t.Helper()
	s, err := j.ToStringSlice()
	assert.NoError(t, err)
	return s
}
