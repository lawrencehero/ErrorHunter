package ocr

import (
	"context"
	"time"
)

// Result OCR识别结果
type Result struct {
	Text           string  `json:"text"`
	Confidence     float64 `json:"confidence"`
	HasHandwriting bool    `json:"has_handwriting"`
	HasFormula     bool    `json:"has_formula"`
	Degraded       bool    `json:"degraded"`
	DegradeReason  string  `json:"degrade_reason,omitempty"`
}

// Provider OCR提供者接口
type Provider interface {
	Recognize(ctx context.Context, imageURL string) (*Result, error)
}

// Service OCR服务
type Service struct {
	provider Provider
	timeout  time.Duration
}

// NewService 创建OCR服务
func NewService(provider Provider, timeout time.Duration) *Service {
	return &Service{
		provider: provider,
		timeout:  timeout,
	}
}

// Recognize 识别图片文字（带超时降级）
func (s *Service) Recognize(ctx context.Context, imageURL string) (*Result, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	resultCh := make(chan *Result, 1)
	errCh := make(chan error, 1)

	go func() {
		r, e := s.provider.Recognize(timeoutCtx, imageURL)
		if e != nil {
			errCh <- e
			return
		}
		resultCh <- r
	}()

	select {
	case r := <-resultCh:
		return r, nil
	case e := <-errCh:
		return &Result{
			Degraded:      true,
			DegradeReason: "识别失败: " + e.Error(),
		}, nil
	case <-timeoutCtx.Done():
		return &Result{
			Degraded:      true,
			DegradeReason: "识别超时，请手动输入题目内容",
		}, nil
	}
}

// MockProvider 模拟OCR提供者（开发测试用）
type MockProvider struct{}

func (p *MockProvider) Recognize(ctx context.Context, imageURL string) (*Result, error) {
	// 模拟延迟
	time.Sleep(100 * time.Millisecond)

	return &Result{
		Text:           "这是一道示例数学题：\n计算 3/4 + 2/3 = ?",
		Confidence:     0.95,
		HasHandwriting: false,
		HasFormula:     true,
		Degraded:       false,
	}, nil
}

// AliyunProvider 阿里云OCR提供者（桩实现）
type AliyunProvider struct {
	AccessKey string
	SecretKey string
	Endpoint  string
}

func (p *AliyunProvider) Recognize(ctx context.Context, imageURL string) (*Result, error) {
	// TODO: 实际调用阿里云OCR API
	// 目前返回固定文本作为桩实现
	return &Result{
		Text:           "[阿里云OCR桩实现] 识别结果将在此显示",
		Confidence:     0.90,
		HasHandwriting: false,
		HasFormula:     false,
		Degraded:       false,
	}, nil
}
