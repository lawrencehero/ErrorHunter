package config

import (
	"fmt"

	"github.com/spf13/viper"
)

// 合法的年级代码
var validKpGrades = map[string]bool{
	"31": true, "32": true, "33": true, "34": true,
	"71": true, "72": true, "73": true,
}

// KnowledgePointEntry 知识点配置条目
type KnowledgePointEntry struct {
	Name          string `mapstructure:"name"`
	Grade         string `mapstructure:"grade"`
	Domain        string `mapstructure:"domain"`
	IsRecommended bool   `mapstructure:"is_recommended"`
	SortOrder     int    `mapstructure:"sort_order"`
}

// KnowledgePointConfig 知识点配置文件
type KnowledgePointConfig struct {
	Version string                 `mapstructure:"version"`
	Subject string                 `mapstructure:"subject"`
	Points  []KnowledgePointEntry  `mapstructure:"points"`
}

// LoadKnowledgePoints 读取知识点 YAML 配置
// path 为空时默认 configs/knowledge_points.yaml
func LoadKnowledgePoints(path string) (*KnowledgePointConfig, error) {
	if path == "" {
		path = "configs/knowledge_points.yaml"
	}

	v := viper.New()
	v.SetConfigFile(path)
	v.SetConfigType("yaml")
	if err := v.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("read knowledge points config: %w", err)
	}

	var cfg KnowledgePointConfig
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("unmarshal knowledge points config: %w", err)
	}

	if cfg.Version == "" {
		cfg.Version = "2026A"
	}
	if cfg.Subject == "" {
		cfg.Subject = "数学"
	}

	if err := validateKnowledgePoints(&cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func validateKnowledgePoints(cfg *KnowledgePointConfig) error {
	if len(cfg.Points) == 0 {
		return fmt.Errorf("knowledge points config: no points defined")
	}
	seen := make(map[string]bool, len(cfg.Points))
	for i, p := range cfg.Points {
		if p.Name == "" {
			return fmt.Errorf("knowledge points config: point #%d missing name", i+1)
		}
		if !validKpGrades[p.Grade] {
			return fmt.Errorf("knowledge points config: point %q has invalid grade %q", p.Name, p.Grade)
		}
		if p.Domain == "" {
			return fmt.Errorf("knowledge points config: point %q missing domain", p.Name)
		}
		key := p.Name + "|" + p.Grade
		if seen[key] {
			return fmt.Errorf("knowledge points config: duplicate (name=%q, grade=%q)", p.Name, p.Grade)
		}
		seen[key] = true
	}
	return nil
}
