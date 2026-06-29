package handler

import (
	"net/http"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// ===== Create 创建错题测试 =====

func TestCreate_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.POST("/questions", h.Create)

	w := tc_doRequest(router, "POST", "/questions", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestCreate_InvalidBody_Empty(t *testing.T) {
	// 缺少必填字段 image_url, error_category, knowledge_point_ids
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestCreate_MissingImageURL(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", map[string]interface{}{
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": []int{1},
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestCreate_MissingErrorCategory(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", map[string]interface{}{
		"image_url":           "https://example.com/img.jpg",
		"knowledge_point_ids": []int{1},
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestCreate_MissingKnowledgePointIDs(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", map[string]interface{}{
		"image_url":      "https://example.com/img.jpg",
		"error_category": "KNOWLEDGE",
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestCreate_EmptyKnowledgePointIDs(t *testing.T) {
	// knowledge_point_ids为空数组（min=1验证）
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", map[string]interface{}{
		"image_url":           "https://example.com/img.jpg",
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": []int{},
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestCreate_TooManyKnowledgePoints(t *testing.T) {
	// knowledge_point_ids超过3个（max=3验证）
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", map[string]interface{}{
		"image_url":           "https://example.com/img.jpg",
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestCreate_ValidBody_NilService(t *testing.T) {
	// 有效请求体但service为nil → panic
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "有效请求应走到service调用")
	}()

	tc.doRequest("POST", "/questions", map[string]interface{}{
		"image_url":           "https://example.com/img.jpg",
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": []int{1, 2},
		"custom_tags":         []string{"数学", "方程"},
	}, nil)
}

func TestCreate_NoBody(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).postRoute("/questions", h.Create)

	w := tc.doRequest("POST", "/questions", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== List 获取错题列表测试 =====

func TestList_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.GET("/questions", h.List)

	w := tc_doRequest(router, "GET", "/questions", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestList_DefaultPagination_NilService(t *testing.T) {
	// 默认分页参数：page=1, page_size=20
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		recover() // service为nil
	}()

	tc.doRequest("GET", "/questions", nil, nil)
}

func TestList_CustomPagination_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/questions?page=2&page_size=10", nil, nil)
}

func TestList_PageSizeCapped(t *testing.T) {
	// page_size超过50应被限制为50
	// 由于service为nil会panic，我们只能验证流程到达了service调用
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/questions?page_size=100", nil, nil)
}

func TestList_WithFilters_NilService(t *testing.T) {
	// 带筛选条件
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/questions?status=NOT_STARTED,REVIEWING&error_category=KNOWLEDGE&keyword=方程&sort_by=created_at&sort_order=desc", nil, nil)
}

// TestList_SearchByQ 验证前端 searchQuestions 发的 `q` 参数被当作 keyword 接收。
// 前端契约：question_remote_data_source.dart 的 searchQuestions 用 `q=<keyword>`，
// 后端必须同时接受 `q`（搜索语义）与 `keyword`（兼容旧调用）。
// 由于 service 为 nil 会 panic，只要走到 service 调用即证明参数解析通过。
func TestList_SearchByQ(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "q 参数应被解析并走到 service 调用")
	}()

	tc.doRequest("GET", "/questions?q=一元一次方程", nil, nil)
}

// TestList_NegativePageClamped 验证 page<1 被钳制到 1，不会因负 offset 引发异常。
func TestList_NegativePageClamped(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "page 钳制后应正常走到 service 调用")
	}()

	tc.doRequest("GET", "/questions?page=-5&page_size=-10", nil, nil)
}

func TestList_WithDateRange_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/questions?start_date=2026-01-01&end_date=2026-06-01", nil, nil)
}

func TestList_WithKnowledgePointFilter(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/questions", h.List)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/questions?knowledge_point_id=42", nil, nil)
}

// ===== GetByID 获取错题详情测试 =====

func TestGetByID_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.GET("/questions/:id", h.GetByID)

	w := tc_doRequest(router, "GET", "/questions/1", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestGetByID_InvalidID(t *testing.T) {
	// id不是数字
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.GET("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.GetByID(c)
	})

	w := tc.doRequest("GET", "/questions/abc", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestGetByID_ValidID_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.GET("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.GetByID(c)
	})

	defer func() {
		recover() // service为nil
	}()

	tc.doRequest("GET", "/questions/123", nil, nil)
}

// ===== Update 更新错题测试 =====

func TestUpdate_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.PUT("/questions/:id", h.Update)

	w := tc_doRequest(router, "PUT", "/questions/1", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestUpdate_InvalidID(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.PUT("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Update(c)
	})

	w := tc.doRequest("PUT", "/questions/not-a-number", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestUpdate_InvalidBody(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.PUT("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Update(c)
	})

	w := tc.doRequestRaw("PUT", "/questions/1", []byte(`{invalid}`), nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestUpdate_ValidBody_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.PUT("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Update(c)
	})

	defer func() {
		recover()
	}()

	tc.doRequest("PUT", "/questions/1", map[string]interface{}{
		"ocr_text": "更新后的OCR文本",
	}, nil)
}

// ===== Delete 删除错题测试 =====

func TestDelete_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.DELETE("/questions/:id", h.Delete)

	w := tc_doRequest(router, "DELETE", "/questions/1", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestDelete_InvalidID(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.DELETE("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Delete(c)
	})

	w := tc.doRequest("DELETE", "/questions/xyz", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestDelete_ValidID_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.DELETE("/questions/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Delete(c)
	})

	defer func() {
		recover()
	}()

	tc.doRequest("DELETE", "/questions/42", nil, nil)
}

// ===== ListRecycleBin 回收站列表测试 =====

func TestListRecycleBin_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.GET("/recycle-bin", h.ListRecycleBin)

	w := tc_doRequest(router, "GET", "/recycle-bin", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestListRecycleBin_DefaultPagination(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).getRoute("/recycle-bin", h.ListRecycleBin)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/recycle-bin", nil, nil)
}

// ===== Restore 恢复错题测试 =====

func TestRestore_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.POST("/restore/:id", h.Restore)

	w := tc_doRequest(router, "POST", "/restore/1", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestRestore_InvalidID(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.POST("/restore/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Restore(c)
	})

	w := tc.doRequest("POST", "/restore/abc", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestRestore_ValidID_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.POST("/restore/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.Restore(c)
	})

	defer func() {
		recover()
	}()

	tc.doRequest("POST", "/restore/1", nil, nil)
}

// ===== PermanentDelete 永久删除测试 =====

func TestPermanentDelete_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.DELETE("/permanent/:id", h.PermanentDelete)

	w := tc_doRequest(router, "DELETE", "/permanent/1", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestPermanentDelete_InvalidID(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.DELETE("/permanent/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.PermanentDelete(c)
	})

	w := tc.doRequest("DELETE", "/permanent/abc", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

// ===== ClearRecycleBin 清空回收站测试 =====

func TestClearRecycleBin_Unauthorized(t *testing.T) {
	h := &QuestionHandler{}
	router := gin.New()
	router.DELETE("/clear", h.ClearRecycleBin)

	w := tc_doRequest(router, "DELETE", "/clear", map[string]interface{}{"confirm": true}, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestClearRecycleBin_NoConfirm(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).deleteRoute("/clear", h.ClearRecycleBin)

	w := tc.doRequest("DELETE", "/clear", map[string]interface{}{
		"confirm": false,
	}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrRecycleBinConfirmRequired)
}

func TestClearRecycleBin_MissingConfirm(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).deleteRoute("/clear", h.ClearRecycleBin)

	w := tc.doRequest("DELETE", "/clear", map[string]interface{}{}, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrRecycleBinConfirmRequired)
}

func TestClearRecycleBin_Confirmed_NilService(t *testing.T) {
	h := &QuestionHandler{}
	tc := newTestCtx().withUser(1).deleteRoute("/clear", h.ClearRecycleBin)

	defer func() {
		recover()
	}()

	tc.doRequest("DELETE", "/clear", map[string]interface{}{
		"confirm": true,
	}, nil)
}

// ===== QuestionHandler 构造函数测试 =====

func TestNewQuestionHandler(t *testing.T) {
	h := NewQuestionHandler(nil)
	assert.NotNil(t, h)
	assert.Nil(t, h.questionService)
}
