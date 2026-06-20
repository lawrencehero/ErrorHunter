package model

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestUser_MaskPhone_Normal 正常11位手机号脱敏
func TestUser_MaskPhone_Normal(t *testing.T) {
	u := &User{Phone: "13812345678"}
	assert.Equal(t, "138****5678", u.MaskPhone())
}

// TestUser_MaskPhone_Short 非11位手机号不脱敏
func TestUser_MaskPhone_Short(t *testing.T) {
	u := &User{Phone: "1234"}
	assert.Equal(t, "1234", u.MaskPhone())
}

// TestUser_MaskPhone_Empty 空手机号
func TestUser_MaskPhone_Empty(t *testing.T) {
	u := &User{Phone: ""}
	assert.Equal(t, "", u.MaskPhone())
}

// TestGrade_Stage 验证年级对应学段
func TestGrade_Stage(t *testing.T) {
	tests := []struct {
		grade    Grade
		expected Stage
	}{
		{Grade31, StagePrimary},
		{Grade32, StagePrimary},
		{Grade33, StagePrimary},
		{Grade34, StagePrimary},
		{Grade71, StageJunior},
		{Grade72, StageJunior},
		{Grade73, StageJunior},
	}

	for _, tt := range tests {
		t.Run(string(tt.grade), func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.grade.Stage())
		})
	}
}

// TestGrade_Stage_Unknown 未知年级默认小学
func TestGrade_Stage_Unknown(t *testing.T) {
	g := Grade("99")
	assert.Equal(t, StagePrimary, g.Stage())
}

// TestJSONB_ToStringSlice 字符串切片转换
func TestJSONB_ToStringSlice(t *testing.T) {
	j := JSONBFromSlice([]string{"a", "b", "c"})
	result, err := j.ToStringSlice()
	assert.NoError(t, err)
	assert.Equal(t, []string{"a", "b", "c"}, result)
}

// TestJSONB_ToStringSlice_Null null值返回nil
func TestJSONB_ToStringSlice_Null(t *testing.T) {
	var j JSONB
	result, err := j.ToStringSlice()
	assert.NoError(t, err)
	assert.Nil(t, result)
}

// TestJSONB_IsNull 判断是否为null
func TestJSONB_IsNull(t *testing.T) {
	var empty JSONB
	assert.True(t, empty.IsNull())

	null := JSONB("null")
	assert.True(t, null.IsNull())

	valid := JSONBFromSlice([]string{"test"})
	assert.False(t, valid.IsNull())
}

// TestJSONB_Value_DriverValuer driver.Valuer 接口
func TestJSONB_Value_DriverValuer(t *testing.T) {
	j := JSONB(`["a","b"]`)
	val, err := j.Value()
	assert.NoError(t, err)
	assert.Equal(t, `["a","b"]`, val)

	var empty JSONB
	val, err = empty.Value()
	assert.NoError(t, err)
	assert.Nil(t, val)
}

// TestJSONB_Scan_SqlScanner sql.Scanner 接口
func TestJSONB_Scan_SqlScanner(t *testing.T) {
	var j JSONB

	err := j.Scan([]byte(`["x","y"]`))
	assert.NoError(t, err)
	assert.Equal(t, JSONB(`["x","y"]`), j)

	err = j.Scan(`["a"]`)
	assert.NoError(t, err)
	assert.Equal(t, JSONB(`["a"]`), j)

	err = j.Scan(nil)
	assert.NoError(t, err)
	assert.Equal(t, JSONB("null"), j)
}

// TestJSONB_MarshalUnmarshal JSON 序列化/反序列化
func TestJSONB_MarshalUnmarshal_JSON(t *testing.T) {
	original := JSONBFromSlice([]string{"hello", "world"})

	data, err := original.MarshalJSON()
	assert.NoError(t, err)

	var restored JSONB
	err = restored.UnmarshalJSON(data)
	assert.NoError(t, err)
	assert.Equal(t, original, restored)
}

// TestTableNames 验证表名
func TestTableNames(t *testing.T) {
	assert.Equal(t, "users", User{}.TableName())
	assert.Equal(t, "questions", Question{}.TableName())
	assert.Equal(t, "review_records", ReviewRecord{}.TableName())
	assert.Equal(t, "knowledge_points", KnowledgePoint{}.TableName())
	assert.Equal(t, "weekly_reports", WeeklyReport{}.TableName())
	assert.Equal(t, "sync_queue", SyncQueue{}.TableName())
	assert.Equal(t, "user_devices", UserDevice{}.TableName())
}
