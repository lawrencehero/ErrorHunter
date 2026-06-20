//go:build integration

package handler_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/handler"
	"github.com/errorhunter/errorhunter-server/internal/middleware"
	jwtPkg "github.com/errorhunter/errorhunter-server/internal/pkg/jwt"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// ============================================================
// 集成测试基础设施
// 需要 Docker Compose 测试环境运行：
//   docker compose -f deploy/docker-compose.test.yml up -d
// 运行方式：
//   go test -tags=integration -v -count=1 ./internal/handler/
// ============================================================

var (
	testDB          *gorm.DB
	testRedis       *redis.Client
	testJWTMgr      *jwtPkg.Manager
	testRouter      *gin.Engine
	testAuthHandler *handler.AuthHandler
	testQHandler    *handler.QuestionHandler
	testRHandler    *handler.ReviewHandler
	testRptHandler  *handler.ReportHandler
	testUserHandler *handler.UserHandler
)

func TestMain(m *testing.M) {
	gin.SetMode(gin.TestMode)

	// 从环境变量读取配置（Docker Compose 测试环境设置）
	cfg := loadTestConfig()

	// 初始化数据库连接
	var err error
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		getEnvOrDefault("EH_DATABASE_HOST", "localhost"),
		getEnvOrDefault("EH_DATABASE_PORT", "5432"),
		getEnvOrDefault("EH_DATABASE_USER", "errorhunter"),
		getEnvOrDefault("EH_DATABASE_PASSWORD", "errorhunter_dev"),
		getEnvOrDefault("EH_DATABASE_DBNAME", "errorhunter_test"),
		getEnvOrDefault("EH_DATABASE_SSLMODE", "disable"),
	)
	testDB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Printf("Failed to connect to test database: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("✓ Connected to test database")

	// 初始化 Redis
	testRedis = redis.NewClient(&redis.Options{
		Addr: getEnvOrDefault("EH_REDIS_ADDR", "localhost:6379"),
	})
	if err := testRedis.Ping(context.Background()).Err(); err != nil {
		fmt.Printf("Failed to connect to test Redis: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("✓ Connected to test Redis")

	// 初始化 JWT
	testJWTMgr = jwtPkg.NewManager(
		"test-access-secret",
		"test-refresh-secret",
		15*time.Minute,
		7*24*time.Hour,
	)

	// 初始化 Repository
	userRepo := repository.NewUserRepository(testDB)
	questionRepo := repository.NewQuestionRepository(testDB)
	reviewRepo := repository.NewReviewRecordRepository(testDB)
	reportRepo := repository.NewWeeklyReportRepository(testDB)

	// 初始化 Service
	authService := service.NewAuthService(userRepo, testRedis, testJWTMgr, cfg.OTP)
	questionService := service.NewQuestionService(questionRepo, userRepo)
	reviewService := service.NewReviewService(questionRepo, reviewRepo, userRepo)

	// 初始化 Handler
	testAuthHandler = handler.NewAuthHandler(authService)
	testQHandler = handler.NewQuestionHandler(questionService)
	testRHandler = handler.NewReviewHandler(reviewService)
	testRptHandler = handler.NewReportHandler(reportRepo, userRepo)
	testUserHandler = handler.NewUserHandler(userRepo)

	// 构建路由
	testRouter = buildTestRouter()

	fmt.Println("✓ Integration test infrastructure ready")
	fmt.Println("---")

	code := m.Run()

	// 清理
	testRedis.Close()
	os.Exit(code)
}

func loadTestConfig() *config.Config {
	return &config.Config{
		OTP: config.OTPConfig{
			Expire:          300,
			ResendInterval:  60,
			DailyLimit:      10,
			MaxRetry:        5,
			LockoutDuration: 1800,
		},
	}
}

func getEnvOrDefault(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func buildTestRouter() *gin.Engine {
	router := gin.New()

	v1 := router.Group("/v1")
	{
		// Auth（无需认证）
		auth := v1.Group("/auth")
		{
			auth.POST("/otp/send", testAuthHandler.SendOTP)
			auth.POST("/otp/verify", testAuthHandler.VerifyOTP)
			auth.POST("/refresh", testAuthHandler.RefreshToken)
		}

		// 需要认证
		authenticated := v1.Group("")
		authenticated.Use(middleware.Auth(testJWTMgr, testRedis))
		{
			authenticated.POST("/auth/logout", testAuthHandler.Logout)

			questions := authenticated.Group("/questions")
			{
				questions.GET("", testQHandler.List)
				questions.POST("", testQHandler.Create)
				questions.GET("/recycle-bin", testQHandler.ListRecycleBin)
				questions.DELETE("/recycle-bin/clear", testQHandler.ClearRecycleBin)
				questions.GET("/:id", testQHandler.GetByID)
				questions.PUT("/:id", testQHandler.Update)
				questions.DELETE("/:id", testQHandler.Delete)
				questions.POST("/:id/restore", testQHandler.Restore)
				questions.DELETE("/:id/permanent", testQHandler.PermanentDelete)
			}

			reviews := authenticated.Group("/reviews")
			{
				reviews.GET("/queue", testRHandler.GetQueue)
				reviews.POST("/result", testRHandler.SubmitResult)
				reviews.GET("", testRHandler.GetHistory)
			}

			reports := authenticated.Group("/reports")
			{
				reports.GET("", testRptHandler.GetDashboard)
			}

			users := authenticated.Group("/users")
			{
				users.GET("/me", testUserHandler.GetMe)
			}
		}
	}

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	return router
}

// ===== 测试辅助函数 =====

func doReq(method, path string, body interface{}, token string) *httptest.ResponseRecorder {
	var buf bytes.Buffer
	if body != nil {
		json.NewEncoder(&buf).Encode(body)
	}
	req, _ := http.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	testRouter.ServeHTTP(w, req)
	return w
}

func parseResp(t *testing.T, w *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var resp map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &resp)
	require.NoError(t, err, "响应应为有效JSON, got: %s", w.Body.String())
	return resp
}

// registerAndLogin 注册并登录一个测试用户，返回 access_token
func registerAndLogin(t *testing.T, phone string) string {
	t.Helper()

	// Step 1: 发送验证码
	w := doReq("POST", "/v1/auth/otp/send", map[string]interface{}{
		"phone": phone,
		"scene": "REGISTER",
	}, "")
	require.Equal(t, http.StatusOK, w.Code, "发送验证码失败: %s", w.Body.String())

	// Step 1.5: 从 Redis 读取验证码（测试环境专用）
	code := getOTPFromRedis(t, "REGISTER", phone)

	// Step 2: 验证验证码（自动注册+登录）
	w = doReq("POST", "/v1/auth/otp/verify", map[string]interface{}{
		"phone": phone,
		"code":  code,
		"scene": "REGISTER",
		"grade": "33",
	}, "")
	require.Equal(t, http.StatusOK, w.Code, "验证/注册失败: %s", w.Body.String())

	resp := parseResp(t, w)
	data, ok := resp["data"].(map[string]interface{})
	require.True(t, ok, "响应缺少 data 字段")
	token, ok := data["access_token"].(string)
	require.True(t, ok && token != "", "响应缺少 access_token")

	return token
}

// loginExisting 登录已存在的用户
func loginExisting(t *testing.T, phone string) string {
	t.Helper()

	// 发送验证码
	w := doReq("POST", "/v1/auth/otp/send", map[string]interface{}{
		"phone": phone,
		"scene": "LOGIN",
	}, "")
	require.Equal(t, http.StatusOK, w.Code, "发送验证码失败: %s", w.Body.String())

	// 从 Redis 读取验证码
	code := getOTPFromRedis(t, "LOGIN", phone)

	// 验证
	w = doReq("POST", "/v1/auth/otp/verify", map[string]interface{}{
		"phone": phone,
		"code":  code,
		"scene": "LOGIN",
	}, "")
	require.Equal(t, http.StatusOK, w.Code, "登录失败: %s", w.Body.String())

	resp := parseResp(t, w)
	data := resp["data"].(map[string]interface{})
	return data["access_token"].(string)
}

// getOTPFromRedis 从 Redis 读取验证码（仅测试环境使用）
func getOTPFromRedis(t *testing.T, scene, phone string) string {
	t.Helper()
	key := fmt.Sprintf("otp:code:%s:%s", scene, phone)
	code, err := testRedis.Get(context.Background(), key).Result()
	require.NoError(t, err, "从Redis读取OTP失败 (key=%s)", key)
	require.NotEmpty(t, code, "Redis中OTP为空 (key=%s)", key)
	return code
}

// createQuestion 创建一个错题，返回 question ID
func createQuestion(t *testing.T, token string, kpIDs []int) int64 {
	t.Helper()

	body := map[string]interface{}{
		"image_url":           "https://example.com/test-question.jpg",
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": kpIDs,
		"my_answer":           "我选A",
		"correct_answer":      "正确答案是B",
	}

	w := doReq("POST", "/v1/questions", body, token)
	require.Equal(t, http.StatusCreated, w.Code, "创建错题失败: %s", w.Body.String())

	resp := parseResp(t, w)
	data := resp["data"].(map[string]interface{})
	id := int64(data["id"].(float64))
	require.Greater(t, id, int64(0))
	return id
}

// ============================================================
// BUG-001 验证测试：GORM many2many 外键约束问题
// ============================================================

// TestBUG001_CreateWithValidKnowledgePoints 使用存在的知识点ID创建错题应成功
func TestBUG001_CreateWithValidKnowledgePoints(t *testing.T) {
	token := registerAndLogin(t, "13800001001")

	// init-db.sql 中预置了 ID 1-24 的知识点
	// 使用 ID 1（数与代数）和 ID 11（整数运算）
	w := doReq("POST", "/v1/questions", map[string]interface{}{
		"image_url":           "https://example.com/q1.jpg",
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": []int{1, 11},
	}, token)

	assert.Equal(t, http.StatusCreated, w.Code,
		"使用存在的知识点ID应返回201, got: %d, body: %s", w.Code, w.Body.String())

	if w.Code == http.StatusCreated {
		resp := parseResp(t, w)
		data := resp["data"].(map[string]interface{})
		assert.NotNil(t, data["id"])
	}
}

// TestBUG001_CreateWithNonExistentKnowledgePoints 使用不存在的知识点ID应返回400而非500
// 这是 BUG-001 的核心验证用例
func TestBUG001_CreateWithNonExistentKnowledgePoints(t *testing.T) {
	token := registerAndLogin(t, "13800001002")

	// 使用一个肯定不存在的知识点 ID（99999）
	w := doReq("POST", "/v1/questions", map[string]interface{}{
		"image_url":           "https://example.com/q-bug.jpg",
		"error_category":      "KNOWLEDGE",
		"knowledge_point_ids": []int{99999},
	}, token)

	// BUG-001: 当前实现会返回 500（GORM 外键约束违反）
	// 期望行为: 应返回 400 + 明确的错误信息
	if w.Code == http.StatusInternalServerError {
		t.Logf("🐛 BUG-001 确认: 使用不存在的知识点ID返回500而非400")
		t.Logf("   响应: %s", w.Body.String())
		t.Fail() // 标记为失败以记录 BUG
	} else if w.Code == http.StatusBadRequest {
		t.Logf("✅ BUG-001 已修复: 正确返回400")
		resp := parseResp(t, w)
		t.Logf("   错误信息: %v", resp["message"])
	} else {
		t.Logf("⚠️ 意外状态码: %d, body: %s", w.Code, w.Body.String())
	}
}

// TestBUG001_CreateWithMixedKnowledgePoints 混合存在和不存在的知识点ID
func TestBUG001_CreateWithMixedKnowledgePoints(t *testing.T) {
	token := registerAndLogin(t, "13800001003")

	// ID 1 存在，ID 99998 不存在
	w := doReq("POST", "/v1/questions", map[string]interface{}{
		"image_url":           "https://example.com/q-mixed.jpg",
		"error_category":      "SKILL",
		"knowledge_point_ids": []int{1, 99998},
	}, token)

	if w.Code == http.StatusInternalServerError {
		t.Logf("🐛 BUG-001 确认: 混合知识点ID时仍返回500")
		t.Logf("   响应: %s", w.Body.String())
		t.Fail()
	} else if w.Code == http.StatusBadRequest {
		t.Logf("✅ BUG-001 已修复: 混合知识点ID时正确返回400")
	} else if w.Code == http.StatusCreated {
		// 如果 GORM 没有外键约束检查（不太可能），也可能成功
		t.Logf("⚠️ 请求成功了 — 可能数据库中未建立外键约束")
	}
}

// ============================================================
// 完整认证流程集成测试
// ============================================================

// TestIntegration_FullAuthFlow 完整认证流程: 注册 → 登录 → 操作 → 登出 → Token失效
func TestIntegration_FullAuthFlow(t *testing.T) {
	phone := "13800002001"

	// Step 1: 注册
	token := registerAndLogin(t, phone)
	require.NotEmpty(t, token, "注册应返回有效token")
	t.Log("✓ Step 1: 注册成功")

	// Step 2: 用 token 获取用户信息
	w := doReq("GET", "/v1/users/me", nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "已登录用户应能获取个人信息")
	t.Log("✓ Step 2: 获取用户信息成功")

	// Step 3: 创建错题
	qID := createQuestion(t, token, []int{1, 2})
	assert.Greater(t, qID, int64(0), "应成功创建错题")
	t.Logf("✓ Step 3: 创建错题成功 (ID=%d)", qID)

	// Step 4: 获取错题详情
	w = doReq("GET", fmt.Sprintf("/v1/questions/%d", qID), nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "应能获取刚创建的错题")
	t.Log("✓ Step 4: 获取错题详情成功")

	// Step 5: 登出
	w = doReq("POST", "/v1/auth/logout", nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "登出应成功")
	t.Log("✓ Step 5: 登出成功")

	// Step 6: 验证旧 token 失效
	w = doReq("GET", "/v1/users/me", nil, token)
	assert.NotEqual(t, http.StatusOK, w.Code,
		"登出后旧token应失效, got status: %d", w.Code)
	t.Logf("✓ Step 6: 旧token已失效 (status=%d)", w.Code)

	// Step 7: 重新登录
	newToken := loginExisting(t, phone)
	require.NotEmpty(t, newToken, "重新登录应返回新token")
	assert.NotEqual(t, token, newToken, "新token应与旧token不同")
	t.Log("✓ Step 7: 重新登录成功")

	// Step 8: 用新 token 可以正常访问
	w = doReq("GET", "/v1/users/me", nil, newToken)
	assert.Equal(t, http.StatusOK, w.Code, "新token应能正常访问")
	t.Log("✓ Step 8: 新token正常工作")
}

// ============================================================
// Dashboard 集成测试
// ============================================================

// TestIntegration_DashboardAfterCreatingQuestions 创建错题后Dashboard应返回真实数据
func TestIntegration_DashboardAfterCreatingQuestions(t *testing.T) {
	phone := "13800003001"
	token := registerAndLogin(t, phone)

	// 创建几道错题
	createQuestion(t, token, []int{1})
	createQuestion(t, token, []int{2})
	createQuestion(t, token, []int{3})

	// 获取 Dashboard
	w := doReq("GET", "/v1/reports", nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "Dashboard应返回200, got: %s", w.Body.String())

	if w.Code == http.StatusOK {
		resp := parseResp(t, w)
		data := resp["data"]
		assert.NotNil(t, data, "Dashboard应返回data字段")
		t.Logf("Dashboard数据: %+v", data)
	}
}

// ============================================================
// 复习流程集成测试
// ============================================================

// TestIntegration_ReviewFlow 创建错题 → 获取复习队列 → 提交复习结果
func TestIntegration_ReviewFlow(t *testing.T) {
	phone := "13800004001"
	token := registerAndLogin(t, phone)

	// 创建一道错题
	qID := createQuestion(t, token, []int{1})

	// 获取复习队列
	w := doReq("GET", "/v1/reviews/queue", nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "获取复习队列应成功")
	t.Logf("复习队列响应: %s", w.Body.String())

	// 提交复习结果
	w = doReq("POST", "/v1/reviews/result", map[string]interface{}{
		"question_id": qID,
		"self_rating": "MASTERED",
	}, token)
	// 可能是200或400（如果该题不在今日复习计划中）
	t.Logf("提交复习结果: status=%d, body=%s", w.Code, w.Body.String())
}

// ============================================================
// 错题 CRUD 集成测试
// ============================================================

// TestIntegration_QuestionCRUD 完整的错题增删改查流程
func TestIntegration_QuestionCRUD(t *testing.T) {
	phone := "13800005001"
	token := registerAndLogin(t, phone)

	// Create
	qID := createQuestion(t, token, []int{1, 2})
	t.Logf("✓ Create: ID=%d", qID)

	// Read
	w := doReq("GET", fmt.Sprintf("/v1/questions/%d", qID), nil, token)
	assert.Equal(t, http.StatusOK, w.Code)
	resp := parseResp(t, w)
	data := resp["data"].(map[string]interface{})
	assert.Equal(t, "KNOWLEDGE", data["error_category"])
	t.Log("✓ Read: 错题详情正确")

	// Update
	w = doReq("PUT", fmt.Sprintf("/v1/questions/%d", qID), map[string]interface{}{
		"ocr_text":       "更新后的OCR文本",
		"correct_answer": "C",
	}, token)
	assert.Equal(t, http.StatusOK, w.Code, "更新应成功")
	t.Log("✓ Update: 更新成功")

	// List
	w = doReq("GET", "/v1/questions?page=1&page_size=10", nil, token)
	assert.Equal(t, http.StatusOK, w.Code)
	listResp := parseResp(t, w)
	listData := listResp["data"].(map[string]interface{})
	total := listData["pagination"].(map[string]interface{})["total"].(float64)
	assert.GreaterOrEqual(t, total, float64(1), "列表至少应有1条记录")
	t.Logf("✓ List: 共%d条记录", int(total))

	// Soft Delete
	w = doReq("DELETE", fmt.Sprintf("/v1/questions/%d", qID), nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "软删除应成功")
	t.Log("✓ Soft Delete: 成功")

	// Verify deleted question not in normal list
	w = doReq("GET", fmt.Sprintf("/v1/questions/%d", qID), nil, token)
	assert.NotEqual(t, http.StatusOK, w.Code, "已删除的错题不应能通过正常接口获取")
	t.Log("✓ Deleted question not accessible via normal API")

	// Recycle Bin
	w = doReq("GET", "/v1/questions/recycle-bin", nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "回收站应可访问")
	t.Log("✓ Recycle Bin: 可访问")

	// Restore
	w = doReq("POST", fmt.Sprintf("/v1/questions/%d/restore", qID), nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "恢复应成功")
	t.Log("✓ Restore: 成功")

	// Verify restored
	w = doReq("GET", fmt.Sprintf("/v1/questions/%d", qID), nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "恢复后应能正常获取")
	t.Log("✓ Restored question is accessible again")

	// Permanent Delete (先软删除再永久删除)
	doReq("DELETE", fmt.Sprintf("/v1/questions/%d", qID), nil, token)
	w = doReq("DELETE", fmt.Sprintf("/v1/questions/%d/permanent", qID), nil, token)
	assert.Equal(t, http.StatusOK, w.Code, "永久删除应成功")
	t.Log("✓ Permanent Delete: 成功")
}

// ============================================================
// 边界条件和异常测试
// ============================================================

// TestIntegration_UnauthorizedAccess 未认证访问受保护端点
func TestIntegration_UnauthorizedAccess(t *testing.T) {
	endpoints := []struct {
		method string
		path   string
	}{
		{"GET", "/v1/questions"},
		{"POST", "/v1/questions"},
		{"GET", "/v1/questions/1"},
		{"GET", "/v1/reviews/queue"},
		{"GET", "/v1/reports"},
		{"GET", "/v1/users/me"},
		{"POST", "/v1/auth/logout"},
	}

	for _, ep := range endpoints {
		w := doReq(ep.method, ep.path, nil, "")
		assert.Equal(t, http.StatusUnauthorized, w.Code,
			"%s %s 未认证应返回401, got: %d", ep.method, ep.path, w.Code)
	}
	t.Log("✓ 所有受保护端点均正确拒绝未认证请求")
}

// TestIntegration_InvalidToken 使用无效Token
func TestIntegration_InvalidToken(t *testing.T) {
	w := doReq("GET", "/v1/users/me", nil, "invalid-token-string")
	assert.NotEqual(t, http.StatusOK, w.Code, "无效token应被拒绝")
	t.Logf("✓ 无效Token被拒绝 (status=%d)", w.Code)
}

// TestIntegration_HealthCheck 健康检查端点
func TestIntegration_HealthCheck(t *testing.T) {
	w := doReq("GET", "/health", nil, "")
	assert.Equal(t, http.StatusOK, w.Code)
	resp := parseResp(t, w)
	assert.Equal(t, "ok", resp["status"])
	t.Log("✓ 健康检查通过")
}

// TestIntegration_CrossUserAccess 用户A不能访问用户B的错题
func TestIntegration_CrossUserAccess(t *testing.T) {
	// 注册用户A
	tokenA := registerAndLogin(t, "13800006001")
	// 注册用户B
	tokenB := registerAndLogin(t, "13800006002")

	// 用户A创建错题
	qID := createQuestion(t, tokenA, []int{1})

	// 用户B尝试获取用户A的错题
	w := doReq("GET", fmt.Sprintf("/v1/questions/%d", qID), nil, tokenB)
	assert.NotEqual(t, http.StatusOK, w.Code,
		"用户B不应能访问用户A的错题, got: %d", w.Code)
	t.Logf("✓ 跨用户访问被正确拒绝 (status=%d)", w.Code)
}
