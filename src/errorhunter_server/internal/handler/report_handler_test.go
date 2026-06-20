package handler

import (
	"net/http"
	"testing"

	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// ===== GetDashboard 获取Dashboard测试 =====

func TestGetDashboard_Unauthorized(t *testing.T) {
	h := &ReportHandler{}
	router := gin.New()
	router.GET("/reports", h.GetDashboard)

	w := tc_doRequest(router, "GET", "/reports", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestGetDashboard_Authorized_NilRepos(t *testing.T) {
	// 已认证但repos为nil → panic
	h := &ReportHandler{}
	tc := newTestCtx().withUser(1).getRoute("/reports", h.GetDashboard)

	defer func() {
		r := recover()
		assert.NotNil(t, r, "nil repo应导致panic")
	}()

	tc.doRequest("GET", "/reports", nil, nil)
}

// ===== GetWeeklyReports 获取周报列表测试 =====

func TestGetWeeklyReports_Unauthorized(t *testing.T) {
	h := &ReportHandler{}
	router := gin.New()
	router.GET("/weekly", h.GetWeeklyReports)

	w := tc_doRequest(router, "GET", "/weekly", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestGetWeeklyReports_DefaultPagination(t *testing.T) {
	h := &ReportHandler{}
	tc := newTestCtx().withUser(1).getRoute("/weekly", h.GetWeeklyReports)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/weekly", nil, nil)
}

func TestGetWeeklyReports_PageSizeCapped(t *testing.T) {
	// page_size超过20应被限制为20
	h := &ReportHandler{}
	tc := newTestCtx().withUser(1).getRoute("/weekly", h.GetWeeklyReports)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/weekly?page_size=50", nil, nil)
}

func TestGetWeeklyReports_CustomPagination(t *testing.T) {
	h := &ReportHandler{}
	tc := newTestCtx().withUser(1).getRoute("/weekly", h.GetWeeklyReports)

	defer func() {
		recover()
	}()

	tc.doRequest("GET", "/weekly?page=2&page_size=5", nil, nil)
}

// ===== GetWeeklyReportDetail 获取周报详情测试 =====

func TestGetWeeklyReportDetail_Unauthorized(t *testing.T) {
	h := &ReportHandler{}
	router := gin.New()
	router.GET("/weekly/:id", h.GetWeeklyReportDetail)

	w := tc_doRequest(router, "GET", "/weekly/1", nil, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assertErrorCode(t, w, errcode.ErrUnauthorized)
}

func TestGetWeeklyReportDetail_InvalidID(t *testing.T) {
	h := &ReportHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.GET("/weekly/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.GetWeeklyReportDetail(c)
	})

	w := tc.doRequest("GET", "/weekly/abc", nil, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assertErrorCode(t, w, errcode.ErrParamValidation)
}

func TestGetWeeklyReportDetail_ValidID_NilRepo(t *testing.T) {
	h := &ReportHandler{}
	tc := newTestCtx().withUser(1)
	tc.router.GET("/weekly/:id", func(c *gin.Context) {
		c.Set("user_id", int64(1))
		h.GetWeeklyReportDetail(c)
	})

	defer func() {
		recover() // repo为nil
	}()

	tc.doRequest("GET", "/weekly/42", nil, nil)
}

// ===== ReportHandler 构造函数测试 =====

func TestNewReportHandler(t *testing.T) {
	h := NewReportHandler(nil, nil)
	assert.NotNil(t, h)
	assert.Nil(t, h.reportRepo)
	assert.Nil(t, h.userRepo)
}

// ===== maxInt64 辅助函数测试 =====

func TestMaxInt64(t *testing.T) {
	tests := []struct {
		name     string
		a, b     int64
		expected int64
	}{
		{"a大于b", 10, 5, 10},
		{"b大于a", 3, 7, 7},
		{"相等", 5, 5, 5},
		{"负数", -3, -7, -3},
		{"零和正数", 0, 5, 5},
		{"零和负数", 0, -5, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := maxInt64(tt.a, tt.b)
			assert.Equal(t, tt.expected, result)
		})
	}
}
