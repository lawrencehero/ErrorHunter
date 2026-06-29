package model

import (
	"encoding/json"
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

// TestKnowledgePoint_MarshalJSON 验证 KnowledgePoint 序列化为与 /v1/knowledge-points
// 列表接口一致的 DTO（id/name/subject/parent_id(领域)/is_recommended），
// 从 keywords JSONB 解析。这是 #10 修复的核心守护：错题详情/列表/复习队列里
// 关联的知识点必须与知识点列表接口返回结构一致，否则前端 fromJson 回退默认值，
// 详情页推荐标记与学段丢失。
func TestKnowledgePoint_MarshalJSON(t *testing.T) {
	t.Run("keywords 含 subject/domain/is_recommended → 全部解析到 DTO", func(t *testing.T) {
		kp := KnowledgePoint{
			ID:   7,
			Name: "一元一次方程",
			Keywords: JSONBFromMap(map[string]interface{}{
				"grade":          "71",
				"domain":         "num",
				"subject":        "数学",
				"is_recommended": true,
			}),
		}
		raw, err := json.Marshal(kp)
		assert.NoError(t, err)
		var m map[string]interface{}
		assert.NoError(t, json.Unmarshal(raw, &m))

		assert.Equal(t, float64(7), m["id"])
		assert.Equal(t, "一元一次方程", m["name"])
		assert.Equal(t, "数学", m["subject"])
		assert.Equal(t, "num", m["parent_id"])
		assert.Equal(t, true, m["is_recommended"])

		// 守护：不输出原始 model 字段（level/stage/keywords/sort_order/version），
		// 保证与列表接口 DTO 形状一致。若有人改回直接序列化 model，这里会失败。
		for _, k := range []string{"level", "stage", "keywords", "sort_order", "version"} {
			_, ok := m[k]
			assert.False(t, ok, "DTO 不应输出 %s（与列表接口不一致），got: %s", k, string(raw))
		}
	})

	t.Run("keywords 为空 → subject 回退数学，is_recommended=false，parent_id 省略", func(t *testing.T) {
		kp := KnowledgePoint{ID: 1, Name: "自定义知识点"}
		raw, err := json.Marshal(kp)
		assert.NoError(t, err)
		var m map[string]interface{}
		assert.NoError(t, json.Unmarshal(raw, &m))

		assert.Equal(t, "数学", m["subject"], "缺省学段回退数学")
		assert.Equal(t, false, m["is_recommended"])
		_, hasParent := m["parent_id"]
		assert.False(t, hasParent, "无 domain 时 parent_id 应 omitempty 省略")
	})

	t.Run("keywords 非法 JSON → 回退默认值，不报错", func(t *testing.T) {
		kp := KnowledgePoint{ID: 2, Name: "x", Keywords: JSONB("{not json}")}
		raw, err := json.Marshal(kp)
		assert.NoError(t, err, "非法 keywords 不应让 MarshalJSON 失败")
		var m map[string]interface{}
		assert.NoError(t, json.Unmarshal(raw, &m))
		assert.Equal(t, "数学", m["subject"])
		assert.Equal(t, false, m["is_recommended"])
	})

	t.Run("is_recommended=false 时仍输出 key（与列表接口一致）", func(t *testing.T) {
		kp := KnowledgePoint{
			ID:   3,
			Name: "非推荐",
			Keywords: JSONBFromMap(map[string]interface{}{
				"domain":         "geo",
				"subject":        "数学",
				"is_recommended": false,
			}),
		}
		raw, err := json.Marshal(kp)
		assert.NoError(t, err)
		body := string(raw)
		assert.Contains(t, body, `"is_recommended":false`)
		assert.Contains(t, body, `"parent_id":"geo"`)
	})
}

// TestQuestion_ReviewRecordsSerialize 验证 Question 的非持久化 ReviewRecords 字段
// 被正确序列化为 review_records（#11 后端修复守护）。详情接口填充后前端 fromJson
// 据此渲染"复习历史"时间线；未填充(nil)时 omitempty 不输出。
func TestQuestion_ReviewRecordsSerialize(t *testing.T) {
	t.Run("填充 ReviewRecords → 序列化出 review_records 数组", func(t *testing.T) {
		q := Question{
			ID:     1,
			Status: StatusReviewing,
			ReviewRecords: []ReviewRecord{
				{ID: 10, QuestionID: 1, ReviewRound: 2, SelfRating: RatingMastered, MasterCountAfter: 3},
				{ID: 9, QuestionID: 1, ReviewRound: 1, SelfRating: RatingFailed, MasterCountAfter: 0},
			},
		}
		raw, err := json.Marshal(q)
		assert.NoError(t, err)
		body := string(raw)
		assert.Contains(t, body, `"review_records"`)
		assert.Contains(t, body, `"self_rating":"MASTERED"`)
		assert.Contains(t, body, `"self_rating":"FAILED"`)
		assert.Contains(t, body, `"review_round":2`)
		assert.Contains(t, body, `"master_count_after":3`)
	})

	t.Run("未填充 ReviewRecords(nil) → omitempty 不输出 key", func(t *testing.T) {
		q := Question{ID: 1, Status: StatusReviewing}
		raw, err := json.Marshal(q)
		assert.NoError(t, err)
		assert.NotContains(t, string(raw), `"review_records"`,
			"未填充时应 omitempty，避免前端误判为空数组")
	})
}

// TestWeeklyReport_JSON_OmitemptyAndAchievements 验证 WeeklyReport 新增字段的
// JSON 序列化语义：
//   - prev_week_review_count / prev_week_accuracy 为 *int / *float64 + omitempty，
//     nil 时不输出 key，非 nil 时输出值（包括 0）。
//   - achievements 为 JSONB（非指针），始终输出；空数组输出 "[]"。
//
// 这保证前端 fromDetailJson 能正确区分「首周无上周周报」（key 不存在 → delta 0）
// 与「上周复习次数=0」（key=0 → delta = 本周值）。
func TestWeeklyReport_JSON_OmitemptyAndAchievements(t *testing.T) {
	t.Run("首周：prev 指针为 nil → 对应 key 不输出；achievements 输出空数组", func(t *testing.T) {
		r := WeeklyReport{
			ID:             1,
			UserID:         100,
			WeekNumber:     202626,
			NewQuestions:   5,
			ReviewCount:    10,
			ReviewAccuracy: 80.0,
			Achievements:   JSONB("[]"),
			// PrevWeek* 全部 nil
		}
		raw, err := json.Marshal(r)
		assert.NoError(t, err)
		body := string(raw)

		assert.NotContains(t, body, "prev_week_new", "PrevWeekNew nil 应 omitempty")
		assert.NotContains(t, body, "prev_week_mastered", "PrevWeekMastered nil 应 omitempty")
		assert.NotContains(t, body, "prev_week_review_count", "PrevWeekReviewCount nil 应 omitempty")
		assert.NotContains(t, body, "prev_week_accuracy", "PrevWeekAccuracy nil 应 omitempty")

		// achievements 始终输出（非指针字段），空数组序列化为 "[]"
		assert.Contains(t, body, `"achievements":[]`)

		// 反序列化校验前端可见字段
		var m map[string]json.RawMessage
		assert.NoError(t, json.Unmarshal(raw, &m))
		_, hasReviewCount := m["prev_week_review_count"]
		assert.False(t, hasReviewCount, "首周不应有 prev_week_review_count")
		_, hasAccuracy := m["prev_week_accuracy"]
		assert.False(t, hasAccuracy, "首周不应有 prev_week_accuracy")
	})

	t.Run("非首周：prev 指针非 nil → 输出值（含 0）", func(t *testing.T) {
		zero := 0
		zeroAcc := 0.0
		r := WeeklyReport{
			ID:                     2,
			UserID:                 101,
			WeekNumber:             202627,
			NewQuestions:           3,
			ReviewCount:            10,
			ReviewAccuracy:         50.0,
			PrevWeekNew:            &zero,
			PrevWeekMastered:       &zero,
			PrevWeekReviewCount:    &zero,
			PrevWeekAccuracy:       &zeroAcc,
			Achievements:           JSONBFromSlice([]string{"连续打卡达人", "消灭能手"}),
		}
		raw, err := json.Marshal(r)
		assert.NoError(t, err)
		body := string(raw)

		// 非 nil 即使 0 也应输出（前端据此计算 delta=本周-0）
		assert.Contains(t, body, `"prev_week_review_count":0`)
		assert.Contains(t, body, `"prev_week_accuracy":0`)
		// achievements 数组应输出两条文案
		assert.Contains(t, body, `"achievements":["连续打卡达人","消灭能手"]`)
	})

	t.Run("achievements 始终输出，即便为零值 JSONB", func(t *testing.T) {
		r := WeeklyReport{ID: 3, UserID: 102, WeekNumber: 202626}
		raw, err := json.Marshal(r)
		assert.NoError(t, err)
		body := string(raw)
		// 零值 JSONB（len=0）MarshalJSON 返回 "null"（见 JSONB.MarshalJSON）
		// 这里只断言 key 存在，具体值由赋值方控制（service 层永远赋 "[]" 或真实数组）
		assert.Contains(t, body, `"achievements"`)
	})
}
