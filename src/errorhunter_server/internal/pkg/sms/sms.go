package sms

import (
	"context"
	"fmt"
	"log"

	"github.com/aliyun/alibaba-cloud-sdk-go/sdk/requests"
	"github.com/aliyun/alibaba-cloud-sdk-go/services/dypnsapi"
)

// Provider 短信验证码提供者接口
type Provider interface {
	SendCode(ctx context.Context, phone string) error
	VerifyCode(ctx context.Context, phone, code string) (bool, error)
}

// ─── MockProvider 开发环境 ──────────────────────────────

type MockProvider struct{}

func (p *MockProvider) SendCode(ctx context.Context, phone string) error {
	log.Printf("[SMS-MOCK] 验证码已发送至 %s (开发环境固定验证码: 888888)", phone)
	return nil
}

func (p *MockProvider) VerifyCode(ctx context.Context, phone, code string) (bool, error) {
	if code == "888888" {
		log.Printf("[SMS-MOCK] 验证码校验通过 phone=%s", phone)
		return true, nil
	}
	log.Printf("[SMS-MOCK] 验证码校验失败 phone=%s code=%s", phone, code)
	return false, nil
}

// ─── AliyunProvider 阿里云号码认证服务 ──────────────────

type AliyunProvider struct {
	AccessKey     string
	SecretKey     string
	Endpoint      string
	SignName      string
	TemplateCode  string
	TemplateParam string
	CodeLength    int64
	CodeType      int64
	ValidTime     int64
	client        *dypnsapi.Client
}

func (p *AliyunProvider) initClient() error {
	if p.client != nil {
		return nil
	}
	client, err := dypnsapi.NewClientWithAccessKey("cn-hangzhou", p.AccessKey, p.SecretKey)
	if err != nil {
		return fmt.Errorf("创建阿里云号码认证客户端失败: %w", err)
	}
	p.client = client
	return nil
}

// SendCode 发送验证码
// 使用阿里云号码认证服务 SendSmsVerifyCode API
// 注意：API 会校验手机号是否为真实有效的中国大陆手机号
func (p *AliyunProvider) SendCode(ctx context.Context, phone string) error {
	if err := p.initClient(); err != nil {
		return err
	}

	request := dypnsapi.CreateSendSmsVerifyCodeRequest()
	request.Scheme = "https"
	request.PhoneNumber = phone
	request.SignName = p.SignName
	request.TemplateCode = p.TemplateCode

	if p.TemplateParam != "" {
		request.TemplateParam = p.TemplateParam
	}
	if p.CodeLength > 0 {
		request.CodeLength = requests.NewInteger64(p.CodeLength)
	}
	if p.CodeType > 0 {
		request.CodeType = requests.NewInteger64(p.CodeType)
	}
	if p.ValidTime > 0 {
		request.ValidTime = requests.NewInteger64(p.ValidTime)
	}

	resp, err := p.client.SendSmsVerifyCode(request)
	if err != nil {
		return fmt.Errorf("SendSmsVerifyCode 失败: %w", err)
	}

	if resp.Code != "OK" {
		log.Printf("[SMS] 发送失败: phone=%s code=%s msg=%s", phone, resp.Code, resp.Message)
		return fmt.Errorf("发送验证码失败: %s - %s", resp.Code, resp.Message)
	}

	log.Printf("[SMS] 验证码已发送至 %s", phone)
	return nil
}

// VerifyCode 校验验证码（阿里云端校验）
func (p *AliyunProvider) VerifyCode(ctx context.Context, phone, code string) (bool, error) {
	if err := p.initClient(); err != nil {
		return false, err
	}

	request := dypnsapi.CreateCheckSmsVerifyCodeRequest()
	request.Scheme = "https"
	request.PhoneNumber = phone
	request.VerifyCode = code

	resp, err := p.client.CheckSmsVerifyCode(request)
	if err != nil {
		return false, fmt.Errorf("CheckSmsVerifyCode 失败: %w", err)
	}

	if resp.Code == "OK" {
		log.Printf("[SMS] 验证码校验通过 phone=%s", phone)
		return true, nil
	}

	log.Printf("[SMS] 验证码校验失败 phone=%s code=%s", phone, resp.Code)
	return false, nil
}
