package sms

import (
	"context"
	"testing"
)

func TestMockProvider_SendCode(t *testing.T) {
	p := &MockProvider{}
	err := p.SendCode(context.Background(), "13800138000")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestMockProvider_VerifyCode_Valid(t *testing.T) {
	p := &MockProvider{}
	valid, err := p.VerifyCode(context.Background(), "13800138000", "888888")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !valid {
		t.Fatal("expected valid for code 888888")
	}
}

func TestMockProvider_VerifyCode_Invalid(t *testing.T) {
	p := &MockProvider{}
	valid, err := p.VerifyCode(context.Background(), "13800138000", "123456")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if valid {
		t.Fatal("expected invalid for code 123456")
	}
}

// 注：AliyunProvider 改为原生 HTTP 签名（callAPI 内联构造请求，使用 http.DefaultClient），
// 不再有 initClient/client 字段，故原 InitClient 测试已移除。SendCode/VerifyCode 依赖真实
// 阿里云 API，在 mock 配置下不便于单元测试，由集成测试覆盖。

