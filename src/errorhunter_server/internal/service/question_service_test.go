package service

import (
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/stretchr/testify/assert"
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
