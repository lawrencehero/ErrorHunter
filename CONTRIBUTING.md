# 贡献指南

感谢你愿意为 ErrorHunter 贡献代码！本文档帮助你快速上手开发流程。提交任何 PR 前，请先阅读：

- [行为准则](CODE_OF_CONDUCT.md)
- [安全策略](SECURITY.md)（尤其「禁止在 PR 中泄露密钥与个人隐私」一节）
- [提交规范](COMMIT_CONVENTION.md)

## 🛠️ 环境要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| Go | 1.21+ | 后端服务 |
| Flutter | 3.x（stable） | 客户端 |
| Dart | 随 Flutter | — |
| Docker / Docker Compose | 最新稳定版 | 本地起依赖（PG/Redis/MinIO） |
| Android SDK | API 34+ | 构建 APK |
| Python | 3.10+ | 可选，海报生成脚本 |

## 🚀 本地启动（开发联调）

1. **克隆并进入工程**
   ```bash
   git clone <repo-url> ErrorHunter
   cd ErrorHunter
   ```

2. **启动后端依赖 + 服务**
   ```bash
   cp deploy/.env.example deploy/.env          # 按需修改（开发默认值即可直接跑）
   docker compose -f deploy/docker-compose.yml up -d   # 起 PG/Redis/MinIO + server
   ```
   后端默认监听 `http://localhost:8080`，健康检查 `GET /health`。

3. **配置客户端连接本机后端**
   客户端默认指向 `http://localhost:8080/v1`。如需连接远程后端：
   ```bash
   flutter run --dart-define=API_BASE_URL=http://<your-server>:8080/v1
   ```
   > Web/Chrome 调试请务必带 `--dart-define`，默认 LAN IP 已不可用。

4. **Android SDK 路径**
   ```bash
   cp src/errorhunter_app/android/local.properties.example src/errorhunter_app/android/local.properties
   # 按本机路径修改 flutter.sdk / sdk.dir
   ```

5. **后端配置**
   ```bash
   cp src/errorhunter_server/configs/config.example.yaml src/errorhunter_server/configs/config.yaml
   ```
   开发默认值即可联调；密钥（阿里云 SMS/OCR）走环境变量 `EH_*` 注入，**不要**写入 config.yaml。

## 🧪 测试与检查

```bash
# 后端
cd src/errorhunter_server
go build ./... && go test ./...

# 客户端
cd src/errorhunter_app
flutter analyze && flutter test
```

PR 默认需通过以上检查；集成测试见 `deploy/docker-compose.test.yml`。

## 📂 分支与提交

- 分支模型：`main`（主干）+ `feature/<topic>` / `fix/<topic>` / `docs/<topic>`。
- 提交规范遵循 [Conventional Commits](COMMIT_CONVENTION.md)：`<type>(<scope>): <subject>`，例：
  ```
  feat(backend): 实现错题 OCR 入库接口
  fix(frontend): 修复复习列表空状态闪烁
  docs: 同步 API 文档与路由实现
  ```
- 提交粒度：一个 PR 解决一个问题，便于 review。

## 🔀 提交 PR 流程

1. Fork 仓库，从 `main` 切出功能分支。
2. 保证 `go build` / `go test` / `flutter analyze` / `flutter test` 通过。
3. 提交信息符合 Conventional Commits；多提交 PR 请保证每个提交可独立构建。
4. PR 描述说明动机、改动点、是否破坏兼容性，关联相关 Issue。
5. 等待 CI（GitHub Actions：lint/test/build-check）通过 + 维护者 review。
6. **禁止在 PR 中包含真实密钥、真实用户手机号、生产环境配置**；测试用占位号段（如 `13800138000`）。

## 📝 文档贡献

文档位于 `docs/`，按子目录组织（需求/PRD/技术设计/设计/测试）。修改代码影响对外契约（API、配置项、数据库 schema）时，请同步更新对应文档，避免文档与实现不一致。

## 🤝 行为准则

参与本项目即代表你同意遵守 [行为准则](CODE_OF_CONDUCT.md)。如有疑问，邮件联系维护者。
