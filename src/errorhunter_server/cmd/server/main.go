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

	// 初始化数据库
	db, err := initDatabase(cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}
	log.Println("Database connected successfully")

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

	// 初始化Service
	authService := service.NewAuthService(userRepo, redisClient, jwtMgr, cfg.OTP)
	questionService := service.NewQuestionService(questionRepo, userRepo)
	reviewService := service.NewReviewService(questionRepo, reviewRepo, userRepo)

	// 初始化Handler
	authHandler := handler.NewAuthHandler(authService)
	questionHandler := handler.NewQuestionHandler(questionService)
	reviewHandler := handler.NewReviewHandler(reviewService)
	reportHandler := handler.NewReportHandler(reportRepo, userRepo)
	userHandler := handler.NewUserHandler(userRepo)
	syncHandler := handler.NewSyncHandler()

	uploadHandler, err := handler.NewUploadHandler(cfg.MinIO, ocrService)
	if err != nil {
		log.Printf("Warning: Failed to init upload handler: %v", err)
	}

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
		// Auth 模块（无需认证）
		auth := v1.Group("/auth")
		{
			auth.POST("/otp/send", authHandler.SendOTP)
			auth.POST("/otp/verify", authHandler.VerifyOTP)
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
			}

			// User
			users := authenticated.Group("/users")
			{
				users.GET("/me", userHandler.GetMe)
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

	go func() {
		log.Printf("Server starting on %s", addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// 优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited properly")
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
