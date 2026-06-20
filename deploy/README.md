# 错题猎手（ErrorHunter）— Docker 集成测试 & 开发环境

## 📋 目录

- [前置条件](#前置条件)
- [快速开始](#快速开始)
- [服务清单](#服务清单)
- [环境变量说明](#环境变量说明)
- [常用命令](#常用命令)
- [运行测试](#运行测试)
- [数据库初始化](#数据库初始化)
- [文件结构](#文件结构)
- [故障排查](#故障排查)

---

## 前置条件

| 工具 | 最低版本 | 说明 |
|------|----------|------|
| Docker | 24.0+ | 容器运行时 |
| Docker Compose | v2.20+ | 服务编排（Docker Desktop 自带） |
| Make | 3.81+ | 可选，用于快捷命令 |

验证安装：
```bash
docker --version        # Docker version 24.x.x
docker compose version  # Docker Compose version v2.x.x
```

---

## 快速开始

### 一键启动

```bash
# 进入 deploy 目录
cd deploy

# 复制环境变量模板
cp .env.example .env

# 启动所有服务
make up
# 或者手动执行
docker compose up -d

# 等待所有服务健康后，访问 API
curl http://localhost:8080/health
# {"status":"ok"}
```

### Windows PowerShell

```powershell
cd deploy
Copy-Item .env.example .env
docker compose up -d
```

---

## 服务清单

| 服务 | 镜像 | 内部端口 | 外部端口 | 用途 |
|------|------|----------|----------|------|
| PostgreSQL | `postgres:16-alpine` | 5432 | 5432 | 主数据库 |
| Redis | `redis:7-alpine` | 6379 | 6379 | 缓存 / 会话 / OTP |
| MinIO | `minio/minio:latest` | 9000 / 9001 | 9000 / 9001 | 对象存储（S3 兼容） |
| Server | 自建 (Go) | 8080 | 8080 | 后端 API 服务 |

### 默认连接信息

**PostgreSQL**
```
Host:     localhost:5432
Database: errorhunter
User:     errorhunter
Password: errorhunter_dev
DSN:      postgresql://errorhunter:errorhunter_dev@localhost:5432/errorhunter
```

**Redis**
```
URL: redis://localhost:6379
```

**MinIO**
```
API:      http://localhost:9000
Console:  http://localhost:9001
User:     minioadmin
Password: minioadmin123
Bucket:   errorhunter
```

**Backend API**
```
Base URL: http://localhost:8080
Health:   GET /health
API Docs: /v1/*
```

> ⚠️ 以上为开发环境默认值，生产部署请务必修改密码和 JWT Secret。

---

## 环境变量说明

所有配置通过 `.env` 文件管理，使用 `${VAR:-default}` 引用。

### 应用服务

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `APP_PORT` | 8080 | API 服务宿主机端口 |
| `APP_MODE` | debug | Gin 运行模式 (debug/release/test) |
| `CONFIG_PATH` | /app/configs/config.yaml | 配置文件路径 |

### 数据库

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `POSTGRES_PORT` | 5432 | PostgreSQL 宿主机端口 |
| `POSTGRES_DB` | errorhunter | 数据库名 |
| `POSTGRES_USER` | errorhunter | 数据库用户 |
| `POSTGRES_PASSWORD` | errorhunter_dev | 数据库密码 |
| `POSTGRES_TEST_DB` | errorhunter_test | 测试数据库名 |

### Redis

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `REDIS_PORT` | 6379 | Redis 宿主机端口 |
| `REDIS_PASSWORD` | (空) | Redis 密码（开发环境可为空） |

### MinIO

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MINIO_API_PORT` | 9000 | MinIO API 端口 |
| `MINIO_CONSOLE_PORT` | 9001 | MinIO 控制台端口 |
| `MINIO_ROOT_USER` | minioadmin | MinIO root 用户 |
| `MINIO_ROOT_PASSWORD` | minioadmin123 | MinIO root 密码 |
| `MINIO_BUCKET` | errorhunter | S3 Bucket 名称 |

### JWT

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `JWT_ACCESS_SECRET` | (见 .env.example) | Access Token 签名密钥 |
| `JWT_REFRESH_SECRET` | (见 .env.example) | Refresh Token 签名密钥 |
| `JWT_ACCESS_EXPIRE` | 15 | Access Token 有效期（分钟） |
| `JWT_REFRESH_EXPIRE` | 10080 | Refresh Token 有效期（分钟，7天） |

### OTP

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OTP_EXPIRE` | 300 | 验证码有效期（秒） |
| `OTP_RESEND_INTERVAL` | 60 | 重发间隔（秒） |
| `OTP_DAILY_LIMIT` | 10 | 每日发送上限 |
| `OTP_MAX_RETRY` | 5 | 最大错误尝试次数 |
| `OTP_LOCKOUT_DURATION` | 1800 | 锁定时长（秒） |

### OCR

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OCR_PROVIDER` | mock | OCR 提供者 (mock/aliyun) |
| `OCR_TIMEOUT` | 5 | OCR 超时时间（秒） |

---

## 常用命令

如果安装了 Make，可直接使用以下快捷命令：

```bash
make up          # 启动所有服务
make down        # 停止并移除所有服务
make restart     # 重启所有服务
make logs        # 查看所有服务日志
make status      # 查看服务状态
make test        # 运行集成测试
make db-shell    # 进入 PostgreSQL 命令行
make redis-cli   # 进入 Redis 命令行
make clean       # 停止服务并清除所有数据卷 ⚠️
```

手动执行等效命令：

```bash
# 启动
docker compose up -d

# 停止
docker compose down

# 查看日志
docker compose logs -f server

# 重建（修改了代码或 Dockerfile 后）
docker compose up -d --build server

# 仅重启某个服务
docker compose restart server
```

---

## 运行测试

### 方式一：Docker Compose 集成测试（推荐）

在隔离环境中运行完整测试套件：

```bash
# 运行测试（测试完成后自动退出）
make test

# 或手动执行
docker compose -f docker-compose.test.yml up \
  --abort-on-container-exit \
  --exit-code-from test-runner

# 清理测试容器
docker compose -f docker-compose.test.yml down -v
```

特点：
- 使用独立的测试数据库 (`errorhunter_test`)
- PostgreSQL 和 Redis 使用 tmpfs（内存存储），速度更快
- 测试结束后容器自动退出
- 不影响开发环境数据

### 方式二：本地 Go 测试

确保基础设施服务已启动后，在本地运行：

```bash
cd ../src/errorhunter_server
go test -v -race -cover ./...
```

### 方式三：进入容器调试

```bash
# 进入正在运行的 server 容器
docker exec -it errorhunter-server sh

# 在容器内运行特定测试
docker exec -it errorhunter-test-runner go test -v -run TestAuth ./internal/service/...
```

---

## 数据库初始化

### 自动初始化

PostgreSQL 容器首次启动时自动执行 `init-db.sql`，包含：

- **8 种枚举类型**：grade_enum, question_status_enum, error_category_enum 等
- **8 张业务表**：users, questions, review_records, knowledge_points, question_knowledge, weekly_reports, sync_queue, user_devices
- **完整的索引体系**：覆盖所有高频查询场景
- **基础知识点种子数据**：小学 + 初中数学一级/二级/三级分类

### 重新初始化

如需重置数据库：

```bash
# 停止服务并删除数据卷
docker compose down -v

# 重新启动（会自动执行 init-db.sql）
docker compose up -d
```

> ⚠️ `init-db.sql` 仅在数据卷 `pgdata` 为空时执行。已有数据的容器不会重复执行。

### 手动执行 SQL

```bash
# 连接到数据库
docker exec -it errorhunter-postgres psql -U errorhunter -d errorhunter

# 或在宿主机使用 psql
psql "postgresql://errorhunter:errorhunter_dev@localhost:5432/errorhunter"
```

---

## 文件结构

```
deploy/
├── README.md                  # 本文档
├── Makefile                   # 快捷命令（位于项目根目录）
├── docker-compose.yml         # 主环境编排（开发 + 集成测试）
├── docker-compose.test.yml    # 测试专用编排（隔离环境）
├── Dockerfile                 # Go 后端多阶段构建
├── Dockerfile.test            # 测试专用构建
├── init-db.sql                # 数据库初始化脚本
├── .env.example               # 环境变量模板
└── .env                       # 实际环境变量（不提交到 Git）
```

---

## 故障排查

### 1. 端口被占用

```bash
# 检查端口占用
lsof -i :5432   # macOS/Linux
netstat -ano | findstr :5432  # Windows

# 修改 .env 中的端口映射
POSTGRES_PORT=5433
REDIS_PORT=6380
```

### 2. 服务启动失败

```bash
# 查看详细日志
docker compose logs postgres
docker compose logs server

# 检查容器状态
docker compose ps

# 检查健康检查
docker inspect --format='{{json .State.Health}}' errorhunter-postgres
```

### 3. 数据库连接失败

常见原因：
- PostgreSQL 尚未就绪 → 等待 healthcheck 通过
- 密码不匹配 → 检查 `.env` 中的 `POSTGRES_PASSWORD`
- 数据卷残留旧配置 → `docker compose down -v` 后重启

### 4. Go 构建失败

```bash
# 清除构建缓存重建
docker compose build --no-cache server

# 检查 go mod
cd ../src/errorhunter_server
go mod tidy
go mod verify
```

### 5. MinIO bucket 不存在

```bash
# 手动创建 bucket
docker exec -it errorhunter-minio mc alias set local http://localhost:9000 minioadmin minioadmin123
docker exec -it errorhunter-minio mc mb local/errorhunter --ignore-existing

# 或通过 minio-init 服务重建
docker compose up minio-init
```

### 6. Docker 拉取镜像慢

配置国内镜像加速器：

1. 打开 Docker Desktop → Settings → Docker Engine
2. 添加镜像源：

```json
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me"
  ]
}
```

3. Apply & Restart

### 7. 测试环境数据未清理

```bash
# 强制清理测试容器和数据卷
docker compose -f docker-compose.test.yml down -v --remove-orphans

# 清理悬空镜像
docker image prune -f
```

---

## 架构说明

```
┌─────────────────────────────────────────────┐
│              Docker Network                  │
│           (errorhunter-net)                  │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Postgres │  │  Redis   │  │  MinIO   │  │
│  │  :5432   │  │  :6379   │  │  :9000   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │              │              │         │
│       └──────────────┼──────────────┘         │
│                      │                        │
│              ┌───────┴───────┐                │
│              │  Go Server    │                │
│              │    :8080      │                │
│              └───────┬───────┘                │
│                      │                        │
└──────────────────────┼────────────────────────┘
                       │
              Host Port Mapping
              localhost:8080
```

---

## 注意事项

1. **安全**：`.env` 文件已在 `.gitignore` 中，不会被提交到仓库
2. **数据持久化**：PostgreSQL、Redis、MinIO 的数据均通过 Docker Volume 持久化
3. **配置优先级**：环境变量 > config.yaml 文件（通过 Viper 的 `EH_` 前缀实现）
4. **健康检查**：所有服务均配置了 healthcheck，server 服务依赖其他服务健康后才启动
5. **测试隔离**：`docker-compose.test.yml` 使用独立网络和临时存储，不影响开发环境
