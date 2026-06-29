package handler

import (
	"net/http"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// ===== GetQueue 获取复习队列测试 =====

func TestGetQueue_Unauthorized(t *testing.T) {
	h := &ReviewHandler{}
	router := gin.New()
	router.GET("/queue", h.GetQueue)

	w := tc_doRequest(router, "GET", "/queue", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestGetQueue_Authorized_NilDeps(t *testing.T) {
	// 已认证但 userRepo/service 均为 nil → panic（先在 userRepo.FindByID 处）
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).getRoute("/queue", h.GetQueue)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "nil 依赖应导致panic")
	}()

	tc.doRequest("GET", "/queue", nil, nil)
}

// ===== SubmitResult 提交复习结果测试 =====

func TestSubmitResult_Unauthorized(t *testing.T) {
	h := &ReviewHandler{}
	router := gin.New()
	router.POST("/result", h.SubmitResult)

	w := tc_doRequest(router, "POST", "/result", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestSubmitResult_InvalidBody_Empty(t *testing.T) {
	// 缺少必填字段 question_id, self_rating
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).postRoute("/result", h.SubmitResult)

	w := tc.doRequest("POST", "/result", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestSubmitResult_MissingQuestionID(t *testing.T) {
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).postRoute("/result", h.SubmitResult)

	w := tc.doRequest("POST", "/result", map[string]interface{}{
		"self_rating": "MASTERED",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestSubmitResult_MissingSelfRating(t *testing.T) {
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).postRoute("/result", h.SubmitResult)

	w := tc.doRequest("POST", "/result", map[string]interface{}{
		"question_id": 1,
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestSubmitResult_ValidBody_NilService(t *testing.T) {
	// 有效请求体，验证通过绑定后到达service调用
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).postRoute("/result", h.SubmitResult)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "有效请求应走到service调用")
	}()

	tc.doRequest("POST", "/result", map[string]interface{}{
		"question_id":         1,
		"self_rating":         "MASTERED",
		"review_duration_sec": 60,
	}, nil)
}

func TestSubmitResult_ReviveCheck_NoResult(t *testing.T) {
	// is_revive_check=true 但缺少 revive_result
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).postRoute("/result", h.SubmitResult)

	defer func() {
		recover() // service为nil
	}()

	// 注意：binding层面不会拦截revive_result（非required），所以会走到service层
	tc.doRequest("POST", "/result", map[string]interface{}{
		"question_id":     1,
		"self_rating":     "MASTERED",
		"is_revive_check": true,
	}, nil)
}

func TestSubmitResult_NoBody(t *testing.T) {
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).postRoute("/result", h.SubmitResult)

	w := tc.doRequest("POST", "/result", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== GetHistory 获取复习历史测试 =====

func TestGetHistory_Unauthorized(t *testing.T) {
	h := &ReviewHandler{}
	router := gin.New()
	router.GET("/history", h.GetHistory)

	w := tc_doRequest(router, "GET", "/history", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestGetHistory_DefaultPagination_NilService(t *testing.T) {
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).getRoute("/history", h.GetHistory)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/history", nil, nil)
}

func TestGetHistory_CustomPagination(t *testing.T) {
	h := &ReviewHandler{}
	tc := newTestCtx().withUser(1).getRoute("/history", h.GetHistory)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/history?page=3&page_size=50", nil, nil)
}

// ===== ReviewHandler 构造函数测试 =====

func TestNewReviewHandler(t *testing.T) {
	h := NewReviewHandler(nil, nil)
	assert.NotNil(t, h)
	assert.Nil(t, h.reviewService)
	assert.Nil(t, h.userRepo)
}
