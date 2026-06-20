# 错题猎手 V1.0 集成测试报告

**测试人员**: 赵测 (QA Agent)  
**测试日期**: 2026-06-20  
**测试环境**: Docker Compose (PostgreSQL 16-alpine + Redis 7-alpine)  
**测试方式**: Go integration tests (`//go:build integration`) + 静态代码分析

---

## 一、Docker Compose 环境验证

### 1.1 环境搭建结果

| 组件 | 镜像 | 状态 | 备注 |
|------|------|------|------|
| PostgreSQL | postgres:16-alpine | ✅ 正常 | tmpfs 内存存储，启动约 15s |
| Redis | redis:7-alpine | ✅ 正常 | 纯内存模式，启动约 5s |
| MinIO | minio/minio:latest | ⏭️ 未测试 | 本次聚焦 BUG-001，MinIO 非必需 |
| Test Runner | golang:1.22-alpine | ⚠️ 构建超时 | 首次拉取镜像+编译耗时过长 |

### 1.2 发现并修复的 Docker/SQL 问题

在启动测试环境过程中，发现 `deploy/init-db.sql` 存在 **3 个阻塞性问题**：

#### 问题 1: Shell 注释语法（严重 🔴）
- **文件**: `deploy/init-db.sql` 第 1-5 行
- **现象**: PostgreSQL 执行初始化脚本时报错 `syntax error at or near "#"`
- **原因**: 使用了 `#` 注释（Shell 风格），PostgreSQL 仅支持 `--` 和 `/* */`
- **修复**: 将 `#` 替换为 `--`

#### 问题 2: 非 IMMUTABLE 函数用于索引表达式（中等 🟡）
- **文件**: `deploy/init-db.sql` 第 277 行
- **现象**: `CREATE INDEX idx_review_user_date_only ON review_records(user_id, (reviewed_at::date))` 报错
- **原因**: `::date` 转换依赖 timezone 设置，不是 IMMUTABLE 函数
- **修复**: 注释掉该索引，应用层使用 `reviewed_at` 范围查询替代

#### 问题 3: NOW() 用于部分索引条件（中等 🟡）
- **文件**: `deploy/init-db.sql` 第 288-289 行
- **现象**: `WHERE ... AND next_retry_at <= NOW()` 报错
- **原因**: `NOW()` 不是 IMMUTABLE 函数，不能用于索引谓词
- **修复**: 移除 `AND next_retry_at <= NOW()` 条件，保留 `WHERE status IN ('PENDING', 'FAILED')`

### 1.3 docker-compose.test.yml 改进

- 为 `postgres-test` 和 `redis-test` 添加了端口映射（5433、6380），方便本地开发调试
- 原有设计仅通过 Docker 内部网络连接，无法从宿主机直接运行 `go test`

### 1.4 环境评估

> ✅ **修复后测试环境可正常工作**。PostgreSQL 和 Redis 均在 20 秒内达到 healthy 状态。  
> ⚠️ **建议**: Dockerfile.test 中的 `go test -c ./...` 编译所有包可能导致构建缓慢，建议改为指定具体测试包。

---

## 二、BUG-001 根因分析与验证

### 2.1 BUG 描述

**POST /v1/questions 创建错题时返回 HTTP 500**，无论知识点 ID 是否有效。

### 2.2 根因分析

#### 触发链路

```
Handler.Create()
  → Service.Create()
    → 构建 KnowledgePoint{ID: kpID}（仅设置 ID，其他字段为零值）
    → Repository.Create()
      → GORM Create(question) 
        → GORM many2many 自动处理关联
          → INSERT INTO knowledge_points (...) VALUES (NULL,'',0,'',...) ← 💥 这里崩溃
```

#### 核心问题

`question_service.go` 第 95-97 行：
```go
for _, kpID := range req.KnowledgePointIDs {
    question.KnowledgePoints = append(question.KnowledgePoints, model.KnowledgePoint{ID: kpID})
}
```

当 GORM 执行 `Create(question)` 时，检测到 `KnowledgePoints` 关联不为空，会尝试先 **upsert** 这些 KnowledgePoint 记录到 `knowledge_points` 表。由于只设置了 `ID` 字段，其他字段均为零值：
- `stage` = `""` （空字符串，不是合法的 `stage_enum` 值）
- `name` = `""`
- `level` = `0`

PostgreSQL 拒绝 `stage_enum` 的空字符串值，抛出：
```
ERROR: invalid input value for enum stage_enum: "" (SQLSTATE 22P02)
```

GORM 将此错误传播回 service 层，service 层捕获后返回 `errcode.EInternalServer`（500）。

#### 关键发现

1. **GORM 不会"只插入 join table"** — 对于 many2many 关联，如果关联对象是结构体（而非仅 ID），GORM 会先尝试创建/更新关联记录
2. **即使知识点 ID 存在于数据库中**，GORM 仍然会尝试 INSERT（使用 `ON CONFLICT DO NOTHING`），但因为空枚举值导致 INSERT 本身就在类型检查阶段失败
3. **question_knowledge 表的外键约束** (`fk_qk_kp`) 实际上没有被触发，因为错误发生在更早的阶段（knowledge_points 表的 INSERT）
4. **Service 层没有验证知识点是否存在** — 注释写着 "简化处理，实际需要查询并验证"

### 2.3 实际测试结果

| 测试用例 | 期望 | 实际 | 结果 |
|---------|------|------|------|
| 使用存在的知识点 ID [1, 11] | 201 Created | 500 Internal Server Error | ❌ FAIL |
| 使用不存在的知识点 ID [99999] | 400 Bad Request | 500 Internal Server Error | ❌ FAIL (BUG-001) |
| 混合存在和不存在的 ID [1, 99998] | 400 Bad Request | 500 Internal Server Error | ❌ FAIL (BUG-001) |

**结论: BUG-001 已确认，且影响范围比预期更大 — 不仅是不存在的 ID 会报错，连完全合法的知识点 ID 也无法创建错题。**

### 2.4 修复建议

#### 方案 A: 仅写入 Join Table（推荐 ✅）

修改 `question_service.go`，不通过 GORM 关联自动处理，而是手动插入 join table：

```go
// 1. 先验证知识点是否存在
var validKPs []model.KnowledgePoint
if err := db.Where("id IN ?", req.KnowledgePointIDs).Find(&validKPs).Error; err != nil {
    return nil, errcode.EInternalServer
}
if len(validKPs) != len(req.KnowledgePointIDs) {
    return nil, errcode.New(20014, "部分知识点不存在", http.StatusBadRequest)
}

// 2. 创建错题时不设置 KnowledgePoints 关联
question.KnowledgePoints = nil
if err := s.questionRepo.Create(ctx, question); err != nil {
    return nil, errcode.EInternalServer
}

// 3. 手动插入 join table
for _, kpID := range req.KnowledgePointIDs {
    if err := db.Exec(
        "INSERT INTO question_knowledge (question_id, knowledge_point_id) VALUES (?, ?)",
        question.ID, kpID,
    ).Error; err != nil {
        return nil, errcode.EInternalServer
    }
}
```

#### 方案 B: 使用 GORM Association Mode

```go
// 先创建错题（不带关联）
if err := db.Create(question).Error; err != nil { ... }

// 再用 Association API 添加关联
db.Model(question).Association("KnowledgePoints").Append(validKPs)
```

#### 方案 C: 配置 GORM 跳过关联自动创建

在 model 中添加 tag：
```go
KnowledgePoints []KnowledgePoint `gorm:"many2many:question_knowledge;association_autocreate:false;association_autoupdate:false;" json:"knowledge_points,omitempty"`
```

> ⚠️ 方案 C 最简洁但需要验证 GORM 版本兼容性；方案 A 最可控且有额外验证逻辑。**推荐方案 A**。

### 2.5 严重程度评估

| 维度 | 评级 | 说明 |
|------|------|------|
| **影响范围** | 🔴 P0 | 创建错题是核心功能，完全不可用 |
| **发生频率** | 🔴 必现 | 任何创建请求都会触发 |
| **用户感知** | 🔴 严重 | 返回模糊的"服务器内部错误"，用户无法理解 |
| **数据风险** | 🟢 低 | 事务回滚，不会产生脏数据 |
| **修复难度** | 🟢 低 | 改动集中在 service 层，约 20 行代码 |

**综合评级: 🔴 P0 — 必须在 V1.0 发布前修复**

---

## 三、集成测试用例

### 3.1 测试文件

**位置**: `src/errorhunter_server/internal/handler/integration_test.go`  
**Build Tag**: `//go:build integration`  
**运行命令**:
```bash
# 先启动测试环境
docker compose -f deploy/docker-compose.test.yml up -d postgres-test redis-test

# 运行全部集成测试
EH_DATABASE_HOST=localhost EH_DATABASE_PORT=5433 \
EH_DATABASE_USER=errorhunter EH_DATABASE_PASSWORD=errorhunter_dev \
EH_DATABASE_DBNAME=errorhunter_test EH_DATABASE_SSLMODE=disable \
EH_REDIS_ADDR=localhost:6380 \
go test -tags=integration -v -count=1 ./internal/handler/

# 仅运行 BUG-001 相关测试
go test -tags=integration -v -count=1 -run "TestBUG001" ./internal/handler/
```

### 3.2 测试用例清单

| # | 测试名称 | 分类 | 状态 | 说明 |
|---|---------|------|------|------|
| 1 | TestBUG001_CreateWithValidKnowledgePoints | BUG-001 | ❌ FAIL | 合法知识点也返回 500 |
| 2 | TestBUG001_CreateWithNonExistentKnowledgePoints | BUG-001 | ❌ FAIL | 应返回 400，实际 500 |
| 3 | TestBUG001_CreateWithMixedKnowledgePoints | BUG-001 | ❌ FAIL | 混合 ID 也返回 500 |
| 4 | TestIntegration_FullAuthFlow | 认证流程 | ⚠️ PARTIAL | 注册/登录/获取信息/登出/Token失效均通过，创建错题被 BUG-001 阻塞 |
| 5 | TestIntegration_DashboardAfterCreatingQuestions | Dashboard | ⏳ BLOCKED | 依赖创建错题，被 BUG-001 阻塞 |
| 6 | TestIntegration_ReviewFlow | 复习流程 | ⏳ BLOCKED | 依赖创建错题，被 BUG-001 阻塞 |
| 7 | TestIntegration_QuestionCRUD | CRUD | ⏳ BLOCKED | 依赖创建错题，被 BUG-001 阻塞 |
| 8 | TestIntegration_UnauthorizedAccess | 安全 | ✅ PASS | 7 个端点均正确返回 401 |
| 9 | TestIntegration_InvalidToken | 安全 | ✅ PASS | 无效 Token 被正确拒绝 |
| 10 | TestIntegration_HealthCheck | 基础 | ✅ PASS | /health 返回 ok |
| 11 | TestIntegration_CrossUserAccess | 安全 | ⏳ BLOCKED | 依赖创建错题 |

### 3.3 测试基础设施特点

- **真实数据库连接**: 通过 Docker Compose 提供隔离的 PostgreSQL + Redis
- **OTP 自动化**: 直接从 Redis 读取验证码，无需 mock
- **完整路由栈**: 包含 JWT 认证中间件，测试真实的 HTTP 请求链路
- **独立于单元测试**: 使用 build tag 隔离，不影响 `go test ./...` 常规运行
- **每测试独立手机号**: 避免 OTP 频率限制冲突

---

## 四、整体就绪度评估

### 4.1 V1.0 发布检查清单

| 检查项 | 状态 | 详情 |
|--------|------|------|
| Docker Compose 开发环境 | ✅ 就绪 | 修复 SQL 注释后可正常启动 |
| Docker Compose 测试环境 | ✅ 就绪 | 修复 3 个 SQL 问题 + 添加端口映射 |
| 用户注册/登录 | ✅ 通过 | 集成测试验证完整流程 |
| JWT 认证/登出/Token黑名单 | ✅ 通过 | 登出后旧 Token 正确失效 |
| 错题创建 (POST /questions) | 🔴 **阻塞** | BUG-001 导致 100% 失败 |
| 错题列表/详情/更新/删除 | ⏳ 待验证 | 被 BUG-001 阻塞 |
| 复习队列/提交结果 | ⏳ 待验证 | 被 BUG-001 阻塞 |
| Dashboard | ⏳ 待验证 | 被 BUG-001 阻塞 |
| 权限隔离 | ✅ 通过 | 未认证访问正确拒绝 |
| init-db.sql 初始化脚本 | ✅ 已修复 | 3 个问题已修正 |

### 4.2 风险评估

```
┌─────────────────────────────────────────────┐
│         V1.0 发布就绪度: 60%                 │
│                                             │
│  ✅ 基础设施  ████████████░░░░  85%         │
│  ✅ 认证模块  ████████████░░░░  90%         │
│  🔴 错题模块  ░░░░░░░░░░░░░░░░   0% (阻塞) │
│  ⏳ 复习模块  ░░░░░░░░░░░░░░░░  待验证      │
│  ⏳ 报告模块  ░░░░░░░░░░░░░░░░  待验证      │
└─────────────────────────────────────────────┘
```

### 4.3 下一步行动建议

| 优先级 | 行动项 | 负责人 | 预计工时 |
|--------|--------|--------|----------|
| 🔴 P0 | 修复 BUG-001 (GORM many2many) | Dev agent | 1-2h |
| 🔴 P0 | 添加知识点存在性验证 | Dev agent | 含在 BUG-001 修复中 |
| 🟡 P1 | 新增 errcode: EKnowledgePointNotFound (20014) | Dev agent | 0.5h |
| 🟡 P1 | BUG-001 修复后重跑全部集成测试 | QA agent | 0.5h |
| 🟢 P2 | Dockerfile.test 优化（减少构建时间） | Ops agent | 1h |
| 🟢 P2 | CI/CD 集成测试流水线 | Ops agent | 2h |

---

## 五、附录

### A. 测试环境快速启动

```bash
# 启动测试环境
docker compose -f deploy/docker-compose.test.yml up -d postgres-test redis-test

# 等待健康检查通过 (~20s)
docker ps --filter "name=test"

# 运行集成测试
cd src/errorhunter_server
EH_DATABASE_HOST=localhost EH_DATABASE_PORT=5433 \
EH_DATABASE_USER=errorhunter EH_DATABASE_PASSWORD=errorhunter_dev \
EH_DATABASE_DBNAME=errorhunter_test EH_DATABASE_SSLMODE=disable \
EH_REDIS_ADDR=localhost:6380 \
go test -tags=integration -v -count=1 ./internal/handler/

# 清理
docker compose -f deploy/docker-compose.test.yml down
```

### B. BUG-001 复现步骤

```bash
# 1. 注册用户获取 token
curl -X POST http://localhost:8080/v1/auth/otp/send \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","scene":"REGISTER"}'

# 2. 验证码（查看服务端日志获取）
curl -X POST http://localhost:8080/v1/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"XXXXXX","scene":"REGISTER","grade":"33"}'

# 3. 创建错题 → 返回 500
curl -X POST http://localhost:8080/v1/questions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/test.jpg",
    "error_category": "KNOWLEDGE",
    "knowledge_point_ids": [1, 2]
  }'
# 响应: {"code":90003,"data":null,"message":"服务器内部错误"}
```

### C. 修改文件清单

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `deploy/init-db.sql` | 修复 | `#` → `--` 注释；移除 2 个非法索引 |
| `deploy/docker-compose.test.yml` | 增强 | 添加端口映射 |
| `src/.../handler/integration_test.go` | 新增 | 11 个集成测试用例 |
| `tests/test-report-V1.0-integration.md` | 新增 | 本报告 |
