# 错题猎手（ErrorHunter）CI/CD 流水线

## 📋 概览

本项目使用 GitHub Actions 实现自动化 CI/CD 流水线，包含三条核心工作流：

| 工作流 | 文件 | 触发条件 | 用途 |
|--------|------|----------|------|
| **CI** | `ci.yml` | PR / Push to main | 代码检查、测试、构建验证 |
| **CD** | `cd.yml` | Push to main / Tag / 手动 | 镜像构建、Staging/Production 部署 |
| **PR 质量门禁** | `pr-check.yml` | PR 创建/更新 | Commit 规范、覆盖率、安全扫描 |

---

## 🔧 CI 流水线详解

### 并行执行的任务

```
PR / Push to main
       │
       ├── 🔍 backend-lint      (golangci-lint)
       ├── 🧪 backend-test      (go test + coverage)
       ├── 🔍 frontend-lint     (flutter analyze)
       ├── 🧪 frontend-test     (flutter test + coverage)
       └── 🐳 build-check       (Docker 构建验证)
              │
              ▼
       🔗 backend-integration-test  (docker-compose.test.yml)
```

- **backend-lint**: 使用 golangci-lint 检查 Go 代码质量
- **backend-test**: 运行 Go 单元测试，生成覆盖率报告
- **backend-integration-test**: 使用 `deploy/docker-compose.test.yml` 启动完整测试环境（PostgreSQL + Redis + MinIO），运行集成测试
- **frontend-lint**: Flutter 代码分析 + 格式化检查
- **frontend-test**: Flutter 单元测试 + 覆盖率
- **build-check**: 验证 Docker 镜像可正常构建

### 缓存策略

- Go modules: 通过 `actions/setup-go@v5` 自动缓存
- Flutter pub cache: 通过 `subosito/flutter-action@v2` 内置缓存
- Docker layers: 通过 GitHub Actions cache (`type=gha`)

---

## 🚀 CD 部署流水线

### 部署流程

```
Push to main / Tag v*
       │
       ▼
  🏗️ build-and-push    → 构建镜像并推送到 GHCR
       │
       ▼
  🚀 deploy-staging     → 部署到 Staging 环境
       │
       ▼
  💨 smoke-test         → Staging 冒烟测试
       │
       ▼ (仅 tag 或手动指定)
  🎯 deploy-production  → 部署到 Production（需审批）
```

### 镜像标签规则

| 来源 | 标签示例 |
|------|----------|
| Push to main | `<commit-sha>`, `latest` |
| Tag `v1.2.3` | `v1.2.3`, `1.2.3`, `<commit-sha>` |
| 手动触发 | 自定义或 `<commit-sha>` |

### 环境配置

需要在 GitHub 仓库中配置以下环境：

1. **staging**: 自动部署，无需审批
2. **production**: 需要至少一名审批人批准

配置路径: `Settings → Environments → New environment`

### 手动部署

在 Actions 页面选择 "CD" 工作流，点击 "Run workflow"：
- 选择目标环境（staging / production）
- 可选指定镜像标签

---

## 🔒 PR 质量门禁

每个 PR 会自动执行以下检查：

### 1. Commit 消息规范
使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：
```
<type>(<scope>): <description>

类型: feat | fix | docs | style | refactor | perf | test | build | ci | chore | revert
范围: backend | frontend | deploy | docs | ci
```

### 2. 代码覆盖率
- 后端最低覆盖率要求: **60%**
- 覆盖率报告会自动评论到 PR

### 3. 安全扫描
- 使用 `gosec` 扫描 Go 代码安全问题
- 检查结果上传到 GitHub Security tab
- 额外检查硬编码密钥/敏感信息

---

## 📊 查看 CI 状态

### 方式一：GitHub Web UI
1. 进入仓库 → **Actions** 标签页
2. 查看各工作流的运行状态
3. 点击具体运行查看详细日志

### 方式二：PR 页面
- PR 底部的 "Checks" 区域显示所有门禁状态
- 点击 "Details" 查看失败原因

### 方式三：命令行
```bash
# 使用 gh CLI
gh run list                           # 查看所有运行
gh run view <run-id>                  # 查看详情
gh run watch <run-id>                 # 实时跟踪
```

---

## 🌿 分支策略

```
main          ← 生产分支，受保护
  │
  ├── feat/*   ← 功能分支
  ├── fix/*    ← 修复分支
  ├── hotfix/* ← 紧急修复
  └── release/*← 发布准备
```

### 分支保护规则（建议在 GitHub 中配置）

- ✅ 要求 PR 审查（至少 1 人）
- ✅ 要求状态检查通过（CI + PR 质量门禁）
- ✅ 禁止强制推送
- ✅ 禁止直接删除
- ✅ 要求线性历史（可选）

---

## 🤖 自动依赖更新

Dependabot 每周一自动检查以下依赖更新：
- Go modules（后端）
- Flutter pub packages（前端）
- GitHub Actions
- Docker 基础镜像

更新的 PR 会自动标记 `dependencies` 标签。

---

## ⚙️ 运维备忘

### 常用命令（Makefile）

```bash
make test           # 运行 Docker 集成测试
make test-local     # 本地运行 Go 测试
make test-coverage  # 生成覆盖率 HTML 报告
make lint           # 运行 golangci-lint
make clean          # 清理所有容器和数据卷
```

### 故障排查

| 问题 | 排查方向 |
|------|----------|
| 集成测试超时 | 检查 docker-compose.test.yml 中的 healthcheck |
| 缓存未命中 | 检查 go.sum / pubspec.lock 是否变更 |
| 镜像构建失败 | 本地 `docker build -f deploy/Dockerfile src/errorhunter_server` 复现 |
| 覆盖率不达标 | 下载 Artifact 查看详细覆盖情况 |
| 安全扫描误报 | 在 `.gosec.json` 中添加排除规则 |
