# 错题猎手（ErrorHunter）— Docker 本地开发环境

## 快速开始

### Windows 用户

```powershell
cd deploy/docker
Copy-Item .env.example .env       # 按需修改密码等配置
.\start.ps1                       # 一键启动
```

### Linux / macOS 用户

```bash
cd deploy/docker
cp .env.example .env              # 按需修改密码等配置
chmod +x start.sh
./start.sh                        # 一键启动
```

---

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| PostgreSQL | `postgres:16` | 5432 | 主数据库 |
| Redis | `redis:7` | 6379 | 缓存 / 会话 / 验证码 |
| MinIO | `minio/minio` | 9000 (API) / 9001 (Console) | 对象存储（兼容 S3，替代阿里云 OSS） |

## 默认连接信息

### PostgreSQL
- **Host:** `localhost`
- **Port:** `5432`
- **Database:** `errorhunter`
- **User:** `errorhunter`
- **Password:** `errorhunter_dev`
- **Connection String:** `postgresql://errorhunter:errorhunter_dev@localhost:5432/errorhunter`

### Redis
- **Host:** `localhost`
- **Port:** `6379`
- **URL:** `redis://localhost:6379`

### MinIO
- **API Endpoint:** `http://localhost:9000`
- **Console:** `http://localhost:9001`
- **Root User:** `minioadmin`
- **Root Password:** `minioadmin123`

> ⚠️ 以上为开发环境默认值，生产部署请务必修改密码。

---

## Docker Desktop 国内镜像加速

由于国内网络访问 Docker Hub 较慢，建议配置镜像加速器。

### 步骤

1. 登录 [阿里云容器镜像服务](https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors)
2. 获取你的**专属加速器地址**（格式：`https://xxxxx.mirror.aliyuncs.com`）
3. 打开 Docker Desktop → Settings → Docker Engine
4. 将 `daemon.json` 中的 `<YOUR_ACCELERATOR_ID>` 替换为你的 ID：

```json
{
  "registry-mirrors": [
    "https://<YOUR_ACCELERATOR_ID>.mirror.aliyuncs.com"
  ]
}
```

5. 点击 **Apply & Restart**

> 本项目提供的 `daemon.json` 已包含备用镜像源（docker.1ms.run、docker.xuanyuan.me），
> 即使不配置阿里云加速器也可尝试使用，但速度不保证。

---

## 环境变量说明

所有敏感配置通过 `.env` 文件管理，`docker-compose.yml` 中使用 `${VAR:-default}` 引用。

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `POSTGRES_PORT` | 5432 | PostgreSQL 宿主机端口 |
| `POSTGRES_DB` | errorhunter | 数据库名 |
| `POSTGRES_USER` | errorhunter | 数据库用户 |
| `POSTGRES_PASSWORD` | errorhunter_dev | 数据库密码 |
| `REDIS_PORT` | 6379 | Redis 宿主机端口 |
| `MINIO_API_PORT` | 9000 | MinIO API 端口 |
| `MINIO_CONSOLE_PORT` | 9001 | MinIO 控制台端口 |
| `MINIO_ROOT_USER` | minioadmin | MinIO root 用户 |
| `MINIO_ROOT_PASSWORD` | minioadmin123 | MinIO root 密码 |
| `COMPOSE_PROJECT_NAME` | errorhunter | Docker Compose 项目名 |

---

## 常用命令

```bash
# 启动所有服务
docker compose up -d

# 停止所有服务
docker compose down

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f postgres
docker compose logs -f redis
docker compose logs -f minio

# 重建并启动（修改了 compose 文件后）
docker compose up -d --build

# 清除所有数据卷（⚠️ 会删除所有持久化数据）
docker compose down -v

# 进入 PostgreSQL 命令行
docker exec -it errorhunter-postgres psql -U errorhunter -d errorhunter

# 进入 Redis 命令行
docker exec -it errorhunter-redis redis-cli
```

---

## 数据库初始化

PostgreSQL 容器首次启动时会自动执行 `init-db.sql`，包含：

- 8 种枚举类型定义
- 8 张业务表（users、questions、review_records、knowledge_points、question_knowledge、weekly_reports、sync_queue、user_devices）
- 完整的索引体系
- 基础知识点种子数据

> ⚠️ `init-db.sql` 仅在数据卷 `pgdata` 为空时执行。如需重新初始化，先执行 `docker compose down -v` 清除数据卷。

---

## 文件结构

```
deploy/docker/
├── README.md              # 本文档
├── daemon.json            # Docker Desktop 镜像加速配置
├── docker-compose.yml     # 服务编排
├── init-db.sql            # 数据库初始化脚本
├── .env.example           # 环境变量模板
├── start.sh               # Linux/macOS 启动脚本
└── start.ps1              # Windows PowerShell 启动脚本
```
