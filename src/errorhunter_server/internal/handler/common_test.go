package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// ===== 测试辅助函数 =====

// testContext 创建带可选用户认证的gin测试上下文
type testContext struct {
	router *gin.Engine
	userID int64
}

// newTestCtx 创建测试上下文
func newTestCtx() *testContext {
	return &testContext{router: gin.New()}
}

// withUser 设置认证用户
func (tc *testContext) withUser(userID int64) *testContext {
	tc.userID = userID
	return tc
}

// postRoute 注册POST路由
func (tc *testContext) postRoute(path string, handler gin.HandlerFunc) *testContext {
	tc.router.POST(path, func(c *gin.Context) {
		if tc.userID > 0 {
			c.Set(middleware.ContextKeyUserID, tc.userID)
		}
		handler(c)
	})
	return tc
}

// getRoute 注册GET路由
func (tc *testContext) getRoute(path string, handler gin.HandlerFunc) *testContext {
	tc.router.GET(path, func(c *gin.Context) {
		if tc.userID > 0 {
			c.Set(middleware.ContextKeyUserID, tc.userID)
		}
		handler(c)
	})
	return tc
}

// putRoute 注册PUT路由
func (tc *testContext) putRoute(path string, handler gin.HandlerFunc) *testContext {
	tc.router.PUT(path, func(c *gin.Context) {
		if tc.userID > 0 {
			c.Set(middleware.ContextKeyUserID, tc.userID)
		}
		handler(c)
	})
	return tc
}

// deleteRoute 注册DELETE路由
func (tc *testContext) deleteRoute(path string, handler gin.HandlerFunc) *testContext {
	tc.router.DELETE(path, func(c *gin.Context) {
		if tc.userID > 0 {
			c.Set(middleware.ContextKeyUserID, tc.userID)
		}
		handler(c)
	})
	return tc
}

// doRequest 发送请求并返回响应记录器
func (tc *testContext) doRequest(method, path string, body interface{}, headers map[string]string) *httptest.ResponseRecorder {
	var buf bytes.Buffer
	if body != nil {
		json.NewEncoder(&buf).Encode(body)
	}
	req, _ := http.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	tc.router.ServeHTTP(w, req)
	return w
}

// doRequestRaw 发送原始字节请求体
func (tc *testContext) doRequestRaw(method, path string, rawBody []byte, headers map[string]string) *httptest.ResponseRecorder {
	req, _ := http.NewRequest(method, path, bytes.NewReader(rawBody))
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	tc.router.ServeHTTP(w, req)
	return w
}

// parseJSON 解析响应JSON
func parseJSON(t *testing.T, w *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var resp map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &resp)
	require.NoError(t, err, "响应应为有效JSON, got: %s", w.Body.String())
	return resp
}

// assertErrorCode 断言响应包含指定错误码
func assertErrorCode(t *testing.T, w *httptest.ResponseRecorder, expectedCode int) {
	t.Helper()
	resp := parseJSON(t, w)
	code, ok := resp["code"].(float64)
	require.True(t, ok, "响应应包含数字code字段")
	assert.Equal(t, float64(expectedCode), code, "错误码不匹配")
}

// assertSuccess 断言响应为成功
func assertSuccess(t *testing.T, w *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	resp := parseJSON(t, w)
	code, ok := resp["code"].(float64)
	require.True(t, ok, "响应应包含数字code字段")
	assert.Equal(t, float64(0), code, "应为成功响应(code=0)")
	return resp
}

// tc_doRequest 独立router请求辅助函数（不依赖testContext）
func tc_doRequest(router *gin.Engine, method, path string, body interface{}, headers map[string]string) *httptest.ResponseRecorder {
	var buf bytes.Buffer
	if body != nil {
		json.NewEncoder(&buf).Encode(body)
	}
	req, _ := http.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

// ===== 通用响应格式测试 =====

func TestRespondSuccess_Format(t *testing.T) {
	tc := newTestCtx()
	tc.getRoute("/test", func(c *gin.Context) {
		respondSuccess(c, map[string]string{"key": "value"})
	})

	w := tc.doRequest("GET", "/test", nil, nil)
	assert.Equal(t, http.StatusOK, w.Code)
	resp := parseJSON(t, w)
	assert.Equal(t, float64(0), resp["code"])
	assert.Equal(t, "success", resp["message"])
	assert.NotNil(t, resp["data"])
}

func TestRespondCreated_Format(t *testing.T) {
	tc := newTestCtx()
	tc.postRoute("/test", func(c *gin.Context) {
		respondCreated(c, map[string]string{"id": "123"})
	})

	w := tc.doRequest("POST", "/test", nil, nil)
	assert.Equal(t, http.StatusCreated, w.Code)
	resp := parseJSON(t, w)
	assert.Equal(t, float64(0), resp["code"])
	assert.Equal(t, "created", resp["message"])
}

func TestRespondError_Format(t *testing.T) {
	tc := newTestCtx()
	tc.getRoute("/test", func(c *gin.Context) {
		respondError(c, errcode.EUnauthorized)
	})

	w := tc.doRequest("GET", "/test", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestRespondNoContent_Format(t *testing.T) {
	tc := newTestCtx()
	tc.deleteRoute("/test", func(c *gin.Context) {
		respondNoContent(c)
	})

	w := tc.doRequest("DELETE", "/test", nil, nil)
	assert.Equal(t, http.StatusNoContent, w.Code)
	assert.Empty(t, w.Body.String())
}

func TestRespondError_WithData(t *testing.T) {
	tc := newTestCtx()
	tc.getRoute("/test", func(c *gin.Context) {
		respondError(c, errcode.EParamValidation.WithData("field 'name' is required"))
	})

	w := tc.doRequest("GET", "/test", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	resp := parseJSON(t, w)
	assert.Equal(t, float64(errcode.ErrParamValidation), resp["code"])
	assert.Equal(t, "field 'name' is required", resp["data"])
}
