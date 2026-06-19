package handler

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsConfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/errorhunter/errorhunter-server/internal/config"
	"github.com/errorhunter/errorhunter-server/internal/middleware"
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/errorhunter/errorhunter-server/internal/pkg/ocr"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// UploadHandler 上传处理器
type UploadHandler struct {
	s3Client   *s3.Client
	bucket     string
	ocrService *ocr.Service
	cfg        config.MinIOConfig
}

func NewUploadHandler(cfg config.MinIOConfig, ocrService *ocr.Service) (*UploadHandler, error) {
	// 配置 S3 客户端（兼容 MinIO）
	resolver := aws.EndpointResolverWithOptionsFunc(
		func(service, region string, options ...interface{}) (aws.Endpoint, error) {
			return aws.Endpoint{
				URL:               fmt.Sprintf("http://%s", cfg.Endpoint),
				SigningRegion:      cfg.Region,
				HostnameImmutable: true,
			}, nil
		},
	)

	awsCfg, err := awsConfig.LoadDefaultConfig(context.Background(),
		awsConfig.WithEndpointResolverWithOptions(resolver),
		awsConfig.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(cfg.AccessKey, cfg.SecretKey, ""),
		),
		awsConfig.WithRegion(cfg.Region),
	)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}

	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		o.UsePathStyle = true
	})

	return &UploadHandler{
		s3Client:   client,
		bucket:     cfg.Bucket,
		ocrService: ocrService,
		cfg:        cfg,
	}, nil
}

// Upload 上传图片
// POST /upload
func (h *UploadHandler) Upload(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	file, header, err := c.Request.FormFile("image")
	if err != nil {
		respondError(c, errcode.EParamValidation.WithData("invalid image file"))
		return
	}
	defer file.Close()

	// 检查文件大小 (20MB)
	if header.Size > 20*1024*1024 {
		respondError(c, errcode.EImageTooLarge)
		return
	}

	// 检查文件类型
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".heic" {
		respondError(c, errcode.EImageFormatUnsupported)
		return
	}

	// 生成唯一文件名
	objectKey := fmt.Sprintf("questions/%d/%s%s", userID, uuid.New().String(), ext)

	// 上传到 MinIO
	_, err = h.s3Client.PutObject(c.Request.Context(), &s3.PutObjectInput{
		Bucket:      aws.String(h.bucket),
		Key:         aws.String(objectKey),
		Body:        file,
		ContentType: aws.String(header.Header.Get("Content-Type")),
	})
	if err != nil {
		respondError(c, errcode.EOssUnavailable)
		return
	}

	// 生成访问URL
	imageURL := fmt.Sprintf("http://%s/%s/%s", h.cfg.Endpoint, h.bucket, objectKey)

	respondSuccess(c, gin.H{
		"image_url": imageURL,
	})
}

// OCRRequest OCR请求
type OCRRequest struct {
	ImageURL string `json:"image_url" binding:"required"`
}

// OCRResponse OCR响应
type OCRResponse struct {
	Text           string  `json:"text"`
	Confidence     float64 `json:"confidence"`
	HasHandwriting bool    `json:"has_handwriting"`
	HasFormula     bool    `json:"has_formula"`
	Degraded       bool    `json:"degraded"`
	DegradeReason  string  `json:"degrade_reason,omitempty"`
}

// OCR OCR识别
// POST /upload/ocr
func (h *UploadHandler) OCR(c *gin.Context) {
	var req OCRRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	result, err := h.ocrService.Recognize(c.Request.Context(), req.ImageURL)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, OCRResponse{
		Text:           result.Text,
		Confidence:     result.Confidence,
		HasHandwriting: result.HasHandwriting,
		HasFormula:     result.HasFormula,
		Degraded:       result.Degraded,
		DegradeReason:  result.DegradeReason,
	})
}

// GetSignedURL 获取签名URL
// GET /upload/signed-url
func (h *UploadHandler) GetSignedURL(c *gin.Context) {
	fileURL := c.Query("file_url")
	if fileURL == "" {
		respondError(c, errcode.EParamValidation)
		return
	}

	expires := 1800 // 默认30分钟
	if exp := c.Query("expires"); exp != "" {
		fmt.Sscanf(exp, "%d", &expires)
		if expires < 60 || expires > 3600 {
			expires = 1800
		}
	}

	// 从URL中提取object key
	// 简化处理：假设URL格式为 http://endpoint/bucket/key
	parts := strings.SplitN(fileURL, "/", 5)
	if len(parts) < 5 {
		respondError(c, errcode.EParamValidation)
		return
	}
	objectKey := parts[4]

	// 生成预签名URL
	presignClient := s3.NewPresignClient(h.s3Client)
	result, err := presignClient.PresignGetObject(c.Request.Context(), &s3.GetObjectInput{
		Bucket: aws.String(h.bucket),
		Key:    aws.String(objectKey),
	}, s3.WithPresignExpires(time.Duration(expires)*time.Second))
	if err != nil {
		respondError(c, errcode.EOssUnavailable)
		return
	}

	respondSuccess(c, gin.H{
		"signed_url": result.URL,
		"expires_in": expires,
	})
}
