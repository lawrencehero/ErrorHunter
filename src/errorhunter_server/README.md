# ErrorHunter Server

错题猎手后端服务 - Go + Gin + GORM + PostgreSQL + Redis + MinIO

## 项目结构

```
src/errorhunter_server/
├── cmd/server/main.go           # 应用入口
├── internal/
│   ├── config/                  # 配置管理 (Viper)
│   ├── middleware/              # JWT / CORS / RateLimit 中间件
│   ├── handler/                 # HTTP handlers
│   │   ├── auth_handler.go      # 认证模块
│   │   ├── question_handler.go  # 错题模块
│   │   ├── review_handler.go    # 复习模块
│   │   ├── report_handler.go    # 报告模块
│   │   ├── upload_handler.go    # 上传模块
│   │   ├── user_handler.go      # 用户模块
│   │   └── sync_handler.go      # 同步模块 (V1.1桩实现)
│   ├── service/                 # 业务逻辑层
│   │   ├── auth_service.go      # OTP/JWT/注册登录
│   │   ├── question_service.go  # 错题CRUD
│   │   └── review_service.go    # 复习调度算法
│   ├── repository/              # 数据访问层
│   │   ├── user_repository.go
│   │   ├── question_repository.go
│   │   ├── review_repository.go
│   │   └── report_repository.go
│   ├── model/                   # 数据模型
│   │   ├── model.go             # User/Question/ReviewRecord等
│   │   └── jsonb.go             # JSONB类型支持
│   └── pkg/                     # 工具包
│       ├── errcode/             # 统一错误码
│       ├── jwt/                 # JWT双token机制
│       ├── ocr/                 # OCR服务(桩实现)
│       └── scheduler/           # 艾宾浩斯复习调度算法
├── configs/config.yaml          # 配置文件
├── migrations/                  # 数据库迁移
├── Dockerfile                   # 多阶段构建
├── docker-compose.dev.yml       # 本地开发环境
├── Makefile                     # 构建脚本
└── go.mod                       # Go模块定义
```

## 已实现的 API 端点 (28个)

### Auth 模块 (4个)
- `POST /v1/auth/otp/send` — 发送短信验证码
- `POST /v1/auth/otp/verify` — 验证OTP并返回JWT
- `POST /v1/auth/refresh` — 刷新access token
- `POST /v1/auth/logout` — 登出（撤销refresh token）

### Questions 模块 (9个)
- `GET /v1/questions` — 列表（分页+筛选）
- `POST /v1/questions` — 新增错题
- `GET /v1/questions/:id` — 详情
- `PUT /v1/questions/:id` — 更新
- `DELETE /v1/questions/:id` — 软删除
- `GET /v1/questions/recycle-bin` — 回收站列表
- `POST /v1/questions/:id/restore` — 恢复
- `DELETE /v1/questions/:id/permanent` — 永久删除
- `DELETE /v1/questions/recycle-bin/clear` — 清空回收站

### Reviews 模块 (3个)
- `GET /v1/reviews/queue` — 今日复习队列
- `POST /v1/reviews/result` — 提交复习结果
- `GET /v1/reviews` — 复习历史

### Reports 模块 (3个)
- `GET /v1/reports` — Dashboard概览
- `GET /v1/reports/weekly` — 周报列表
- `GET /v1/reports/weekly/:id` — 周报详情

### Upload 模块 (3个)
- `POST /v1/upload` — 上传图片到MinIO
- `POST /v1/upload/ocr` — OCR识别
- `GET /v1/upload/signed-url` — 获取签名URL

### User 模块 (3个)
- `GET /v1/users/me` — 获取用户信息
- `PUT /v1/users/me/settings` — 更新设置
- `POST /v1/users/me/deactivate` — 注销账号

### Sync 模块 (2个, V1.1桩实现)
- `POST /v1/sync/push` — 推送本地变更
- `GET /v1/sync/pull` — 拉取远端变更

### Health Check (1个)
- `GET /health` — 健康检查

## 核心功能实现状态

| 功能 | 状态 | 说明 |
|------|------|------|
| JWT双token机制 | ✅ 完成 | access 15min, refresh 7天 |
| OTP验证码 | ✅ 完成 | 6位数字，5分钟过期，Redis存储 |
| 艾宾浩斯复习调度 | ✅ 完成 | 5轮间隔: 1,2,4,7,16天 |
| 消灭引擎状态机 | ✅ 完成 | NOT_STARTED→REVIEWING→MASTERED→PERMANENTLY_MASTERED |
| 复活检测降频 | ✅ 完成 | 30→60→90天递进 |
| OCR集成 | ⚠️ 桩实现 | 阿里云OCR接口预留，当前返回固定文本 |
| 图片上传(MinIO) | ✅ 完成 | S3兼容存储 |
| 每日复习上限 | ✅ 完成 | 默认20道，优先级排序 |
| 积压大扫除排序 | ✅ 完成 | >50道时启用 |
| 离线同步 | ⚠️ 桩实现 | V1.1完整实现 |
| 学情统计 | ⚠️ 简化版 | Dashboard框架就绪，需完善聚合查询 |
| 周报生成 | ⏳ 待实现 | 定时任务待添加 |

## 快速开始

### 前置要求
- Go 1.22+
- Docker & Docker Compose

### 本地开发

```bash
cd src/errorhunter_server

# 启动基础设施
docker-compose -f docker-compose.dev.yml up -d postgres redis minio minio-init

# 下载依赖
go mod tidy

# 运行服务
make run
```

### Docker部署

```bash
# 构建镜像
make docker-build

# 启动全部服务
make docker-run

# 查看日志
make docker-logs
```

## 配置说明

配置文件: `configs/config.yaml`

支持环境变量覆盖，前缀 `EH_`:
- `EH_SERVER_PORT` — 服务端口
- `EH_DATABASE_HOST` — 数据库地址
- `EH_REDIS_ADDR` — Redis地址
- `EH_MINIO_ENDPOINT` — MinIO地址
- `EH_JWT_ACCESS_SECRET` — JWT密钥

## 技术栈

- **Web框架**: Gin
- **ORM**: GORM
- **数据库**: PostgreSQL 16
- **缓存**: Redis 7
- **对象存储**: MinIO (S3兼容)
- **JWT**: golang-jwt/v5
- **配置管理**: Viper
- **日志**: Zap (TODO)

## TODO / 遗留项

1. **编译验证**: 需要网络环境下载依赖后验证 `go build`
2. **单元测试**: 各模块测试用例
3. **日志集成**: Zap结构化日志
4. **定时任务**: 周报生成、Dashboard预计算
5. **消息队列**: 异步任务处理
6. **监控告警**: Prometheus + Grafana
7. **API文档**: Swagger/OpenAPI自动生成
8. **国际化**: i18n支持
9. **完整的Dashboard聚合查询**
10. **知识点AI推荐引擎**

## 参考文档

- 技术设计: `docs/04-技术设计/`
- API契约: `src/errorhunter_app/lib/data/remote/api_endpoints.dart`
- 数据库DDL: `deploy/docker/init-db.sql`
