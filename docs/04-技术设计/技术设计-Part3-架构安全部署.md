# 错题猎手（ErrorHunter）— 技术设计 Part 3：架构·安全·部署

```
┌──────────────────────────────────────────────────┐
│                  文档信息                          │
├──────────────┬───────────────────────────────────┤
│ 文档名称      │ 技术设计-Part3-架构安全部署         │
│ 所属产品      │ 错题猎手（ErrorHunter）             │
│ 文档版本      │ V1.0                              │
│ 编写人        │ @Arch（李工）                       │
│ 创建日期      │ 2026-06-17                        │
│ 上游依赖      │ PRD V1.1 / 技术架构概要 / 竞品报告   │
│ 状态          │ 待评审                             │
└──────────────┴───────────────────────────────────┘
```

---

## 目录

- [第1章：技术选型详细论证](#第1章技术选型详细论证)
- [第2章：系统架构详细设计](#第2章系统架构详细设计)
- [第3章：安全设计](#第3章安全设计)
- [第4章：性能设计](#第4章性能设计)
- [第5章：部署架构](#第5章部署架构)
- [第6章：技术风险与Sprint计划](#第6章技术风险与sprint计划)

---

## 第1章：技术选型详细论证

### 1.1 Go vs Java 后端选型对比

| 维度 | Go (1.22+) | Java (21 + Spring Boot 3) | 权重 | 评判 |
|------|-----------|--------------------------|------|------|
| **并发性能** | goroutine 轻量级协程，单机轻松承载 10w+ 并发连接；内存占用 ~2KB/goroutine | 虚拟线程(Loom)改善显著，但 JVM 基础内存开销仍 ~200MB+ | ⭐⭐⭐ | Go ✅ |
| **启动速度** | 编译为二进制，冷启动 < 100ms | JVM 预热 3-10s（GraalVM Native 可降至 < 1s，但生态兼容有坑） | ⭐⭐ | Go ✅ |
| **开发效率** | 语法简洁，标准库强大；ORM(GORM)够用但不及 MyBatis-Plus 丰富 | Spring 全家桶开箱即用，CRUD 脚手架成熟 | ⭐⭐⭐ | Java ✅ |
| **生态/中间件** | gin/echo/fiber + GORM + go-redis + zap，MVP 足够 | Spring Cloud Alibaba 一站式微服务方案 | ⭐⭐ | MVP 阶段平手 |
| **团队能力** | 当前团队 2 人有 Go 项目经验，1 人纯 Java | 3 人均有 Java 经验 | ⭐⭐ | Go 需学习成本 |
| **运维复杂度** | 单二进制部署，Docker 镜像 ~15MB | JRE 镜像 ~300MB+，GC 调优门槛 | ⭐⭐ | Go ✅ |
| **长期扩展** | 天然适合微服务拆分；gRPC 一等公民 | Spring Cloud 体系完善但重 | ⭐ | MVP 不拆微服务，平手 |
| **社区/招聘** | Go 在国内云原生/教育科技赛道人才增长快 | Java 人才池最大 | ⭐ | 平手 |

#### 🏁 明确结论：**选择 Go**

**核心理由：**

1. **MVP 是单体服务**——Go 的编译型 + 低内存特性意味着一台 2C4G 服务器即可支撑万级 DAU，节省早期云资源成本约 40%
2. **复习调度引擎是 CPU 密集 + 定时任务场景**——goroutine + channel 天然适配，无需引入额外消息队列框架
3. **竞品窗口期紧迫**（参见竞品报告 §7.2）——更快的部署迭代 = 更多试错机会
4. **团队学习成本可控**——Go 语法简单，2 周上手，1 个月达到生产水平；PRD 中 MVP 预计 14 周，时间充裕
5. **V1.1 AI 模块预留**——AI 推理服务通常用 Python，Go 通过 gRPC/HTTP 调用无碍，Java 并无优势

**MVP 妥协点：** ORM 选用 GORM，复杂查询手写 SQL；暂不引入微服务框架，单体模块化（见 §2.3）。

---

### 1.2 Flutter 版本及关键依赖包选型

| 依赖包 | 版本 | 用途 | 选型理由 | MVP/V1.1 |
|--------|------|------|---------|----------|
| **Flutter SDK** | 3.24.x (stable) | 跨端框架 | 最新稳定版，Impeller 渲染引擎默认启用 | MVP |
| **dio** | ^5.5.0 | HTTP 客户端 | 拦截器链、取消令牌、FormData 上传、重试机制完善 | MVP |
| **flutter_bloc** | ^8.1.6 | 状态管理 | BLoC/Cubit 模式，业务逻辑与 UI 分离，测试友好 | MVP |
| **get_it** | ^7.7.0 | 依赖注入 | 轻量级服务定位器，配合 Injectable 代码生成 | MVP |
| **sqflite** | ^2.3.3 | 本地 SQLite | 离线存储核心依赖，支持事务、批量操作 | MVP |
| **cached_network_image** | ^3.4.1 | 图片缓存 | OSS 签名 URL 场景下自定义 cacheManager key | MVP |
| **image_picker** | ^1.1.2 | 拍照/相册 | 官方维护，HEIC 自动转 JPG | MVP |
| **image_cropper** | ^8.0.2 | 图片裁剪 | FR-200-7 手动拖拽四角裁剪框 | MVP |
| **flutter_image_compress** | ^2.3.0 | 客户端压缩 | 上传前压缩至 ≤500KB | MVP |
| **go_router** | ^14.2.0 | 声明式路由 | 深度链接、嵌套路由、路由守卫 | MVP |
| **shared_preferences** | ^2.3.2 | KV 存储 | Token/用户偏好/同步状态等轻量持久化 | MVP |
| **firebase_analytics** | ^11.2.0 | 数据埋点 | GR-004 要求 MVP 第一天启用 | MVP |
| **flutter_local_notifications** | ^17.2.1 | 本地推送 | FR-402 复习提醒 | MVP |
| **pdf** | ^3.11.0 | PDF 生成 | FR-203 客户端本地生成 PDF | MVP |
| **fl_chart** | ^0.69.0 | 图表组件 | FR-600 饼图/折线图/日历热力图 | MVP |
| **rxdart** | ^0.28.0 | 响应式扩展 | 防抖搜索、合并流 | MVP |
| **connectivity_plus** | ^6.0.5 | 网络状态监听 | GR-002 离线检测 + 联网自动触发同步 | MVP |
| **device_info_plus** | ^10.1.2 | 设备信息 | 多设备登录管理需要 device_id | MVP |
| **crypto** | ^3.0.3 | 哈希工具 | 密码 bcrypt、签名验证 | MVP |
| **intl** | ^0.19.0 | 国际化/格式化 | 日期格式化、数字格式化 | MVP |
| **jpush_flutter** | TBD | 远程推送 | V1.1 接入 | V1.1 |
| **webview_flutter** | TBD | H5 容器 | V1.1 数学公式渲染备选 | V1.1 |

> **版本锁定策略：** `pubspec.yaml` 中使用精确版本号，CI 中运行 `flutter pub get --enforce-lockfile` 确保构建一致性。

---

### 1.3 PostgreSQL vs MySQL 对比

| 维度 | PostgreSQL 16 | MySQL 8.0 | 评判 |
|------|--------------|-----------|------|
| **JSON 支持** | JSONB 二进制存储，GIN 索引，jsonpath 查询 | JSON 文本存储，仅虚拟列索引 | PG ✅ |
| **数组类型** | 原生 TEXT[]/INT[]，ANY/ALL/unnest | 不支持原生数组 | PG ✅ |
| **部分索引** | WHERE deleted_at IS NULL 条件索引 | 不支持 | PG ✅ |
| **全文搜索** | tsvector/tsquery + pg_jieba 中文分词 | FULLTEXT 中文支持弱 | PG ✅ |
| **扩展性** | pg_trgm/pg_cron/timescaledb/pgvector | 插件生态较弱 | PG ✅ |
| **ACID 严格性** | MVCC + 真正 SERIALIZABLE | next-key lock 伪串行化 | PG ✅ |
| **运维熟悉度** | 团队经验较少 | 团队更熟悉 | MySQL ✅ |
| **云服务支持** | 阿里云 RDS PG 全功能托管 | 阿里云 RDS MySQL 全功能托管 | 平手 |

#### 🏁 明确结论：**选择 PostgreSQL 16**

**核心理由：** PRD 数据模型大量使用 JSON（solution_steps/custom_tags/keywords），PG 的 JSONB + GIN 索引是刚需；部分索引直接命中需求；V1.1 可能需要 pgvector 向量检索。

---

### 1.4 Redis 使用场景规划

| 场景 | Key 格式 | 数据结构 | TTL | MVP |
|------|---------|---------|-----|-----|
| JWT 黑名单 | `jwt:blacklist:{jti}` | STRING | Token剩余有效期 | MVP |
| 验证码 | `sms:code:{phone}` | STRING | 5min | MVP |
| 验证码发送计数 | `sms:daily:{phone}:{date}` | STRING | 当日剩余 | MVP |
| 验证码错误计数 | `sms:error:{phone}` | STRING | 30min | MVP |
| API 限流 | `ratelimit:user:{uid}` | STRING | 滑动窗口 | MVP |
| Dashboard 缓存 | `dashboard:{uid}:{date}` | HASH | 到次日00:00 | MVP |
| 今日待复习数 | `review:today_count:{uid}` | STRING | 1h | MVP |
| 今日待复习列表 | `review:today_list:{uid}` | SORTED SET | 到次日00:00 | MVP |
| 用户会话 | `session:{uid}:{device_id}` | HASH | 30d | MVP |
| 知识点树缓存 | `knowledge:tree:{stage}:{ver}` | STRING(JSON) | 24h | MVP |
| OCR 结果缓存 | `ocr:cache:{image_hash}` | STRING | 7d | MVP |
| 周报生成锁 | `lock:weekly_report:{week}` | STRING | 1h | MVP |
| 延迟队列(软删除) | `queue:soft_delete` | SORTED SET | score=删除时间戳 | MVP |
| 复习提醒队列 | `queue:review_reminder` | SORTED SET | score=提醒时间戳 | MVP |

**Redis 实例规划（MVP）：** 单实例 2C4G，maxmemory-policy=allkeys-lru，AOF+RDB 双持久化。

---

### 1.5 阿里云 OSS 配置

#### Bucket 设计

| Bucket | 用途 | ACL | 地域 |
|--------|------|-----|------|
| `errorhunter-images-prod` | 错题原始图片 | private | cn-hangzhou |
| `errorhunter-thumbs-prod` | 缩略图(CDN回源) | private | cn-hangzhou |
| `errorhunter-assets-prod` | APP静态资源 | public-read | cn-hangzhou |

#### 目录结构

```
errorhunter-images-prod/
├── {user_id}/
│   ├── questions/
│   │   ├── {question_id}_orig.jpg
│   │   └── {question_id}_crop.jpg
│   ├── avatars/
│   └── exports/  (7天后自动清理)
```

#### 生命周期规则

| 规则 | 动作 | 说明 |
|------|------|------|
| 缩略图自动生成 | PUT→IMM处理300px宽 | CDN分发 |
| 导出文件过期 | 7天后删除 | PDF不持久化 |
| 软删除图片清理 | 定时DeleteObject | FR-202-8 |
| 历史版本保留 | 版本控制常驻 | 误删7天可恢复 |

#### CDN 配置

| 项目 | 配置 |
|------|------|
| 加速域名 | img.errorhunter.com |
| 缓存策略 | 缩略图30天；原图签名URL不经CDN |
| HTTPS | 强制HTTPS |
| 防盗链 | Referer白名单 *.errorhunter.com |

> **MVP vs V1.1：** MVP缩略图走CDN，原图走OSS签名直连。V1.1评估原图上CDN。

---

### 1.6 Firebase Analytics 集成方案

#### 事件定义（GR-004 落地）

| 事件名 | 参数 | 触发时机 | 对应GR-004 |
|--------|------|---------|-----------|
| sign_up_complete | grade, platform | 注册成功 | GR-004-2 |
| first_question_added | ocr_used(bool) | 首次录入 | GR-004-2 |
| first_review_completed | question_count | 首次完成复习 | GR-004-2 |
| first_question_mastered | review_rounds | 首次消灭 | GR-004-2 |
| app_opened | source | 每日首次打开 | GR-004-3 |
| daily_review_completed | count, duration_sec | 每日复习完成 | GR-004-3 |
| pdf_exported | question_count, time_range | PDF导出 | GR-004-4 |
| error_category_changed | from_cat, to_cat | 错因修改 | GR-004-4 |
| ocr_failed | error_type | OCR失败 | GR-004-4 |
| offline_question_added | — | 离线录入 | GR-004-4 |
| sync_triggered | pending_count, result | 联网同步 | 补充 |

#### 隐私合规

- ❌ 禁止上报：手机号、昵称、题目图片、OCR文字、IP地址
- ✅ 允许上报：Firebase内部ID、年级、平台、行为事件
- 首次启动展示隐私弹窗，同意后才初始化SDK
- iOS遵守ATT框架

---

## 第2章：系统架构详细设计

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                          客 户 端 层                                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Flutter App (iOS + Android)                      │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────────┐ │  │
│  │  │ BLoC     │ │ Dio HTTP │ │ SQLite   │ │ Firebase        │ │  │
│  │  │ State    │ │ Client   │ │ Offline  │ │ Analytics       │ │  │
│  │  │ Mgmt     │ │ +Retry   │ │ Store    │ │                 │ │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────────────┘ │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                             │ HTTPS (JWT)                            │
└─────────────────────────────┼───────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        API Gateway 层                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Nginx / Caddy                               │  │
│  │  • TLS终止(HTTPS)  • 请求限流(令牌桶)  • JWT预校验             │  │
│  │  • Gzip/Brotli压缩  • CORS头注入  • 静态资源服务               │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          服 务 层                                    │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Go Monolith (Gin Framework)                       │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────────┐ │  │
│  │  │ Auth     │ │ Question │ │ Review   │ │ Report          │ │  │
│  │  │ Module   │ │ Module   │ │ Engine   │ │ Module          │ │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────────────┘ │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────────────────┐ │  │
│  │  │ OCR      │ │Knowledge │ │ Notification                 │ │  │
│  │  │ Adapter  │ │ Module   │ │ Module (Local Push MVP)      │ │  │
│  │  └──────────┘ └──────────┘ └──────────────────────────────┘ │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  Cross-Cutting Middleware                                │ │  │
│  │  │  Auth | RateLimit | UserIsolation | Logger | Recovery   │ │  │
│  │  └─────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          数 据 层                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ PostgreSQL   │  │    Redis     │  │   Aliyun OSS + CDN       │  │
│  │ 16 (RDS)     │  │   7.x       │  │  错题原图/缩略图/生命周期  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  External: OCR API(百度/腾讯) | SMS(阿里云) | Firebase       │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 各层职责定义

| 层级 | 职责 | 约束 |
|------|------|------|
| **客户端层** | UI渲染、本地状态管理、离线存储、图片预处理、埋点采集 | 不含业务逻辑决策 |
| **API Gateway层** | TLS终止、L7限流、JWT格式预校验、CORS、压缩 | 不做业务鉴权 |
| **服务层** | 全部业务逻辑、数据校验、权限判定、第三方编排、定时任务 | 单体模块化，interface调用 |
| **数据层** | 持久化、缓存、对象存储、外部API代理 | DB不暴露给客户端 |

### 2.3 模块划分与职责边界表

| 模块 | 包路径 | 核心职责 | 对外接口 | 依赖模块 | MVP |
|------|--------|---------|---------|---------|-----|
| **Auth** | `internal/module/auth` | 注册/登录/JWT/设备管理/Token刷新/注销 | `AuthService` interface | Redis, SMS | MVP |
| **Question** | `internal/module/question` | 错题CRUD/软删除/回收站/图片关联 | `QuestionService` interface | Auth, OSS, Knowledge | MVP |
| **Review** | `internal/module/review` | 艾宾浩斯调度/自评/消灭判定/复活检测 | `ReviewService` interface | Auth, Question | MVP |
| **Report** | `internal/module/report` | Dashboard聚合/周报/学情统计/打卡 | `ReportService` interface | Auth, Question, Review, Redis | MVP |
| **Knowledge** | `internal/module/knowledge` | 知识点树/AI关键词匹配/版本管理 | `KnowledgeService` interface | — | MVP |
| **Notification** | `internal/module/notification` | 复习提醒/召回通知/推送token管理 | `NotificationService` interface | Auth, Review | MVP |
| **OCR** | `internal/module/ocr` | OCR适配/去手写/超时降级/结果缓存 | `OCRAdapter` interface | Redis | MVP |

### 2.4 模块间依赖关系图

```
                    ┌──────────────┐
                    │   Auth       │ ◄──── 所有模块依赖（用户身份）
                    └──────┬───────┘
                           │
              ┌────────────┼────────────────┐
              ▼            ▼                ▼
      ┌──────────────┐ ┌────────────┐ ┌──────────────┐
      │  Question    │ │  Knowledge │ │ Notification │
      └──────┬───────┘ └─────┬──────┘ └──────┬───────┘
             │               │                │
             ▼               │                │
      ┌──────────────┐       │                │
      │   Review     │◄──────┘                │
      └──────┬───────┘                        │
             │                                │
             ▼                                ▼
      ┌──────────────┐                 ┌────────────┐
      │   Report     │◄────────────────│   Redis    │
      └──────────────┘                 └────────────┘
      ┌──────────────┐
      │     OCR      │ (独立适配器，被Question调用)
      └──────────────┘
```

**依赖原则：** 单向依赖禁止循环；Go interface解耦；Auth是基础设施；OCR通过interface隔离。

### 2.5 同步/异步通信边界

| 通信方式 | 场景 | MVP |
|---------|------|-----|
| 同步HTTP | 所有客户端→服务端API | MVP |
| 进程内goroutine | Dashboard离线计算、周报生成 | MVP |
| Redis Sorted Set延迟队列 | 软删除清理、复习提醒 | MVP |
| Ticker goroutine | 每日00:00复习调度刷新 | MVP |
| gRPC | Go↔Python AI服务 | V1.1 |
| 消息队列 | 跨服务异步事件 | V2.0 |

> **MVP原则：** 能用goroutine+Redis解决的，不上消息队列。

### 2.6 第三方服务集成架构

```
Go Service Layer
├── OCR Adapter (interface) → 百度/腾讯 OCR REST API
├── SMS Adapter (interface) → 阿里云 SMS REST API
├── OSS Adapter (interface) → 阿里云 OSS SDK + SignURL
├── Firebase Analytics SDK (客户端集成)
└── 极光/个推 Push SDK (V1.1)
```

**适配器模式要点：** interface+具体实现；配置驱动切换；统一错误码映射；超时+重试(MVP)，V1.1加熔断。

---

## 第3章：安全设计

### 3.1 JWT 认证流程

#### Token 体系

| Token类型 | 有效期 | 存储位置 | 用途 |
|-----------|--------|---------|------|
| Access Token | 2小时 | 客户端内存+SharedPreferences | API鉴权 |
| Refresh Token | 30天 | 客户端SecureStorage | 静默续期 |

#### 流程图

```
Client                              Server             Redis
  │ POST /auth/login                   │                 │
  │ {phone,code,device_id,device_name} │                 │
  │───────────────────────────────────▶│ 验证验证码       │
  │                                    │ 检查设备数<=3    │
  │                                    │ 生成token对     │
  │                                    │────────────────▶│ SET session:{uid}:{did}
  │ {access_token, refresh_token}      │                 │
  │◀───────────────────────────────────│                 │
  │ GET /questions (Bearer token)      │                 │
  │───────────────────────────────────▶│ 解析JWT         │
  │                                    │ 检查黑名单─────▶│ GET jwt:blacklist:{jti}
  │                                    │ 校验user_id隔离 │
  │ 200 {data}                         │                 │
  │◀───────────────────────────────────│                 │
  │ POST /auth/logout                  │                 │
  │───────────────────────────────────▶│ token加黑名单──▶│ SET jwt:blacklist:{jti}
  │                                    │ 删session──────▶│ DEL session:{uid}:{did}
  │ 204                                │                 │
  │◀───────────────────────────────────│                 │
```

#### Go 代码实现

```go
// internal/module/auth/jwt.go
package auth

import (
	"context"
	"fmt"
	"time"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Claims struct {
	jwt.RegisteredClaims
	UserID   int64  `json:"uid"`
	DeviceID string `json:"did"`
	Grade    int    `json:"grade"`
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

const (
	accessTokenTTL  = 2 * time.Hour
	refreshTokenTTL = 30 * 24 * time.Hour
)

func (s *AuthService) GenerateTokenPair(ctx context.Context, userID int64, deviceID string, grade int) (*TokenPair, error) {
	now := time.Now()
	jti := uuid.New().String()
	accessClaims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			ID: jti, Subject: fmt.Sprintf("%d", userID),
			IssuedAt: jwt.NewNumericDate(now), ExpiresAt: jwt.NewNumericDate(now.Add(accessTokenTTL)),
			Issuer: "errorhunter",
		},
		UserID: userID, DeviceID: deviceID, Grade: grade,
	}
	accessToken, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims).SignedString([]byte(s.cfg.JWTSecret))

	refreshJTI := uuid.New().String()
	refreshClaims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			ID: refreshJTI, Subject: fmt.Sprintf("%d", userID),
			IssuedAt: jwt.NewNumericDate(now), ExpiresAt: jwt.NewNumericDate(now.Add(refreshTokenTTL)),
			Issuer: "errorhunter",
		},
		UserID: userID, DeviceID: deviceID,
	}
	refreshToken, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims).SignedString([]byte(s.cfg.JWTRefreshSecret))

	return &TokenPair{AccessToken: accessToken, RefreshToken: refreshToken, ExpiresIn: int64(accessTokenTTL.Seconds())}, nil
}

func (s *AuthService) ValidateAccessToken(ctx context.Context, tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(s.cfg.JWTSecret), nil
	})
	if err != nil { return nil, err }
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid { return nil, fmt.Errorf("invalid claims") }

	// 检查黑名单（主动失效/踢设备）
	exists, _ := s.redis.Exists(ctx, fmt.Sprintf("jwt:blacklist:%s", claims.ID)).Result()
	if exists > 0 { return nil, fmt.Errorf("token revoked") }
	return claims, nil
}

func (s *AuthService) RevokeToken(ctx context.Context, jti string, remainingTTL time.Duration) error {
	return s.redis.Set(ctx, fmt.Sprintf("jwt:blacklist:%s", jti), "1", remainingTTL).Err()
}
```

### 3.2 多设备登录管理（FR-001-5/6）

规则：最多3台设备，第4台踢最早登录的设备。被踢设备收到401 TOKEN_REVOKED提示重新登录。

```go
// internal/module/auth/device.go
const maxDevicesPerUser = 3

type DeviceSession struct {
	DeviceID   string    `json:"device_id"`
	DeviceName string    `json:"device_name"`
	JTI        string    `json:"jti"`
	LoginAt    time.Time `json:"login_at"`
	Platform   string    `json:"platform"`
}

func (s *AuthService) RegisterDevice(ctx context.Context, userID int64, session DeviceSession) ([]string, error) {
	prefix := fmt.Sprintf("session:%d:", userID)
	keys, _ := s.redis.Keys(ctx, prefix+"*").Result()

	type entry struct { key string; session DeviceSession }
	var entries []entry
	for _, key := range keys {
		data, err := s.redis.Get(ctx, key).Bytes()
		if err != nil { continue }
		var ds DeviceSession
		if json.Unmarshal(data, &ds) != nil { continue }
		entries = append(entries, entry{key: key, session: ds})
	}
	// 按登录时间升序（最早的在前）
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].session.LoginAt.Before(entries[j].session.LoginAt)
	})

	var evictedJTIs []string
	for len(entries) >= maxDevicesPerUser {
		victim := entries[0]; entries = entries[1:]
		remainingTTL := time.Until(victim.session.LoginAt.Add(refreshTokenTTL))
		if remainingTTL > 0 { _ = s.RevokeToken(ctx, victim.session.JTI, remainingTTL) }
		_ = s.redis.Del(ctx, victim.key).Err()
		evictedJTIs = append(evictedJTIs, victim.session.JTI)
	}

	sessionKey := fmt.Sprintf("session:%d:%s", userID, session.DeviceID)
	data, _ := json.Marshal(session)
	s.redis.Set(ctx, sessionKey, data, refreshTokenTTL)
	return evictedJTIs, nil
}
```

### 3.3 API 限流策略

| 维度 | 限制 | 算法 | 适用接口 |
|------|------|------|---------|
| 全局IP | 100 req/s/IP | 滑动窗口 | 所有接口 |
| 用户级通用 | 30 req/s/user | 令牌桶 | 除上传外所有接口 |
| 短信验证码 | 1 req/60s/phone | 固定窗口 | POST /auth/sms-code |
| 登录 | 5 req/min/phone | 固定窗口 | POST /auth/login |
| 图片上传 | 10 req/min/user | 令牌桶 | POST /questions/image |
| OCR识别 | 20 req/min/user | 令牌桶 | POST /ocr/recognize |

Go中间件使用Redis Lua脚本实现原子性令牌桶。Redis故障时放行避免阻断。

### 3.4 图片签名URL方案

- 仅服务端生成OSS预签名URL，有效期30分钟（NFR-001-4）
- 列表接口批量签发减少N+1 RTT
- 客户端缓存需记录过期时间，过期前主动刷新

### 3.5 用户数据隔离

中间件层从JWT提取user_id注入context；URL参数中若含user_id则校验一致性；Service层所有Query强制WHERE user_id=?（纵深防御）。

### 3.6 未成年人数据保护合规

| 要求 | 实现措施 | 对应法规 |
|------|---------|---------|
| 家长知情同意 | 注册勾选+记录时间戳 | 个人信息保护法 S31 |
| 最小必要原则 | 仅采集手机号+年级+昵称 | 个人信息保护法 S6 |
| 无广告 | MVP不接入广告SDK | 未成年人保护法 S74 |
| 数据删除权 | 注销后7天内全删含OSS | 个人信息保护法 S47 |
| 隐私政策 | 首次启动弹窗同意 | APP违规认定方法 |
| 数据不出境 | 全部cn-hangzhou | 数据安全法 S31 |
| 加密传输 | 全链路HTTPS | 网络安全法 S21 |

### 3.7 SQL注入/XSS防护

SQL注入：GORM全程参数化；手写SQL用占位符；binding tag校验；最小权限DB账号；WAF(V1.1)。
XSS：Content-Type application/json；JSON自动转义；CSP头；bluemonday清洗用户输入。

### 3.8 HTTPS + 证书管理

TLS 1.2+；阿里云免费SSL证书；HSTS头；Nginx 301重定向；blackbox_exporter监控证书到期(提前30天告警)；私钥存KMS不落盘。

---

## 第4章：性能设计

### 4.1 Redis 缓存策略

#### 缓存全景表

| 缓存对象 | Key | TTL | 更新策略 | 穿透防护 | 击穿防护 | 雪崩防护 |
|---------|-----|-----|---------|---------|---------|---------|
| Dashboard统计 | dashboard:{uid}:{date} | 到次日00:00 | 凌晨定时写入 | 空值缓存5min | singleflight | TTL随机偏移+-10% |
| 今日待复习数 | review:today_count:{uid} | 1h | 复习/录入时主动失效 | - | singleflight | TTL随机偏移 |
| 今日待复习列表 | review:today_list:{uid} | 到次日00:00 | 复习/录入时主动失效 | 空列表缓存5min | singleflight | - |
| 知识点树 | knowledge:tree:{stage}:{ver} | 24h | 教研更新后DEL | DB回填 | singleflight | TTL随机偏移 |
| OCR结果 | ocr:cache:{image_md5} | 7d | 首次识别写入 | 失败也缓存1h | - | - |
| 用户信息 | user:info:{uid} | 30min | 修改资料时DEL | 空值缓存5min | singleflight | TTL随机偏移 |

#### 防击穿实现（singleflight）

```go
var sf singleflight.Group

func GetOrLoad[T any](ctx context.Context, key string, ttl time.Duration,
	loadFn func(ctx context.Context) (T, error),
	getter func(ctx context.Context, key string) (T, bool),
	setter func(ctx context.Context, key string, val T, ttl time.Duration),
) (T, error) {
	if val, ok := getter(ctx, key); ok { return val, nil }
	result, err, _ := sf.Do(key, func() (interface{}, error) {
		if val, ok := getter(ctx, key); ok { return val, nil } // double-check
		val, err := loadFn(ctx)
		if err != nil { var zero T; return zero, err }
		setter(ctx, key, val, ttl)
		return val, nil
	})
	if err != nil { var zero T; return zero, err }
	return result.(T), nil
}
```

**雪崩防护：** jitterTTL在base上添加+-10%随机偏移。

### 4.2 数据库查询优化

#### 慢查询监控

```yaml
log_min_duration_statement = 200    # >200ms记录日志
auto_explain.log_min_duration = 500 # >500ms记录执行计划
auto_explain.log_analyze = on
```

#### 索引策略

```sql
CREATE INDEX idx_questions_user_status ON questions(user_id, status);
CREATE INDEX idx_questions_user_review ON questions(user_id, next_review_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_questions_user_category ON questions(user_id, error_category);
CREATE INDEX idx_questions_user_created ON questions(user_id, created_at DESC);
CREATE INDEX idx_review_user_date ON review_records(user_id, reviewed_at DESC);
CREATE INDEX idx_review_question ON review_records(question_id);
-- Dashboard覆盖索引
CREATE INDEX idx_questions_dashboard_covering ON questions(user_id, status, error_category, created_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_qk_question ON question_knowledge(question_id);
CREATE INDEX idx_qk_knowledge ON question_knowledge(knowledge_point_id);
```

EXPLAIN规范：所有新查询上线前必须EXPLAIN(ANALYZE,BUFFERS)；目标Seq Scan->Index Scan。

### 4.3 图片处理链路

```
手机相机(~5MB) -> Flutter Compress(<=500KB) -> Go API Upload+MD5 -> OSS+IMM -> CDN缩略图
```

| 环节 | 规格 |
|------|------|
| 客户端压缩 | JPEG q=80, maxW=1920px, <=500KB |
| 上传 | Multipart+MD5校验 |
| OSS路径 | {user_id}/questions/{qid}_crop.jpg |
| 缩略图 | IMM生成300px宽，异步触发 |
| CDN | 仅缩略图走CDN |
| HEIC | 客户端转JPEG |
| 去手写 | OCR API侧处理，效果不佳保留原图标注 |

### 4.4 API响应优化（P99<=500ms保障）

| 措施 | 说明 |
|------|------|
| 连接池 | PG:maxOpen=20,maxIdle=10; Redis:poolSize=20 |
| 查询精简 | 列表只SELECT必要字段 |
| 分页游标 | id>last_id LIMIT 20代替OFFSET |
| 批量签名 | 列表一次签发N个图片URL |
| ETag+304 | 读多写少接口Response Cache |
| 超时控制 | OCR 5s, OSS 10s独立timeout |
| P99监控 | Prometheus histogram按接口分组 |

```go
// 连接池配置
db.SetMaxOpenConns(20)
db.SetMaxIdleConns(10)
db.SetConnMaxLifetime(30 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)
```

### 4.5 首页Dashboard加载优化

四重策略组合：

1. **离线预计算（FR-600-2）**：每天00:00定时任务聚合统计数据写入Redis
2. **Redis缓存**：API优先读缓存(TTL到次日00:00)，miss回源
3. **客户端懒加载**：首屏(<200ms)->二屏(骨架屏异步)->三屏(视口触发)
4. **增量更新**：操作成功后客户端乐观更新，下次与服务端merge

```go
func (s *ReportService) ComputeDailyDashboard(ctx context.Context) error {
	date := time.Now().Format("2006-01-02")
	userIDs, _ := s.repo.GetActiveUserIDs(ctx, 30)
	for _, uid := range userIDs {
		summary, err := s.aggregateDashboard(ctx, uid)
		if err != nil { continue }
		key := fmt.Sprintf("dashboard:%d:%s", uid, date)
		data, _ := json.Marshal(summary)
		ttl := time.Until(time.Now().AddDate(0, 0, 1).Truncate(24 * time.Hour))
		s.redis.Set(ctx, key, data, ttl)
	}
	return nil
}
```

---

## 第5章：部署架构

### 5.1 MVP 服务器规格与数量

| 资源 | 规格 | 数量 | 月费(估) | 说明 |
|------|------|------|---------|------|
| ECS应用服务器 | 2C4G ecs.c7.large | 1 | ~200元 | Go单体+Nginx |
| RDS PostgreSQL | 2C4G pg.n2.small.2c | 1 | ~300元 | 高可用版 |
| Redis | 2G 标准版双副本 | 1 | ~150元 | 缓存+队列+会话 |
| OSS | 按量付费 | - | ~50元起 | 预估100GB |
| CDN | 按流量计费 | - | ~30元起 | 缩略图加速 |
| SLB | 共享型 | 1 | ~30元 | 便于后续扩容 |
| 域名+SSL | .com+免费证书 | 1 | ~60元/年 | api.errorhunter.com |
| **合计** | | | **~760元/月** | |

扩容触发：CPU>70%持续15min->升4C8G；RDS连接>80%->升级；Redis内存>80%->扩至4G。

### 5.2 Docker容器化方案

#### docker-compose.yml

```yaml
version: "3.9"
services:
  app:
    build: { context: ., dockerfile: deploy/docker/Dockerfile }
    ports: ["8080:8080"]
    environment:
      - ENV=production
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=errorhunter
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_ADDR=redis:6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
      - OSS_BUCKET=errorhunter-images-prod
      - OSS_ENDPOINT=oss-cn-hangzhou-internal.aliyuncs.com
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/api/v1/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  postgres:
    image: postgres:16-alpine
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./deploy/sql/init.sql:/docker-entrypoint-initdb.d/01-init.sql
    environment:
      POSTGRES_DB: errorhunter
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d errorhunter"]
      interval: 10s
      retries: 5
    command: >
      postgres -c log_min_duration_statement=200 -c shared_buffers=1GB
      -c effective_cache_size=3GB -c work_mem=16MB -c max_connections=100

  redis:
    image: redis:7-alpine
    command: >
      redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 1gb
      --maxmemory-policy allkeys-lru --appendonly yes
    volumes: [redis_data:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      retries: 5

  migrate:
    build: { context: ., dockerfile: deploy/docker/Dockerfile.migrate }
    environment:
      - DB_HOST=postgres
      - DB_NAME=errorhunter
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
    depends_on: { postgres: { condition: service_healthy } }
    restart: "no"

volumes:
  pg_data:
  redis_data:
```

#### Dockerfile（多阶段构建）

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata wget
COPY --from=builder /server /server
EXPOSE 8080
USER nobody
ENTRYPOINT ["/server"]
```

### 5.3 CI/CD流水线（GitHub Actions）

三阶段流水线：

1. **Quality Gate**: lint(golangci-lint) + unit test(race) + integration test(PG+Redis service container)
2. **Build & Push**: Docker multi-stage build -> ACR(registry.cn-hangzhou.aliyuncs.com)
3. **Deploy**: develop->staging SSH部署; main->production SSH部署; 部署后健康检查验证

触发规则：PR->仅lint+test; merge develop->build+deploy staging; merge main->build+deploy prod。

### 5.4 环境规划

| 环境 | 分支 | 用途 | 基础设施 | 数据 |
|------|------|------|---------|------|
| dev | feature/* | 本地开发调试 | Docker Compose本地 | Seed数据 |
| staging | develop | 集成测试/UAT | 阿里云ECS 2C4G | 脱敏测试数据 |
| prod | main | 生产环境 | 阿里云(见5.1) | 真实用户数据 |

隔离原则：每环境独立DB/Redis/OSS Bucket；环境变量注入配置；密钥走KMS/GitHub Secrets；staging与prod网络隔离。

### 5.5 监控告警体系（Prometheus+Grafana）

| 类别 | 指标 | 告警阈值 | 级别 |
|------|------|---------|------|
| API延迟 | P99 duration | >500ms持续5min | P1 |
| API错误率 | 5xx rate | >1%持续3min | P0 |
| QPS | request rate | >500容量预警 | P2 |
| DB连接池 | active/max | >80%持续5min | P1 |
| Redis内存 | used/max | >80% | P1 |
| Redis命中率 | hits/(hits+misses) | <90%持续10min | P2 |
| 磁盘 | available | <20% | P1 |
| SSL证书 | cert expiry | <30天 | P2 |
| OSS上传失败 | error count | >10/min | P1 |
| OCR超时率 | timeout/request | >5%持续5min | P1 |
| 业务指标 | DAU/复习完成率 | 环比降>30% | P2 |

Dashboard四行布局：Overview(QPS/P99/错误率) -> Application(接口延迟/状态码) -> Infrastructure(CPU/Mem/DB/Redis) -> Business(DAU/复习率/OCR)。

### 5.6 日志收集

结构化日志(zap)：level/ts/msg/trace_id/user_id/method/path/status/latency_ms/error。

| 方案 | MVP | V1.1 |
|------|-----|------|
| 文件日志+阿里云SLS | Y | - |
| Loki+Grafana | - | Y |
| ELK Stack | - | 评估 |

### 5.7 备份策略

| 对象 | 频率 | 保留期 | 方式 | RTO |
|------|------|--------|------|-----|
| PostgreSQL | 每日全量+WAL连续增量 | 30天 | RDS自动+跨区域复制cn-shanghai | <1h |
| Redis | RDB每小时+AOF实时 | 7天 | Redis自动备份 | <30min |
| OSS图片 | 版本控制常驻 | 误删7天可恢复 | 版本控制+跨区域复制 | <2h |
| 配置文件 | Git版本控制 | 永久 | GitHub | <10min |

每周备份恢复演练(smoke test+行数校验)。

### 5.8 回滚方案

- **应用回滚**: docker compose pull app:<previous_tag> + up -d + 健康检查
- **DDL迁移失败**: golang-migrate自动down migration (<5min)
- **数据损坏**: PITR (<1h)
- **全量灾难**: 全量备份+WAL回放 (<2h)
- **决策流程**: 新功能异常->Feature Flag关闭; 错误率飙升->版本回滚; 数据不一致->修复脚本/PITR; 全站不可用->紧急回滚+复盘

---

## 第6章：技术风险与 Sprint 计划

### 6.1 技术风险清单

| # | 风险 | 等级 | 影响 | 应对措施 | MVP妥协点 |
|---|------|------|------|---------|-----------|
| R1 | OCR印刷体准确率<98% | 高 | 录入体验差用户流失 | Sprint0 POC对比百度/腾讯；人工编辑兜底；去手写单独评估 | 不达标则保留原图+标注模式 |
| R2 | Go团队学习曲线延迟进度 | 中 | Sprint1-2产出低 | Sprint0训练营+结对编程；Tech Lead Review | 非核心模块延后Sprint2 |
| R3 | 艾宾浩斯调度边界case | 中 | 复习计划错乱 | >=50个单元测试case；灰度发布 | 先上基础5轮，积压/复活微调 |
| R4 | Flutter离线同步数据丢失 | 中 | 用户数据丢失 | 单向上传简化；SQLite WAL；同步状态可视化 | 不做双向同步/冲突解决 |
| R5 | OSS上传慢/超时 | 低 | 录入卡顿 | 客户端压缩<=500KB；超时重试 | MVP不支持断点续传 |
| R6 | Firebase国内可用性 | 中 | 埋点缺失 | 测试连通性；备选Umeng | 不通则切Umeng |
| R7 | PG JSONB查询性能退化 | 低 | Dashboard慢 | GIN索引；VACUUM ANALYZE；监控 | 降级应用层聚合 |
| R8 | 未成年人合规未通过 | 高 | 上架被拒 | 提前法务咨询；隐私政策审核 | - |
| R9 | 竞品快速复制差异化 | 中 | 窗口期缩短 | 加速MVP(14周)；V1.1紧跟AI | - |
| R10 | PDF生成内存溢出 | 低 | APP崩溃 | 上限50题；分批渲染；降采样 | 限制50题 |

### 6.2 Sprint 0-3 技术交付物清单

#### Sprint 0：基础设施搭建（第1-2周）

| # | 交付物 | 负责人 | 验收标准 |
|---|--------|--------|---------|
| S0-1 | Go脚手架(Gin+GORM+zap+config) | Dev | make run健康检查通过 |
| S0-2 | Docker Compose本地环境(PG+Redis) | Ops | docker compose up一键启动 |
| S0-3 | CI/CD流水线(lint+test+build+deploy staging) | Ops | PR自动检查，merge develop自动部署 |
| S0-4 | DDL+Migration工具链 | Dev | make migrate-up创建全部表 |
| S0-5 | Flutter脚手架(BLoC+Dio+Router+SQLite) | Dev | 空壳APP双端编译通过 |
| S0-6 | OCR POC(百度vs腾讯含去手写) | Arch | 选型报告确定供应商 |
| S0-7 | OSS+CDN环境+签名URL POC | Dev | 端到端验证 |
| S0-8 | Go团队培训 | Arch | 全员hands-on完成 |
| S0-9 | 推送服务商选型 | Arch | 选型报告(MVP暂不接入) |
| S0-10 | Firebase SDK集成POC | Dev | Console可见测试事件 |

#### Sprint 1：核心链路打通（第3-6周）

| # | 交付物 | 负责人 | 验收标准 |
|---|--------|--------|---------|
| S1-1 | 注册/登录API+JWT中间件 | Dev | 全流程通过 |
| S1-2 | 多设备登录管理(3台+踢设备) | Dev | 第4台踢第1台+提示 |
| S1-3 | 错题CRUD API(含图片/OSS签名) | Dev | CRUD全流程 |
| S1-4 | 知识点树+AI关键词匹配 | Dev | 题目文字返回TOP3知识点 |
| S1-5 | OCR对接(供应商+超时降级) | Dev | 识别+去手写+5s降级 |
| S1-6 | Flutter录入三步流程UI | Dev | 拍照->裁剪->OCR->保存端到端 |
| S1-7 | 艾宾浩斯调度引擎+单测 | Dev | >=50 case全通过 |
| S1-8 | Flutter离线SQLite+同步UI | Dev | 离线录入->联网上传->状态更新 |
| S1-9 | 限流+数据隔离中间件 | Dev | 429/403正确返回 |
| S1-10 | 结构化日志+SLS接入 | Ops | SLS Console可查 |

#### Sprint 2：复习闭环+学情报告（第7-10周）

| # | 交付物 | 负责人 | 验收标准 |
|---|--------|--------|---------|
| S2-1 | 复习API(自评->调度->消灭) | Dev | 3次完全掌握->MASTERED |
| S2-2 | 复活检测(30->60->90天递进) | Dev | 消灭30天后出现复习列表末尾 |
| S2-3 | Flutter复习卡片UI | Dev | 翻转<=300ms；左滑流畅 |
| S2-4 | Dashboard离线计算+Redis缓存 | Dev | 首页<1s加载 |
| S2-5 | Flutter Dashboard UI(懒加载) | Dev | 首屏<200ms |
| S2-6 | 周报自动生成+分享长图 | Dev | 每周日生成；PNG含二维码 |
| S2-7 | PDF导出(客户端生成) | Dev | <=50题<10s |
| S2-8 | 消灭动画 | Dev | <=2s；可跳过/关闭 |
| S2-9 | 复习提醒本地通知 | Dev | 定时提醒；待复习=0不推 |
| S2-10 | Prometheus+Grafana看板 | Ops | 指标可视化；钉钉告警 |

#### Sprint 3：打磨+测试+上线准备（第11-14周）

| # | 交付物 | 负责人 | 验收标准 |
|---|--------|--------|---------|
| S3-1 | 全链路压测 | QA | 200并发P99<=500ms |
| S3-2 | 安全审计 | QA | 零高危；合规checklist通过 |
| S3-3 | 双端兼容性测试 | QA | iOS14+/Android8+通过率>=95% |
| S3-4 | 离线场景专项测试 | QA | 数据零丢失 |
| S3-5 | Firebase埋点验证 | QA | 控制台数据一致 |
| S3-6 | 生产环境部署 | Ops | HTTPS+健康检查通过 |
| S3-7 | 备份恢复演练 | Ops | 恢复成功RTO<1h |
| S3-8 | 隐私政策法务审核 | PM | 法务签字 |
| S3-9 | 提审材料准备 | PM | 截图/描述/合规就绪 |
| S3-10 | 灰度发布+种子内测 | PM | 50名种子反馈收集 |

### 6.3 每个Sprint的技术依赖和前置条件

```
Sprint 0: 无前置。依赖阿里云账号、OCR商务对接、Apple Developer账号。
Sprint 1: 前置S0-1+S0-4+S0-6+S0-7。依赖OCR Key、短信开通、知识点树JSON。
Sprint 2: 前置S1-1+S1-3+S1-7。依赖教研确认错因文案、UI设计稿。
Sprint 3: 前置S2全部完成。依赖法务审核、App Store预约、种子招募。
```

### 6.4 关键技术POC验证点列表

| # | POC项 | 验证内容 | 负责 | 时间 | 通过标准 | 失败预案 |
|---|--------|---------|------|------|---------|---------|
| POC-1 | OCR印刷体 | 100张样本准确率 | Arch | S0W1 | >=98% | 换供应商 |
| POC-2 | OCR去手写 | 50张带手写试卷 | Arch | S0W1 | 印刷体>=95% | 放弃去手写保留原图标注 |
| POC-3 | OSS签名+CDN | 端到端延迟 | Dev | S0W2 | 缩略图<500ms | 不走CDN直连OSS |
| POC-4 | Flutter离线同步 | 断网50条->联网上传 | Dev | S0W2 | 零丢失顺序正确 | 改手动触发 |
| POC-5 | Firebase国内 | 事件上报成功率 | Dev | S0W2 | >=95%到达 | 切Umeng |
| POC-6 | PDF生成 | 50题含图时间和内存 | Dev | S1W4 | <10s,<300MB | 上限降至20题 |
| POC-7 | 调度边界 | 跨时区/闰年/长假 | Dev | S1W2 | 50case全通过 | 增加人工修正入口 |
| POC-8 | JWT踢设备 | 4台同时->第1台被踢 | Dev | S1W1 | <1s感知 | 下次请求感知 |
| POC-9 | Dashboard性能 | 1000条错题加载 | Dev | S2W2 | <1s含缓存 | 减少首屏组件 |
| POC-10 | 全链路P99 | 200并发混合请求 | QA | S3W1 | <=500ms | 热点加缓存;读写分离 |

---

## 附录：MVP vs V1.1 技术差异速查表

| 技术领域 | MVP (V1.0) | V1.1 |
|---------|-----------|------|
| 后端架构 | Go单体模块化 | 评估微服务拆分 |
| 离线同步 | 单向上传 | 双向同步+冲突解决 |
| 推送 | 本地通知 | 极光/个推远程推送 |
| OCR | 单源 | 主备双源自动切换 |
| AI分析 | 关键词匹配推荐 | LLM深度错因+举一反三 |
| 数学公式 | 纯文本 | KaTeX/MathJax渲染 |
| 缓存 | Redis单实例 | Redis Cluster(如需) |
| 日志 | 阿里云SLS | Loki+Grafana |
| 监控 | 基础Prometheus | 全链路Trace(Jaeger) |
| 数据库 | PG单实例 | PG主从+读写分离 |
| API序列化 | JSON | 评估Protobuf |
| 熔断降级 | 超时+重试 | Sentinel/Hystrix-go |
| Feature Flag | 硬编码 | Unleash/自研 |
| 多学科 | 仅数学 | +语文、英语 |
| 激励体系 | 打卡+消灭动画 | 成就徽章+宠物养成 |

---

**文档签署：**

| 角色 | 姓名 | 日期 | 状态 |
|------|------|------|------|
| 架构师 | @Arch（李工） | 2026-06-17 | 已签署 |
| 后端负责人 | | | 待签署 |
| 前端负责人 | | | 待签署 |
| 运维负责人 | | | 待签署 |
| 测试负责人 | | | 待签署 |
| 产品负责人 | | | 待签署 |
