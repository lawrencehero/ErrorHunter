package ocr

import (
	"context"
	"testing"
	"time"
)

func TestMockProvider_Recognize(t *testing.T) {
	p := &MockProvider{}
	result, err := p.Recognize(context.Background(), "https://example.com/test.jpg", nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Text == "" {
		t.Fatal("expected non-empty text")
	}
	if result.Degraded {
		t.Fatal("mock should not be degraded")
	}
}

func TestService_Recognize_WithMock(t *testing.T) {
	p := &MockProvider{}
	svc := NewService(p, 5*time.Second)

	result, err := svc.Recognize(context.Background(), "https://example.com/test.jpg", nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Degraded {
		t.Fatalf("should not be degraded, reason: %s", result.DegradeReason)
	}
}

func TestAliyunProvider_InitClient(t *testing.T) {
	p := &AliyunProvider{
		AccessKey: "test-key",
		SecretKey: "test-secret",
		Endpoint:  "ocr-api.cn-hangzhou.aliyuncs.com",
	}

	if err := p.initClient(); err != nil {
		t.Fatalf("initClient failed: %v", err)
	}
	if p.client == nil {
		t.Fatal("client should not be nil after init")
	}
}
