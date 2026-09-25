package sms

import (
	"context"
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
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

// ─── AliyunProvider 阿里云号码认证服务（原生 HTTP 签名） ──
//
// 直接使用 HTTP 调用 dypnsapi API，绕开 alibaba-cloud-sdk-go SDK。
// 生产环境 SDK 调用 SendSmsVerifyCode 返回 UNKNOWN 错误，但同等参数的
// 原生 HTTP 请求能正常发送短信，故改用 HTTP 签名方式。
//
// 验证码由阿里云自动生成、托管和校验，本服务无需存储验证码。

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
}

// aliyunResponse 阿里云 API 通用响应结构
type aliyunResponse struct {
	Code    string `json:"Code"`
	Message string `json:"Message"`
}

// callAPI 发起阿里云 API 请求（V1 签名）
func (p *AliyunProvider) callAPI(action string, extraParams map[string]string) (*aliyunResponse, error) {
	endpoint := p.Endpoint
	if endpoint == "" {
		endpoint = "dypnsapi.aliyuncs.com"
	}

	// 构造公共参数
	params := map[string]string{
		"Format":           "JSON",
		"Version":          "2017-05-25",
		"AccessKeyId":      p.AccessKey,
		"SignatureMethod":   "HMAC-SHA1",
		"SignatureVersion":  "1.0",
		"SignatureNonce":    uuid.New().String(),
		"Timestamp":         time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		"Action":            action,
	}
	for k, v := range extraParams {
		params[k] = v
	}

	// 按 key 排序，构造 canonicalized query string
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var pairs []string
	for _, k := range keys {
		pairs = append(pairs, url.QueryEscape(k)+"="+url.QueryEscape(params[k]))
	}
	canonicalized := strings.Join(pairs, "&")

	// 构造待签名串：GET&%2F&<encoded canonicalized>
	stringToSign := "GET&" + url.QueryEscape("/") + "&" + url.QueryEscape(canonicalized)

	// HMAC-SHA1 签名
	mac := hmac.New(sha1.New, []byte(p.SecretKey+"&"))
	mac.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	// 拼接最终 URL
	requestURL := fmt.Sprintf("https://%s/?%s&Signature=%s",
		endpoint, canonicalized, url.QueryEscape(signature))

	req, err := http.NewRequest("GET", requestURL, nil)
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求阿里云 API 失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %w", err)
	}

	var result aliyunResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %w (body=%s)", err, string(body))
	}

	return &result, nil
}

// SendCode 通过 dypnsapi.SendSmsVerifyCode 发送验证码
// 验证码由阿里云自动生成并通过短信下发，同时托管在阿里云侧供后续校验。
func (p *AliyunProvider) SendCode(ctx context.Context, phone string) error {
	extraParams := map[string]string{
		"PhoneNumber": phone,
		"SignName":    p.SignName,
		"TemplateCode": p.TemplateCode,
	}
	if p.TemplateParam != "" {
		extraParams["TemplateParam"] = p.TemplateParam
	}
	if p.CodeLength > 0 {
		extraParams["CodeLength"] = fmt.Sprintf("%d", p.CodeLength)
	}
	if p.CodeType > 0 {
		extraParams["CodeType"] = fmt.Sprintf("%d", p.CodeType)
	}
	if p.ValidTime > 0 {
		extraParams["ValidTime"] = fmt.Sprintf("%d", p.ValidTime)
	}

	result, err := p.callAPI("SendSmsVerifyCode", extraParams)
	if err != nil {
		return err
	}

	if result.Code != "OK" {
		log.Printf("[SMS] 发送失败: phone=%s code=%s msg=%s", phone, result.Code, result.Message)
		return fmt.Errorf("发送验证码失败: %s - %s", result.Code, result.Message)
	}

	log.Printf("[SMS] 验证码已发送至 %s", phone)
	return nil
}

// VerifyCode 通过 dypnsapi.CheckSmsVerifyCode 校验验证码
// 验证码由阿里云端校验（SendCode 时阿里云自动存储）。
func (p *AliyunProvider) VerifyCode(ctx context.Context, phone, code string) (bool, error) {
	extraParams := map[string]string{
		"PhoneNumber": phone,
		"VerifyCode":  code,
	}

	result, err := p.callAPI("CheckSmsVerifyCode", extraParams)
	if err != nil {
		return false, err
	}

	if result.Code == "OK" {
		log.Printf("[SMS] 验证码校验通过 phone=%s", phone)
		return true, nil
	}

	log.Printf("[SMS] 验证码校验失败 phone=%s code=%s msg=%s", phone, result.Code, result.Message)
	return false, nil
}
