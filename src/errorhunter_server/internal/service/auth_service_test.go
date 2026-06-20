package service

import (
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"github.com/stretchr/testify/assert"
)

// TestGradeMapping_ValidGrades 验证所有有效年级的映射正确性
func TestGradeMapping_ValidGrades(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected model.Grade
	}{
		{"小学三年级", "3", model.Grade31},
		{"小学四年级", "4", model.Grade32},
		{"小学五年级", "5", model.Grade33},
		{"小学六年级", "6", model.Grade34},
		{"初中一年级", "7", model.Grade71},
		{"初中二年级", "8", model.Grade72},
		{"初中三年级", "9", model.Grade73},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			grade, err := mapFrontendGrade(tt.input)
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, grade)
		})
	}
}

// TestGradeMapping_InvalidGrades 验证无效年级返回错误
func TestGradeMapping_InvalidGrades(t *testing.T) {
	invalidInputs := []string{"", "0", "1", "2", "10", "abc", "-1", "3.5"}

	for _, input := range invalidInputs {
		t.Run("invalid_"+input, func(t *testing.T) {
			_, err := mapFrontendGrade(input)
			assert.Error(t, err)
			assert.Contains(t, err.Error(), "invalid grade")
		})
	}
}
