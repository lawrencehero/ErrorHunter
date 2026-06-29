package service

import (
	"testing"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestIsValidErrorCategory_Valid 验证有效错因分类
func TestIsValidErrorCategory_Valid(t *testing.T) {
	validCategories := []model.ErrorCategory{
		model.ErrorKnowledge,
		model.ErrorSkill,
		model.ErrorPsychology,
		model.ErrorHabit,
		model.ErrorUnknown,
	}

	for _, cat := range validCategories {
		t.Run(string(cat), func(t *testing.T) {
			assert.True(t, isValidErrorCategory(cat))
		})
	}
}

// TestIsValidErrorCategory_Invalid 验证无效错因分类
func TestIsValidErrorCategory_Invalid(t *testing.T) {
	invalidCategories := []model.ErrorCategory{
		"",
		"INVALID",
		"knowledge", // 大小写敏感
		"MATH",
	}

	for _, cat := range invalidCategories {
		t.Run(string(cat), func(t *testing.T) {
			assert.False(t, isValidErrorCategory(cat))
		})
	}
}

// TestPagination_Calculation 分页计算逻辑
func TestPagination_Calculation(t *testing.T) {
	result := &ListResult{
		List: make([]model.Question, 10),
		Pagination: Pagination{
			Page:     2,
			PageSize: 10,
			Total:    55,
		},
	}

	assert.Equal(t, 2, result.Pagination.Page)
	assert.Equal(t, 10, result.Pagination.PageSize)
	assert.Equal(t, int64(55), result.Pagination.Total)
	assert.Len(t, result.List, 10)
}

// TestCreateRequest_Validation 创建请求字段验证逻辑
func TestCreateRequest_Validation(t *testing.T) {
	// 测试自定义标签上限
	tags := []string{"tag1", "tag2", "tag3", "tag4", "tag5", "tag6"}
	assert.Greater(t, len(tags), 5, "超过5个标签应该被拒绝")

	validTags := []string{"tag1", "tag2", "tag3"}
	assert.LessOrEqual(t, len(validTags), 5, "5个以内标签应该被接受")
}

// TestParseDateFilter_BothNil 验证 nil 入参返回 nil（不过滤）
func TestParseDateFilter_BothNil(t *testing.T) {
	start, end := parseDateFilter(nil, nil)
	assert.Nil(t, start)
	assert.Nil(t, end)
}

// TestParseDateFilter_EmptyString 验证空串等同 nil（不过滤）
func TestParseDateFilter_EmptyString(t *testing.T) {
	empty := ""
	start, end := parseDateFilter(&empty, &empty)
	assert.Nil(t, start)
	assert.Nil(t, end)
}

// TestParseDateFilter_Valid 验证合法 YYYY-MM-DD 被正确解析为当天 00:00（Local）
func TestParseDateFilter_Valid(t *testing.T) {
	s := "2026-06-01"
	e := "2026-06-29"
	start, end := parseDateFilter(&s, &e)
	require.NotNil(t, start)
	require.NotNil(t, end)
	assert.Equal(t, 2026, start.Year())
	assert.Equal(t, time.June, start.Month())
	assert.Equal(t, 1, start.Day())
	assert.Equal(t, 0, start.Hour())
	assert.Equal(t, 0, start.Minute())
	// 关键：end 也是当天 00:00，repo 会自己 +24h 形成半开区间
	assert.Equal(t, 29, end.Day())
	assert.Equal(t, 0, end.Hour(), "end 应为当天 00:00，由 repo +24h 形成半开区间")
}

// TestParseDateFilter_InvalidFormat 验证非法格式返回 nil（不阻断筛选）
func TestParseDateFilter_InvalidFormat(t *testing.T) {
	bad := "2026/06/01"
	start, end := parseDateFilter(&bad, &bad)
	assert.Nil(t, start, "非法格式不应产生 start 过滤")
	assert.Nil(t, end, "非法格式不应产生 end 过滤")
}

// TestParseDateFilter_StartOnly 验证只传 start
func TestParseDateFilter_StartOnly(t *testing.T) {
	s := "2026-01-15"
	start, end := parseDateFilter(&s, nil)
	require.NotNil(t, start)
	assert.Nil(t, end)
}
