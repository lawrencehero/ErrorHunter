package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis"`
	MinIO    MinIOConfig    `mapstructure:"minio"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	OTP      OTPConfig      `mapstructure:"otp"`
	SMS      SMSConfig      `mapstructure:"sms"`
	OCR      OCRConfig      `mapstructure:"ocr"`
	Log      LogConfig      `mapstructure:"log"`
}

type ServerConfig struct {
	Port int    `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
}

type DatabaseConfig struct {
	Host            string `mapstructure:"host"`
	Port            int    `mapstructure:"port"`
	User            string `mapstructure:"user"`
	Password        string `mapstructure:"password"`
	DBName          string `mapstructure:"dbname"`
	SSLMode         string `mapstructure:"sslmode"`
	MaxOpenConns    int    `mapstructure:"max_open_conns"`
	MaxIdleConns    int    `mapstructure:"max_idle_conns"`
	ConnMaxLifetime int    `mapstructure:"conn_max_lifetime"`
}

func (c *DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode,
	)
}

type RedisConfig struct {
	Addr     string `mapstructure:"addr"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
	PoolSize int    `mapstructure:"pool_size"`
}

type MinIOConfig struct {
	Endpoint  string `mapstructure:"endpoint"`
	AccessKey string `mapstructure:"access_key"`
	SecretKey string `mapstructure:"secret_key"`
	Bucket    string `mapstructure:"bucket"`
	Region    string `mapstructure:"region"`
	UseSSL    bool   `mapstructure:"use_ssl"`
}

type JWTConfig struct {
	AccessSecret  string `mapstructure:"access_secret"`
	RefreshSecret string `mapstructure:"refresh_secret"`
	AccessExpire  int    `mapstructure:"access_expire"`  // minutes
	RefreshExpire int    `mapstructure:"refresh_expire"` // minutes
}

func (c *JWTConfig) AccessDuration() time.Duration {
	return time.Duration(c.AccessExpire) * time.Minute
}

func (c *JWTConfig) RefreshDuration() time.Duration {
	return time.Duration(c.RefreshExpire) * time.Minute
}

type OTPConfig struct {
	Expire          int `mapstructure:"expire"`           // seconds
	ResendInterval  int `mapstructure:"resend_interval"`  // seconds
	DailyLimit      int `mapstructure:"daily_limit"`
	MaxRetry        int `mapstructure:"max_retry"`
	LockoutDuration int `mapstructure:"lockout_duration"` // seconds
	// BypassPhones 验证码白名单：名单内手机号跳过真实短信发送与校验，
	// 任意验证码均可通过。用于测试/内部账号，生产环境应留空。
	BypassPhones []string `mapstructure:"bypass_phones"`
}

type OCRConfig struct {
	Provider string       `mapstructure:"provider"`
	Timeout  int          `mapstructure:"timeout"` // seconds
	Aliyun   AliyunOCR    `mapstructure:"aliyun"`
}

type AliyunOCR struct {
	AccessKey string `mapstructure:"access_key"`
	SecretKey string `mapstructure:"secret_key"`
	Endpoint  string `mapstructure:"endpoint"`
}

type SMSConfig struct {
	Provider     string     `mapstructure:"provider"`     // aliyun, mock
	Aliyun       AliyunSMS  `mapstructure:"aliyun"`
}

type AliyunSMS struct {
	AccessKey     string `mapstructure:"access_key"`
	SecretKey     string `mapstructure:"secret_key"`
	Endpoint      string `mapstructure:"endpoint"`
	SignName      string `mapstructure:"sign_name"`
	TemplateCode  string `mapstructure:"template_code"`
	TemplateParam string `mapstructure:"template_param"`
	CodeLength    int64  `mapstructure:"code_length"`
	CodeType      int64  `mapstructure:"code_type"`
	ValidTime     int64  `mapstructure:"valid_time"`
}

// HasCodeLength 判断是否显式配置了验证码长度
func (a AliyunSMS) HasCodeLength() bool { return a.CodeLength > 0 }

// HasCodeType 判断是否显式配置了验证码类型
func (a AliyunSMS) HasCodeType() bool { return a.CodeType > 0 }

// HasValidTime 判断是否显式配置了有效期
func (a AliyunSMS) HasValidTime() bool { return a.ValidTime > 0 }

type LogConfig struct {
	Level    string `mapstructure:"level"`
	Format   string `mapstructure:"format"`
	Output   string `mapstructure:"output"`
	FilePath string `mapstructure:"file_path"`
}

var globalConfig *Config

func Load(configPath string) (*Config, error) {
	v := viper.New()

	v.SetConfigFile(configPath)
	v.SetConfigType("yaml")

	// Environment variable support
	v.SetEnvPrefix("EH")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	if err := v.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("read config file: %w", err)
	}

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	globalConfig = &cfg
	return &cfg, nil
}

func Get() *Config {
	return globalConfig
}
