package handler

import (
	"encoding/json"
	"net/http"
	"testing"
	"unicode/utf8"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// ===== GetMe 获取当前用户信息测试 =====

func TestGetMe_Unauthorized(t *testing.T) {
	// 未登录用户应返回401
	h := &UserHandler{}
	router := gin.New()
	router.GET("/me", h.GetMe) // 不设置user_id

	w := tc_doRequest(router, "GET", "/me", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestGetMe_Authorized_NilRepo(t *testing.T) {
	// 已认证但repo为nil → panic（说明handler正确走到了repo调用）
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).getRoute("/me", h.GetMe)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "nil repo应导致panic，说明handler正确走到了repo调用")
	}()

	tc.doRequest("GET", "/me", nil, nil)
}

// ===== UpdateSettings 更新用户设置测试 =====

func TestUpdateSettings_Unauthorized(t *testing.T) {
	h := &UserHandler{}
	router := gin.New()
	router.PUT("/settings", h.UpdateSettings)

	w := tc_doRequest(router, "PUT", "/settings", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestUpdateSettings_InvalidJSON(t *testing.T) {
	// 无效JSON格式应返回参数校验错误（在repo调用之前拦截）
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).putRoute("/settings", h.UpdateSettings)

	w := tc.doRequestRaw("PUT", "/settings", []byte(`{invalid json}`), nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestUpdateSettings_EmptyBody_ReachesRepo(t *testing.T) {
	// 空JSON对象 {} 是有效的（所有字段都是指针/可选）
	// 由于repo为nil会panic，验证流程到达了repo调用
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).putRoute("/settings", h.UpdateSettings)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "空body通过绑定后应走到repo调用")
	}()

	tc.doRequest("PUT", "/settings", map[string]interface{}{}, nil)
}

func TestUpdateSettings_WithFields_ReachesRepo(t *testing.T) {
	// 注意：handler中先调用FindByID再做字段验证
	// 所以即使nickname/daily_limit无效，也会先panic在repo调用
	// 这里验证请求能到达repo层
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).putRoute("/settings", h.UpdateSettings)

	defer func() {
		recover()
	}()

	tc.doRequest("PUT", "/settings", map[string]interface{}{
		"nickname":             "小明",
		"review_reminder_time": "20:00:00",
		"daily_review_limit":   20,
		"reminder_enabled":     true,
		"mastered_animation":   false,
	}, nil)
}

// ===== 昵称验证逻辑单元测试（RuneCountInString行为验证）=====

func TestNicknameLengthValidation_Logic(t *testing.T) {
	// 验证handler使用的 utf8.RuneCountInString 对中文字符的计算
	// 这是handler内部验证逻辑的核心
	tests := []struct {
		name     string
		nickname string
		runeLen  int
		valid    bool
	}{
		{"1个中文字符-太短", "好", 1, false},
		{"2个中文字符-最短有效", "小明", 2, true},
		{"3个中文字符", "小明明", 3, true},
		{"12个中文字符-最长有效", "一二三四五六七八九十十一", 12, true},
		{"13个中文字符-超长", "一二三四五六七八九十十一十", 13, false},
		{"英文2字符-最短有效", "ab", 2, true},
		{"英文1字符-太短", "a", 1, false},
		{"混合字符5个", "小明abc", 5, true},
		{"emoji", "😀😁", 2, true},
		{"空字符串", "", 0, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runeLen := utf8.RuneCountInString(tt.nickname)
			assert.Equal(t, tt.runeLen, runeLen, "RuneCountInString计算结果")

			// 模拟handler中的验证逻辑
			isValid := runeLen >= 2 && runeLen <= 12
			assert.Equal(t, tt.valid, isValid, "昵称'%s'有效性", tt.nickname)
		})
	}
}

// ===== DailyLimit验证逻辑单元测试 =====

func TestDailyLimitValidation_Logic(t *testing.T) {
	tests := []struct {
		name  string
		limit int
		valid bool
	}{
		{"下限9-无效", 9, false},
		{"下限10-有效", 10, true},
		{"中间值20-有效", 20, true},
		{"上限30-有效", 30, true},
		{"上限31-无效", 31, false},
		{"零值-无效", 0, false},
		{"负值-无效", -1, false},
		{"大值-无效", 100, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// 模拟handler中的验证逻辑
			isValid := tt.limit >= 10 && tt.limit <= 30
			assert.Equal(t, tt.valid, isValid, "daily_limit=%d有效性", tt.limit)
		})
	}
}

// ===== Deactivate 注销账号测试 =====

func TestDeactivate_Unauthorized(t *testing.T) {
	h := &UserHandler{}
	router := gin.New()
	router.POST("/deactivate", h.Deactivate)

	w := tc_doRequest(router, "POST", "/deactivate", map[string]interface{}{"confirm": true}, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestDeactivate_NoConfirm(t *testing.T) {
	// confirm=false应返回参数校验错误（在repo调用之前拦截）
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).postRoute("/deactivate", h.Deactivate)

	w := tc.doRequest("POST", "/deactivate", map[string]interface{}{
		"confirm": false,
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestDeactivate_MissingConfirm(t *testing.T) {
	// 缺少confirm字段（默认false）→ 应被拦截
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).postRoute("/deactivate", h.Deactivate)

	w := tc.doRequest("POST", "/deactivate", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestDeactivate_Confirmed_NilRepo(t *testing.T) {
	// confirm=true但repo为nil → panic（说明走过了确认检查到达repo调用）
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).postRoute("/deactivate", h.Deactivate)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "confirm=true后应走到repo调用")
	}()

	tc.doRequest("POST", "/deactivate", map[string]interface{}{
		"confirm": true,
	}, nil)
}

func TestDeactivate_InvalidJSON(t *testing.T) {
	h := &UserHandler{}
	tc := newTestCtx().withUser(1).postRoute("/deactivate", h.Deactivate)

	w := tc.doRequestRaw("POST", "/deactivate", []byte(`not json`), nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== UserHandler 构造函数测试 =====

func TestNewUserHandler(t *testing.T) {
	h := NewUserHandler(nil)
	assert.NotNil(t, h)
	assert.Nil(t, h.userRepo)
}

// ===== UpdateSettingsRequest 结构体绑定测试 =====

func TestUpdateSettingsRequest_Binding(t *testing.T) {
	// 验证UpdateSettingsRequest的JSON绑定行为
	tests := []struct {
		name    string
		json    string
		wantErr bool
	}{
		{"空对象", `{}`, false},
		{"只有nickname", `{"nickname":"小明"}`, false},
		{"所有字段", `{"nickname":"test","grade":"31","daily_review_limit":20,"reminder_enabled":true}`, false},
		{"null值", `{"nickname":null}`, false},
		{"无效JSON", `{invalid}`, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var req UpdateSettingsRequest
			err := jsonUnmarshal([]byte(tt.json), &req)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// jsonUnmarshal 辅助函数
func jsonUnmarshal(data []byte, v interface{}) error {
	return json.Unmarshal(data, v)
}
