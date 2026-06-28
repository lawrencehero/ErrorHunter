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

func TestAliyunProvider_InitClient(t *testing.T) {
	p := &AliyunProvider{
		AccessKey:    "test-key",
		SecretKey:    "test-secret",
		Endpoint:     "dypnsapi.aliyuncs.com",
		SignName:     "测试签名",
		TemplateCode: "100001",
	}

	if err := p.initClient(); err != nil {
		t.Fatalf("initClient failed: %v", err)
	}
	if p.client == nil {
		t.Fatal("client should not be nil after init")
	}

	// Second call reuses existing client
	if err := p.initClient(); err != nil {
		t.Fatalf("second initClient failed: %v", err)
	}
}
