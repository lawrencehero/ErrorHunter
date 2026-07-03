package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/handler"
	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/jwt"
	"github.com/errorhunter/errorhunter-server/internal/pkg/ocr"
	"github.com/errorhunter/errorhunter-server/internal/pkg/sms"
	"github.com/errorhunter/errorhunter-server/internal/repository"
	"github.com/errorhunter/errorhunter-server/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func main() {
	// 加载配置
	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "configs/config.yaml"
	}

	cfg, err := config.Load(configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 加载知识点配置
	kpConfigPath := os.Getenv("EH_KP_CONFIG_PATH")
	if kpConfigPath == "" {
		kpConfigPath = "configs/knowledge_points.yaml"
	}
	kpCfg, err := config.LoadKnowledgePoints(kpConfigPath)
	if err != nil {
		log.Fatalf("Failed to load knowledge points config: %v", err)
	}

	// 初始化数据库
	db, err := initDatabase(cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}
	log.Println("Database connected successfully")

	// 种子知识点（幂等，启动时把配置文件同步进 DB）
	kpSeeder := service.NewKnowledgePointSeeder(db, kpCfg)
	if _, err := kpSeeder.Seed(context.Background()); err != nil {
		log.Fatalf("Failed to seed knowledge points: %v", err)
	}

	// 初始化Redis
	redisClient, err := initRedis(cfg.Redis)
	if err != nil {
		log.Fatalf("Failed to connect Redis: %v", err)
	}
	log.Println("Redis connected successfully")

	// 初始化JWT管理器
	jwtMgr := jwt.NewManager(
		cfg.JWT.AccessSecret,
		cfg.JWT.RefreshSecret,
		cfg.JWT.AccessDuration(),
		cfg.JWT.RefreshDuration(),
	)

	// 初始化OCR服务
	var ocrProvider ocr.Provider
	if cfg.OCR.Provider == "mock" {
		ocrProvider = &ocr.MockProvider{}
	} else {
		ocrProvider = &ocr.AliyunProvider{
			AccessKey: cfg.OCR.Aliyun.AccessKey,
			SecretKey: cfg.OCR.Aliyun.SecretKey,
			Endpoint:  cfg.OCR.Aliyun.Endpoint,
		}
	}
	ocrService := ocr.NewService(ocrProvider, time.Duration(cfg.OCR.Timeout)*time.Second)

	// 初始化Repository
	userRepo := repository.NewUserRepository(db)
	questionRepo := repository.NewQuestionRepository(db)
	reviewRepo := repository.NewReviewRecordRepository(db)
	reportRepo := repository.NewWeeklyReportRepository(db)
	kpRepo := repository.NewKnowledgePointRepository(db)

	// 初始化SMS服务
	var smsProvider sms.Provider
	if cfg.SMS.Provider == "aliyun" {
		smsProvider = &sms.AliyunProvider{
			AccessKey:     cfg.SMS.Aliyun.AccessKey,
			SecretKey:     cfg.SMS.Aliyun.SecretKey,
			Endpoint:      cfg.SMS.Aliyun.Endpoint,
			SignName:      cfg.SMS.Aliyun.SignName,
			TemplateCode:  cfg.SMS.Aliyun.TemplateCode,
			TemplateParam: cfg.SMS.Aliyun.TemplateParam,
			CodeLength:    cfg.SMS.Aliyun.CodeLength,
			CodeType:      cfg.SMS.Aliyun.CodeType,
			ValidTime:     cfg.SMS.Aliyun.ValidTime,
		}
	} else {
		smsProvider = &sms.MockProvider{}
	}

	// 初始化Service
	authService := service.NewAuthService(userRepo, redisClient, jwtMgr, cfg.OTP, smsProvider)
	questionService := service.NewQuestionService(questionRepo, userRepo, db)
	reviewService := service.NewReviewService(questionRepo, reviewRepo, userRepo)
	weeklyReportService := service.NewWeeklyReportService(reportRepo, questionRepo, reviewRepo, userRepo, db)

	// 初始化Handler
	authHandler := handler.NewAuthHandler(authService)
	questionHandler := handler.NewQuestionHandler(questionService)
	reviewHandler := handler.NewReviewHandler(reviewService, userRepo)
	reportHandler := handler.NewReportHandler(reportRepo, userRepo)
	userHandler := handler.NewUserHandler(userRepo, authService)
	syncHandler := handler.NewSyncHandler()
	kpHandler := handler.NewKnowledgePointHandler(kpRepo)

	uploadHandler, err := handler.NewUploadHandler(cfg.MinIO, ocrService)
	if err != nil {
		log.Printf("Warning: Failed to init upload handler: %v", err)
	}
	// 注入对象存储删除能力：永久删除错题/清空回收站时同步清理 MinIO 图片
	if uploadHandler != nil {
		questionService.SetImageDeleter(uploadHandler)
	}
	// 注入复习记录仓库：错题详情接口返回最近复习记录（详情页"复习历史"）
	questionService.SetReviewRepo(reviewRepo)

	// 设置Gin模式
	gin.SetMode(cfg.Server.Mode)

	// 创建路由
	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())
	router.Use(middleware.CORS())

	// 限流器
	rateLimiter := middleware.NewRateLimiter(100, time.Minute)
	rateLimiter.Cleanup(5 * time.Minute)
	router.Use(rateLimiter.RateLimit())

	// API版本组
	v1 := router.Group("/v1")
	{
		// 图片代理（无需认证，objectKey 含 UUID 不可猜测）
		if uploadHandler != nil {
			v1.GET("/files/*key", uploadHandler.ServeFile)
		}

		// Auth 模块（无需认证）
		auth := v1.Group("/auth")
		{
			auth.POST("/otp/send", authHandler.SendOTP)
			auth.POST("/otp/verify", authHandler.VerifyOTP)
			auth.POST("/register", authHandler.Register)
			auth.POST("/refresh", authHandler.RefreshToken)
		}

		// 需要认证的端点
		authenticated := v1.Group("")
		authenticated.Use(middleware.Auth(jwtMgr, redisClient))
		{
			// Auth
			authenticated.POST("/auth/logout", authHandler.Logout)

			// Questions
			questions := authenticated.Group("/questions")
			{
				questions.GET("", questionHandler.List)
				questions.POST("", questionHandler.Create)
				questions.GET("/recycle-bin", questionHandler.ListRecycleBin)
				questions.DELETE("/recycle-bin/clear", questionHandler.ClearRecycleBin)
				questions.GET("/:id", questionHandler.GetByID)
				questions.PUT("/:id", questionHandler.Update)
				questions.DELETE("/:id", questionHandler.Delete)
				questions.POST("/:id/restore", questionHandler.Restore)
				questions.DELETE("/:id/permanent", questionHandler.PermanentDelete)
			}

			// Knowledge Points
			knowledgePoints := authenticated.Group("/knowledge-points")
			{
				knowledgePoints.GET("", kpHandler.List)
			}

			// Reviews
			reviews := authenticated.Group("/reviews")
			{
				reviews.GET("/queue", reviewHandler.GetQueue)
				reviews.POST("/result", reviewHandler.SubmitResult)
				reviews.GET("", reviewHandler.GetHistory)
			}

			// Reports
			reports := authenticated.Group("/reports")
			{
				reports.GET("", reportHandler.GetDashboard)
				reports.GET("/weekly", reportHandler.GetWeeklyReports)
				reports.GET("/weekly/:id", reportHandler.GetWeeklyReportDetail)
			}

			// Upload
			if uploadHandler != nil {
				authenticated.POST("/upload", uploadHandler.Upload)
				authenticated.POST("/upload/ocr", uploadHandler.OCR)
				authenticated.GET("/upload/signed-url", uploadHandler.GetSignedURL)
				// 存储用量：统计当前用户在 MinIO 的错题图片总量
				authenticated.GET("/storage", uploadHandler.GetStorageUsage)
			}

			// User
			users := authenticated.Group("/users")
			{
				users.GET("/me", userHandler.GetMe)
				users.GET("/me/settings", userHandler.GetSettings)
				users.PUT("/me/settings", userHandler.UpdateSettings)
				users.POST("/me/deactivate", userHandler.Deactivate)
			}

			// Sync (V1.1 桩实现)
			sync := authenticated.Group("/sync")
			{
				sync.POST("/push", syncHandler.Push)
				sync.GET("/pull", syncHandler.Pull)
			}
		}
	}

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// 启动服务器
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	server := &http.Server{
		Addr:    addr,
		Handler: router,
	}

	// 后台周报生成任务 ctx：随 server 优雅关闭一并退出
	bgCtx, bgCancel := context.WithCancel(context.Background())
	defer bgCancel()

	go func() {
		log.Printf("Server starting on %s", addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// 启动周报定时生成后台 goroutine：
	//   - 启动时先跑一次：为所有活跃用户补生成"上一完整周"的周报（服务重启可补生成）
	//   - 之后每 24h 触发一次：再次尝试生成上一完整周（已存在则跳过，幂等）
	// 触发时机不精确到每天 00:05（避免引入定时计算复杂度）；24h ticker + 启动即跑
	// 已能满足"周报不漏生成"的核心诉求。
	startWeeklyReportScheduler(bgCtx, weeklyReportService)

	// 优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	// 通知后台 goroutine 退出
	bgCancel()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited properly")
}

// startWeeklyReportScheduler 启动周报生成后台循环。
//
// 行为：
//   1. 启动时立即跑一次：为所有活跃用户生成"上一完整周"周报（补生成，幂等）。
//   2. 之后每 24 小时 tick 一次，重复生成"上一完整周"（已存在则跳过）。
//
// "上一完整周"判定（见 service.LastCompletedWeekStart）：以当前上海时刻所在周的
// 上一周的周一为 weekStart，保证只生成 weekEnd <= now 的已结束周，不生成当前未结束周。
//
// 通过 ctx 控制退出：ctx.Done() 时 goroutine 返回，配合 server 优雅关闭。
func startWeeklyReportScheduler(ctx context.Context, svc *service.WeeklyReportService) {
	const tickInterval = 24 * time.Hour

	runOnce := func() {
		weekStart := service.LastCompletedWeekStart(time.Now())
		generated, err := svc.GenerateForAllActiveUsers(ctx, weekStart)
		if err != nil {
			log.Printf("weekly_report: 定时生成遇到错误（仍可能已生成部分）generated=%d week=%v: %v",
				generated, weekStart, err)
		} else {
			log.Printf("weekly_report: 定时生成完成 generated=%d week=%v", generated, weekStart)
		}
	}

	go func() {
		// 启动即跑一次（补生成上周）
		runOnce()

		ticker := time.NewTicker(tickInterval)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				log.Println("weekly_report: scheduler stopped")
				return
			case <-ticker.C:
				runOnce()
			}
		}
	}()
}

func initDatabase(cfg config.DatabaseConfig) (*gorm.DB, error) {
	dsn := cfg.DSN()
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	sqlDB, _ := db.DB()
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.ConnMaxLifetime) * time.Second)

	return db, nil
}

func initRedis(cfg config.RedisConfig) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr,
		Password: cfg.Password,
		DB:       cfg.DB,
		PoolSize: cfg.PoolSize,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return client, nil
}
