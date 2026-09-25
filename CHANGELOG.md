# Changelog

本项目的所有显著变更记录见此文件。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- 开源前整改：新增 `LICENSE`（Apache 2.0）、`NOTICE`、`README.md`、`CONTRIBUTING.md`、`CODE_OF_CONDUCT.md`、`SECURITY.md`、`.editorconfig`。
- 提供 `configs/config.example.yaml`、`android/local.properties.example`、`deploy/prod/.env.example` 等模板文件。

### Changed
- 后端配置脱敏：阿里云 SMS/OCR AccessKey 改由环境变量 `EH_SMS_ALIYUN_*` / `EH_OCR_ALIYUN_*` 注入；OTP 白名单默认留空。
- 客户端 `apiBaseUrl` 默认指向本机后端 `http://localhost:8080/v1`，生产用 `--dart-define=API_BASE_URL=...` 覆盖。
- 清理 `network_security_config.xml`，仅保留本地明文例外。

### Removed
- 取消跟踪机器特定文件（`local.properties`、`Generated.xcconfig`、`flutter_export_environment.sh`）与交叉编译二进制。

## [1.0.26] - 2026-09-24

### Added
- 自包含 v1.0.26 更新海报与生成脚本。

### Changed
- 复习用时显示秒级精度，避免短复习显示"0 分钟"。
- 复习历史轮次自增、已消灭图标重设计、复习进度显示下次复习时间。

### Fixed
- 复习/存储/周报/打卡多项问题修复并补回归测试。
- 系统性前后端契约对齐与字段缺失修复。

## [1.0.25] - 2026-09-22

### Added
- 精简注册为 OTP + 资料补全流程，新增自包含介绍海报。
- CI/CD：Docker Compose 一键启动、GitHub Actions 流水线、Makefile。

### Fixed
- 注册验证码总是失败的根因修复 + 错误提示改善。

## [1.0.0] - 2026-06-21

### Added
- 错题猎手 V1.0 首个可用版本：采集 → 归因 → 复习 → 消灭 全生命周期。
- Flutter 客户端（首页/采集/复习/报表/我的）+ Go 后端 + PostgreSQL/Redis/MinIO。
- 阿里云读光 OCR、号码认证 SMS、OSS 对象存储。
- 后端 + 前端单元测试（96 用例）与 V1.0 全面测试报告。
