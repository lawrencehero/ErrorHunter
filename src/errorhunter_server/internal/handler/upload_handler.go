package handler

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"sort"
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

	// 生成访问URL：通过后端代理 /v1/files/<key> 提供，使用请求 Host（客户端可达）
	imageURL := fmt.Sprintf("http://%s/v1/files/%s", c.Request.Host, objectKey)

	respondSuccess(c, gin.H{
		"image_url": imageURL,
	})
}

// ServeFile 通过后端代理提供图片访问（从 MinIO 流式转发）。
// 路径 /v1/files/<objectKey>，objectKey 含 UUID 不可猜测，故免鉴权以便 Image.network 直接加载。
func (h *UploadHandler) ServeFile(c *gin.Context) {
	// c.Param("key") 带前导 "/"
	objectKey := strings.TrimPrefix(c.Param("key"), "/")
	if objectKey == "" {
		c.Status(http.StatusBadRequest)
		return
	}

	getObj, err := h.s3Client.GetObject(c.Request.Context(), &s3.GetObjectInput{
		Bucket: aws.String(h.bucket),
		Key:    aws.String(objectKey),
	})
	if err != nil {
		c.Status(http.StatusNotFound)
		return
	}
	defer getObj.Body.Close()

	// 透传 Content-Type / Content-Length
	if getObj.ContentType != nil {
		c.Header("Content-Type", *getObj.ContentType)
	}
	if getObj.ContentLength != nil {
		c.Header("Content-Length", fmt.Sprintf("%d", *getObj.ContentLength))
	}
	c.Status(http.StatusOK)
	io.Copy(c.Writer, getObj.Body)
}

// OCRRequest OCR请求
type OCRRequest struct {
	ImageURL string `json:"image_url" binding:"required"`
}

// OCRResponse OCR响应
type OCRResponse struct {
	Text           string             `json:"text"`
	Confidence     float64            `json:"confidence"`
	HasHandwriting bool               `json:"has_handwriting"`
	HasFormula     bool               `json:"has_formula"`
	Figures        []ocr.FigureRegion `json:"figures"`
	Degraded       bool               `json:"degraded"`
	DegradeReason  string             `json:"degrade_reason,omitempty"`
}

// OCR OCR识别
// POST /upload/ocr
func (h *UploadHandler) OCR(c *gin.Context) {
	var req OCRRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, errcode.EParamValidation)
		return
	}

	// 从图片 URL 中提取 object key，直接从 MinIO 下载传给 OCR（避免内网 URL 外网不可达）
	imageURL := req.ImageURL
	var imageBody io.Reader

	// 提取 object key：支持 /v1/files/<key> 代理 URL 和 http://endpoint/bucket/<key> 直连 URL
	objectKey := ""
	if idx := strings.Index(imageURL, "/v1/files/"); idx >= 0 {
		objectKey = imageURL[idx+len("/v1/files/"):]
	} else {
		parts := strings.SplitN(imageURL, "/", 5)
		if len(parts) >= 5 {
			objectKey = parts[4]
		}
	}
	if objectKey != "" {
		// 从 MinIO 下载图片
		getObj, err := h.s3Client.GetObject(c.Request.Context(), &s3.GetObjectInput{
			Bucket: aws.String(h.bucket),
			Key:    aws.String(objectKey),
		})
		if err == nil && getObj.Body != nil {
			// 读入内存：OCR 失败重试时需重置 Reader，且避免流式读取中途断开
			data, readErr := io.ReadAll(getObj.Body)
			getObj.Body.Close()
			if readErr == nil && len(data) > 0 {
				imageBody = bytes.NewReader(data)
				log.Printf("[OCR] 从 MinIO 下载图片: %s (%d bytes)", objectKey, len(data))
			} else {
				log.Printf("[WARN] MinIO 读取失败，回退使用 URL: %v", readErr)
			}
		} else {
			log.Printf("[WARN] MinIO 下载失败，回退使用 URL: %v", err)
		}
	}

	result, err := h.ocrService.Recognize(c.Request.Context(), imageURL, imageBody)
	if err != nil {
		respondError(c, errcode.EInternalServer)
		return
	}

	respondSuccess(c, OCRResponse{
		Text:           result.Text,
		Confidence:     result.Confidence,
		HasHandwriting: result.HasHandwriting,
		HasFormula:     result.HasFormula,
		Figures:        result.Figures,
		Degraded:       result.Degraded,
		DegradeReason:  result.DegradeReason,
	})
}

// DeleteObject 删除 MinIO 中的指定对象（用于错题永久删除时清理图片）。
// 实现 service.ImageObjectDeleter 接口。
func (h *UploadHandler) DeleteObject(ctx context.Context, key string) error {
	_, err := h.s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(h.bucket),
		Key:    aws.String(key),
	})
	return err
}

// cloudImageItem 云端错题图片元信息（存储管理页列表项）。
type cloudImageItem struct {
	URL          string `json:"url"`
	Size         int64  `json:"size"`
	LastModified string `json:"last_modified"`
	Key          string `json:"key"`
}

// cloudImageListMax 单次返回的图片对象上限，避免列表过大拖累请求。
const cloudImageListMax = 200

// GetStorageUsage 统计当前用户在 MinIO 中的错题图片总用量，并返回图片对象列表。
// GET /v1/storage
// 遍历该用户名册下的所有对象（前缀 questions/<userID>/），累加体积与数量，
// 同时收集每张图片的可访问 URL（/v1/files/<key>，由 ServeFile 代理转发，供客户端 Image.network 直接加载）。
// 注：前缀以 "questions/<userID>/" 结尾，不会误匹配 questions/170/ 等其它用户。
// 图片对象按 last_modified 倒序，最多返回 cloudImageListMax 张；超出则在 has_more/total 中体现。
func (h *UploadHandler) GetStorageUsage(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == 0 {
		respondError(c, errcode.EUnauthorized)
		return
	}

	prefix := fmt.Sprintf("questions/%d/", userID)
	var totalBytes int64
	var imageCount int64
	images := make([]cloudImageItem, 0, cloudImageListMax)

	paginator := s3.NewListObjectsV2Paginator(h.s3Client, &s3.ListObjectsV2Input{
		Bucket: aws.String(h.bucket),
		Prefix: aws.String(prefix),
	})

	// 访问 URL 前缀：用请求 Host 构造，客户端可直接访问（与 Upload 一致）。
	// 不带 https：保持与既有图片 URL 形式一致，由客户端按需升级或经反代统一。
	urlPrefix := fmt.Sprintf("http://%s/v1/files/", c.Request.Host)

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(c.Request.Context())
		if err != nil {
			respondError(c, errcode.EOssUnavailable)
			return
		}
		for _, obj := range page.Contents {
			if obj.Size == nil || *obj.Size <= 0 {
				continue
			}
			size := *obj.Size
			totalBytes += size
			imageCount++

			// 已收集满上限后不再追加（但 totalBytes/imageCount 仍统计全量）。
			if len(images) >= cloudImageListMax {
				continue
			}

			lastModified := ""
			if obj.LastModified != nil {
				lastModified = obj.LastModified.UTC().Format(time.RFC3339)
			}
			key := aws.ToString(obj.Key)
			images = append(images, cloudImageItem{
				URL:          urlPrefix + key,
				Size:         size,
				LastModified: lastModified,
				Key:          key,
			})
		}
	}

	// 按 last_modified 倒序（最近在前）
	sort.Slice(images, func(i, j int) bool {
		return images[i].LastModified > images[j].LastModified
	})

	respondSuccess(c, gin.H{
		"used_bytes":  totalBytes,
		"image_count": imageCount,
		"images":      images,
		"total":       imageCount,
		"has_more":    imageCount > int64(len(images)),
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
