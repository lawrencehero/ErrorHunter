# Security Policy

## 报告漏洞

感谢你帮助提升 ErrorHunter 的安全性。如果你发现安全漏洞，请**不要**在公开 Issue 中提交，而是通过以下方式私下报告：

- 邮件：security@errorhunter.com（请替换为实际维护者邮箱）
- GitHub Security Advisory：仓库 → Security → Report a vulnerability

报告时请尽量包含：
- 问题类型（如 SQL 注入、鉴权绕过、敏感信息泄露）
- 复现步骤 / PoC
- 影响范围与受影响版本
- 你建议的修复方向（可选）

我们会在 **5 个工作日内**响应并确认收到，修复进度通过原渠道同步。

## 处理原则

- 我们遵循 [Coordinated Vulnerability Disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure)（协调披露），在修复发布前不公开细节。
- 对提交有效漏洞报告的贡献者，我们会在致谢中列出（除非你希望匿名）。

## ⚠️ 提交前必读：禁止在 PR/Issue 中泄露密钥与个人隐私

- **严禁**在 Issue、PR、代码、配置、日志、截图、测试数据中出现真实密钥（AccessKey、JWT Secret、数据库密码）、真实手机号、真实用户数据。
- 后端密钥统一通过环境变量注入（前缀 `EH_`，见 `src/errorhunter_server/configs/config.example.yaml`）；客户端 API 地址通过 `--dart-define=API_BASE_URL=...` 注入。
- 测试中使用明显的占位号段（如 `13800138000`、`13812345678`）或 mock，不得使用真实号码。
- 若你发现自己的密钥已被提交，请立即轮换并联系维护者清理历史，不要仅靠删除文件。

## 支持的版本

ErrorHunter 处于开源初期，仅对最新发布版本（见 [Releases](../../releases)）提供安全修复。

## 安全配置要点

| 项 | 要求 |
|----|------|
| 数据库密码 | 生产必须随机强密码，`EH_DATABASE_PASSWORD` 注入 |
| JWT Secret | 生产必须随机 64 字符，`EH_JWT_ACCESS_SECRET` / `EH_JWT_REFRESH_SECRET` |
| 阿里云 AccessKey | 仅通过环境变量注入，不得写入仓库 |
| OTP 白名单 `bypass_phones` | 生产必须为空 |
| 后端端口 | 仅对外暴露 `APP_PORT`（默认 8080）；Postgres/Redis/MinIO 绑定 `127.0.0.1` |
| HTTPS | 生产建议前置反代启用 HTTPS，客户端 `network_security_config.xml` 仅保留本地明文例外 |
