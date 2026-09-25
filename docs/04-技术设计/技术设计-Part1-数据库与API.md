# 错题猎手 V1.0 — 技术设计文档 Part 1：数据库与API

```
┌──────────────────────────────────────────────────┐
│                  文档信息                          │
├──────────────┬───────────────────────────────────┤
│ 文档名称      │ 技术设计-Part1-数据库与API          │
│ 所属产品      │ 错题猎手（ErrorHunter）V1.0         │
│ 文档版本      │ V1.0                              │
│ 编写人        │ @Arch（李工）                      │
│ 创建日期      │ 2026-06-17                        │
│ 上游输入      │ PRD V1.1 + 竞品分析会议纪要         │
│ 状态         │ 待评审                             │
└──────────────┴───────────────────────────────────┘
```

---

## 修订记录

| 版本 | 日期 | 修改内容 | 修改人 |
|------|------|---------|--------|
| V1.0 | 2026-06-17 | 初始版本：数据库DDL、API接口、错误码规范 | @Arch |

---

## 目录

1. [第1章：数据库详细设计](#第1章数据库详细设计)
2. [第2章：API接口设计](#第2章api接口设计)
3. [第3章：错误码规范](#第3章错误码规范)

---

# 第1章：数据库详细设计

## 1.1 ER关系图

```
┌─────────────────┐       ┌──────────────────────┐       ┌─────────────────────┐
│     users        │       │      questions        │       │  knowledge_points   │
├─────────────────┤       ├──────────────────────┤       ├─────────────────────┤
│ id (PK)         │──1:N──│ user_id (FK)         │       │ id (PK)             │
│ phone (UQ)      │       │ id (PK)              │──M:N──│ parent_id (FK->self)│
│ nickname        │       │ status               │       │ name                │
│ avatar_url      │       │ image_url            │       │ level               │
│ grade           │       │ ocr_text             │       │ stage               │
│ storage_used    │       │ ocr_confirmed        │       │ keywords            │
│ storage_limit   │       │ my_answer            │       │ sort_order          │
│ streak_days     │       │ correct_answer       │       │ version             │
│ review_reminder │       │ solution_steps       │       └─────────────────────┘
│ reminder_enabled│       │ error_step_index     │                │
│ mastered_anim   │       │ error_category       │                │
│ daily_review_lim│       │ error_sub_category   │                │
│ last_active_at  │       │ custom_tags          │                │
│ created_at      │       │ master_count         │                │
│ updated_at      │       │ review_round         │                │
│ deleted_at      │       │ next_review_date     │                │
└─────────────────┘       │ mastered_at          │                │
        │                 │ revive_check_date    │                │
        │                 │ revive_check_interval│                │
        │                 │ ai_error_analysis    │ <- V1.1预留    │
        │                 │ ai_knowledge_gaps    │ <- V1.1预留    │
        │                 │ ai_suggested_exercises<- V1.1预留    │
        │                 │ ai_analyzed_at       │ <- V1.1预留    │
        │                 │ created_at           │                │
        │                 │ updated_at           │                │
        │                 │ deleted_at           │                │
        │                 └──────────┬───────────┘                │
        │                            │                            │
        │                   1:N      │                     M:N    │
        │                            v                            │
        │                 ┌──────────────────────┐    ┌──────────────────────┐
        │                 │   review_records      │    │ question_knowledge   │
        │                 ├──────────────────────┤    ├──────────────────────┤
        │                 │ id (PK)              │    │ question_id (FK,PK)  │
        │                 │ question_id (FK)     │    │ knowledge_point_id   │
        │                 │ user_id (FK)         │    │   (FK,PK)            │
        │                 │ review_round         │    └──────────────────────┘
        │                 │ self_rating          │
        │                 │ master_count_after   │
        │                 │ review_duration_sec  │
        │                 │ reviewed_at          │
        │                 └──────────────────────┘
        │
        │1:N
        v
┌─────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
│ weekly_reports  │    │     sync_queue        │    │    user_devices      │
├─────────────────┤    ├──────────────────────┤    ├──────────────────────┤
│ id (PK)         │    │ id (PK)              │    │ id (PK)              │
│ user_id (FK)    │    │ user_id (FK)         │    │ user_id (FK)         │
│ week_number     │    │ entity_type          │    │ device_name          │
│ week_start      │    │ entity_id            │    │ device_type          │
│ week_end        │    │ operation            │    │ push_token           │
│ new_questions   │    │ payload              │    │ last_login_at        │
│ mastered_quest  │    │ status               │    │ created_at           │
│ review_count    │    │ retry_count          │    └──────────────────────┘
│ review_accuracy │    │ next_retry_at        │     MVP新增: FR-001-5/6
│ prev_week_new   │    │ error_message        │
│ prev_week_mast  │    │ created_at           │
│ top_error_cat   │    │ updated_at           │
│ weak_know_top   │    └──────────────────────┘
│ created_at      │     MVP新增: GR-002
└─────────────────┘
```

**关系说明：**
- `users` 1:N `questions`：一个用户拥有多道错题
- `users` 1:N `review_records`：一个用户有多条复习记录
- `users` 1:N `weekly_reports`：一个用户有多份周报
- `users` 1:N `sync_queue`：一个用户有多条同步队列记录
- `users` 1:N `user_devices`：一个用户最多3台设备（FR-001-5）
- `questions` 1:N `review_records`：一道错题有多次复习记录
- `questions` M:N `knowledge_points`：通过 `question_knowledge` 关联表
- `knowledge_points` 自关联：`parent_id -> id` 构成树形结构

---

## 1.2 完整DDL语句

### 1.2.1 枚举类型定义

```sql
-- ============================================================
-- 枚举类型（PostgreSQL TYPE）
-- ============================================================

-- 年级枚举
CREATE TYPE grade_enum AS ENUM (
    '31',  -- 小学三年级
    '32',  -- 小学四年级
    '33',  -- 小学五年级
    '34',  -- 小学六年级
    '71',  -- 初中一年级
    '72',  -- 初中二年级
    '73'   -- 初中三年级
);

-- 错题状态枚举（含V1.1变更：新增PERMANENTLY_MASTERED）
CREATE TYPE question_status_enum AS ENUM (
    'NOT_STARTED',          -- 未掌握
    'REVIEWING',            -- 复习中
    'MASTERED',             -- 已消灭
    'PERMANENTLY_MASTERED'  -- 永久消灭（通过90天复活检测）
);

-- 错因粗分类枚举（含V1.1变更：新增UNKNOWN）
CREATE TYPE error_category_enum AS ENUM (
    'KNOWLEDGE',   -- 知识性错误
    'SKILL',       -- 技能性错误
    'PSYCHOLOGY',  -- 心理性错误
    'HABIT',       -- 习惯性错误
    'UNKNOWN'      -- 不确定（仅小学生，不计入错因分布统计）
);

-- 自评结果枚举
CREATE TYPE self_rating_enum AS ENUM (
    'MASTERED',  -- 完全掌握
    'PARTIAL',   -- 部分记得
    'FAILED'     -- 完全不会
);

-- 知识点学段枚举
CREATE TYPE stage_enum AS ENUM (
    'PRIMARY',  -- 小学
    'JUNIOR'    -- 初中
);

-- 同步队列操作类型枚举
CREATE TYPE sync_operation_enum AS ENUM (
    'CREATE',  -- 新建
    'UPDATE',  -- 更新
    'DELETE'   -- 删除
);

-- 同步队列状态枚举
CREATE TYPE sync_status_enum AS ENUM (
    'PENDING',   -- 待上传
    'UPLOADING', -- 上传中
    'SUCCESS',   -- 上传成功
    'FAILED'     -- 上传失败（已达最大重试次数）
);

-- 设备类型枚举
CREATE TYPE device_type_enum AS ENUM (
    'IOS',
    'ANDROID'
);
```

### 1.2.2 users 用户表

```sql
-- ============================================================
-- users 用户表
-- 来源：PRD S7.2 + FR-001 + FR-800
-- ============================================================
CREATE TABLE users (
    id                   BIGSERIAL PRIMARY KEY,
    phone                VARCHAR(11)    NOT NULL,
    nickname             VARCHAR(24),
    avatar_url           VARCHAR(512),
    grade                grade_enum     NOT NULL,
    storage_used         BIGINT         NOT NULL DEFAULT 0,
    storage_limit        BIGINT         NOT NULL DEFAULT 5368709120,  -- 5GB
    streak_days          INT            NOT NULL DEFAULT 0,
    review_reminder_time TIME           NOT NULL DEFAULT '19:00:00',
    reminder_enabled     BOOLEAN        NOT NULL DEFAULT TRUE,
    mastered_animation   BOOLEAN        NOT NULL DEFAULT TRUE,
    daily_review_limit   INT            NOT NULL DEFAULT 20,
    last_active_at       TIMESTAMPTZ,
    created_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    deleted_at           TIMESTAMPTZ,

    CONSTRAINT uk_users_phone UNIQUE (phone),
    CONSTRAINT chk_users_storage_non_neg CHECK (storage_used >= 0),
    CONSTRAINT chk_users_storage_limit_pos CHECK (storage_limit > 0),
    CONSTRAINT chk_users_streak_non_neg CHECK (streak_days >= 0),
    CONSTRAINT chk_users_daily_limit CHECK (daily_review_limit BETWEEN 10 AND 30),
    CONSTRAINT chk_users_nickname_len CHECK (
        nickname IS NULL OR char_length(nickname) BETWEEN 2 AND 12
    )
);

COMMENT ON TABLE users IS '用户表';
COMMENT ON COLUMN users.grade IS '年级：31-36=小学, 71-73=初中';
COMMENT ON COLUMN users.storage_limit IS '存储上限，默认5GB（字节）';
COMMENT ON COLUMN users.daily_review_limit IS '每日复习上限，默认20，范围10-30';
COMMENT ON COLUMN users.deleted_at IS '注销时间，非NULL表示账号已注销';
```

### 1.2.3 questions 错题表

```sql
-- ============================================================
-- questions 错题表
-- 来源：PRD S7.2 + FR-200/201/500 + 变更7(AI预留字段)
-- ============================================================
CREATE TABLE questions (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT              NOT NULL,
    status                  question_status_enum NOT NULL DEFAULT 'NOT_STARTED',
    image_url               VARCHAR(512)        NOT NULL,
    ocr_text                TEXT,
    ocr_confirmed           BOOLEAN             NOT NULL DEFAULT FALSE,
    my_answer               TEXT,
    correct_answer          TEXT,
    solution_steps          JSONB,              -- [{"step":1,"content":"...","is_error":false}]
    error_step_index        INT,
    error_category          error_category_enum NOT NULL,
    error_sub_category      VARCHAR(32),
    custom_tags             JSONB,              -- 字符串数组，最多5个
    master_count            INT                 NOT NULL DEFAULT 0,
    review_round            INT                 NOT NULL DEFAULT 1,
    next_review_date        DATE                NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 day'),
    mastered_at             TIMESTAMPTZ,
    revive_check_date       DATE,
    revive_check_interval   INT                 DEFAULT 30,  -- 30->60->90递进

    -- AI预留字段（V1.1，MVP阶段均为NULL）
    ai_error_analysis       TEXT,               -- AI深度错因分析文本
    ai_knowledge_gaps       JSONB,              -- AI前置知识缺失链
    ai_suggested_exercises  JSONB,              -- AI推荐同类题列表
    ai_analyzed_at          TIMESTAMPTZ,         -- AI分析执行时间

    created_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ,

    CONSTRAINT fk_questions_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT chk_q_master_count CHECK (master_count BETWEEN 0 AND 3),
    CONSTRAINT chk_q_review_round CHECK (review_round BETWEEN 1 AND 5),
    CONSTRAINT chk_q_custom_tags_max CHECK (
        custom_tags IS NULL OR jsonb_array_length(custom_tags) <= 5
    ),
    CONSTRAINT chk_q_error_step CHECK (
        error_step_index IS NULL OR error_step_index >= 0
    ),
    CONSTRAINT chk_q_revive_interval CHECK (revive_check_interval IN (30, 60, 90))
);

COMMENT ON TABLE questions IS '错题表';
COMMENT ON COLUMN questions.status IS '状态：NOT_STARTED/REVIEWING/MASTERED/PERMANENTLY_MASTERED';
COMMENT ON COLUMN questions.solution_steps IS '解题步骤JSON数组，error_step_index标记出错步骤';
COMMENT ON COLUMN questions.master_count IS '连续掌握计数(0-3)，达到3时触发消灭';
COMMENT ON COLUMN questions.review_round IS '当前复习轮次(1-5)';
COMMENT ON COLUMN questions.revive_check_interval IS '复活检测间隔天数：30->60->90递进';
COMMENT ON COLUMN questions.ai_error_analysis IS '[V1.1预留] AI深度错因分析，MVP为NULL';
COMMENT ON COLUMN questions.ai_knowledge_gaps IS '[V1.1预留] AI前置知识缺失链，MVP为NULL';
COMMENT ON COLUMN questions.ai_suggested_exercises IS '[V1.1预留] AI推荐同类题，MVP为NULL';
COMMENT ON COLUMN questions.ai_analyzed_at IS '[V1.1预留] AI分析时间，MVP为NULL';
```

### 1.2.4 review_records 复习记录表

```sql
-- ============================================================
-- review_records 复习记录表
-- 来源：PRD S7.2 + FR-400/401
-- ============================================================
CREATE TABLE review_records (
    id                    BIGSERIAL PRIMARY KEY,
    question_id           BIGINT           NOT NULL,
    user_id               BIGINT           NOT NULL,
    review_round          INT              NOT NULL,
    self_rating           self_rating_enum NOT NULL,
    master_count_after    INT              NOT NULL,
    review_duration_sec   INT,
    reviewed_at           TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_review_question FOREIGN KEY (question_id) REFERENCES questions(id),
    CONSTRAINT fk_review_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT chk_rr_round CHECK (review_round BETWEEN 1 AND 5),
    CONSTRAINT chk_rr_master CHECK (master_count_after BETWEEN 0 AND 3),
    CONSTRAINT chk_rr_duration CHECK (
        review_duration_sec IS NULL OR review_duration_sec >= 0
    )
);

COMMENT ON TABLE review_records IS '复习记录表，每次自评产生一条';
COMMENT ON COLUMN review_records.self_rating IS '自评：MASTERED/PARTIAL/FAILED';
COMMENT ON COLUMN review_records.master_count_after IS '本次复习后的消灭计数快照';
```

### 1.2.5 knowledge_points 知识点表

```sql
-- ============================================================
-- knowledge_points 知识点表
-- 来源：PRD S7.2 FR-301
-- ============================================================
CREATE TABLE knowledge_points (
    id          SERIAL PRIMARY KEY,
    parent_id   INT,
    name        VARCHAR(64)  NOT NULL,
    level       SMALLINT     NOT NULL,  -- 1/2/3级
    stage       stage_enum   NOT NULL,
    keywords    JSONB,                 -- 关键词列表，用于AI匹配
    sort_order  INT          NOT NULL DEFAULT 0,
    version     VARCHAR(16)  NOT NULL DEFAULT '2026A',

    CONSTRAINT fk_kp_parent FOREIGN KEY (parent_id) REFERENCES knowledge_points(id),
    CONSTRAINT chk_kp_level CHECK (level BETWEEN 1 AND 3),
    CONSTRAINT chk_kp_sort CHECK (sort_order >= 0),
    CONSTRAINT uk_kp_parent_name_ver UNIQUE (parent_id, name, version)
);

COMMENT ON TABLE knowledge_points IS '知识点树表，支持多级结构和版本管理';
COMMENT ON COLUMN knowledge_points.level IS '层级：1=一级, 2=二级, 3=三级知识点';
COMMENT ON COLUMN knowledge_points.keywords IS '关键词JSON数组，用于AI规则匹配推荐';
COMMENT ON COLUMN knowledge_points.version IS '版本号如2026A，支持每学期更新';
```

### 1.2.6 question_knowledge 错题-知识点关联表

```sql
-- ============================================================
-- question_knowledge 错题-知识点关联表（M:N）
-- 来源：PRD S7.2 + GR-003-3（每题1-3个知识点）
-- ============================================================
CREATE TABLE question_knowledge (
    question_id        BIGINT NOT NULL,
    knowledge_point_id INT    NOT NULL,

    CONSTRAINT pk_qk PRIMARY KEY (question_id, knowledge_point_id),
    CONSTRAINT fk_qk_question FOREIGN KEY (question_id) REFERENCES questions(id),
    CONSTRAINT fk_qk_kp FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points(id)
);

COMMENT ON TABLE question_knowledge IS '错题与知识点的多对多关联表';
```

### 1.2.7 weekly_reports 周报表

```sql
-- ============================================================
-- weekly_reports 学情周报表
-- 来源：PRD S7.2 + FR-602
-- ============================================================
CREATE TABLE weekly_reports (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT         NOT NULL,
    week_number         INT            NOT NULL,  -- 如202624=2026年第24周
    week_start          DATE           NOT NULL,
    week_end            DATE           NOT NULL,
    new_questions       INT            NOT NULL DEFAULT 0,
    mastered_questions  INT            NOT NULL DEFAULT 0,
    review_count        INT            NOT NULL DEFAULT 0,
    review_accuracy     DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
    prev_week_new       INT,
    prev_week_mastered  INT,
    top_error_category  error_category_enum,
    weak_knowledge_top  JSONB,         -- [{id, name, count}]
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_report_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uk_report_user_week UNIQUE (user_id, week_number),
    CONSTRAINT chk_rpt_dates CHECK (week_end > week_start),
    CONSTRAINT chk_rpt_accuracy CHECK (review_accuracy BETWEEN 0 AND 100),
    CONSTRAINT chk_rpt_counts CHECK (
        new_questions >= 0 AND mastered_questions >= 0 AND review_count >= 0
    )
);

COMMENT ON TABLE weekly_reports IS '学情周报表，每周日20:00自动生成';
COMMENT ON COLUMN weekly_reports.week_number IS '周编号YYYYWW';
COMMENT ON COLUMN weekly_reports.review_accuracy IS '本周复习正确率(%)';
COMMENT ON COLUMN weekly_reports.weak_knowledge_top IS '薄弱知识点TOP3 JSON数组';
```

### 1.2.8 sync_queue 离线同步队列表（MVP新增）

```sql
-- ============================================================
-- sync_queue 离线同步队列表
-- 来源：GR-002 单向上传 + 变更5
-- ============================================================
CREATE TABLE sync_queue (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT             NOT NULL,
    entity_type     VARCHAR(16)        NOT NULL,  -- QUESTION / REVIEW_RECORD
    entity_id       VARCHAR(64),                  -- 本地临时ID或远端ID
    operation       sync_operation_enum NOT NULL,
    payload         JSONB              NOT NULL,  -- 完整实体数据
    status          sync_status_enum   NOT NULL DEFAULT 'PENDING',
    retry_count     INT                NOT NULL DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    error_message   TEXT,
    created_at      TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ        NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_sync_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT chk_sync_retry CHECK (retry_count BETWEEN 0 AND 3),
    CONSTRAINT chk_sync_entity CHECK (entity_type IN ('QUESTION', 'REVIEW_RECORD'))
);

COMMENT ON TABLE sync_queue IS '离线同步队列，支持GR-002单向上传';
COMMENT ON COLUMN sync_queue.entity_type IS '实体类型：QUESTION/REVIEW_RECORD';
COMMENT ON COLUMN sync_queue.payload IS '完整实体数据JSON';
COMMENT ON COLUMN sync_queue.retry_count IS '重试次数，最多3次，指数退避(1s->2s->4s)';
COMMENT ON COLUMN sync_queue.next_retry_at IS '下次重试时间';
```

### 1.2.9 user_devices 设备管理表（MVP新增）

```sql
-- ============================================================
-- user_devices 设备管理表
-- 来源：FR-001-5/6（最多3台设备，第4台踢最早设备）
-- ============================================================
CREATE TABLE user_devices (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT           NOT NULL,
    device_name    VARCHAR(64)      NOT NULL,
    device_type    device_type_enum NOT NULL,
    push_token     VARCHAR(256),              -- APNs / FCM token
    last_login_at  TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    created_at     TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_device_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uk_device_user_push UNIQUE (user_id, push_token)
);

COMMENT ON TABLE user_devices IS '设备管理表，每用户最多3台（FR-001-5）';
COMMENT ON COLUMN user_devices.push_token IS '推送token，用于APNs/FCM';
COMMENT ON COLUMN user_devices.last_login_at IS '最后登录时间，踢设备依据';
```

---

## 1.3 索引设计

```sql
-- ============================================================
-- 索引设计
-- 原则：覆盖高频查询路径，避免过度索引影响写入性能
-- ============================================================

-- ==================== users ====================
-- phone已有UNIQUE约束自动创建索引
CREATE INDEX idx_users_last_active ON users(last_active_at) WHERE deleted_at IS NULL;

-- ==================== questions ====================
-- 核心：按用户+状态筛选错题列表
CREATE INDEX idx_questions_user_status ON questions(user_id, status)
    WHERE deleted_at IS NULL;

-- 核心：获取今日待复习列表（最高频查询！）
CREATE INDEX idx_questions_user_next_review ON questions(user_id, next_review_date)
    WHERE deleted_at IS NULL AND status IN ('NOT_STARTED', 'REVIEWING');

-- 按错因筛选
CREATE INDEX idx_questions_user_category ON questions(user_id, error_category)
    WHERE deleted_at IS NULL;

-- 按录入时间排序/筛选
CREATE INDEX idx_questions_user_created ON questions(user_id, created_at DESC)
    WHERE deleted_at IS NULL;

-- 复活检测队列
CREATE INDEX idx_questions_revive_check ON questions(mastered_at, revive_check_date)
    WHERE deleted_at IS NULL AND status = 'MASTERED';

-- 软删除过期清理定时任务
CREATE INDEX idx_questions_deleted_expired ON questions(deleted_at)
    WHERE deleted_at IS NOT NULL;

-- Dashboard统计聚合
CREATE INDEX idx_questions_user_stats ON questions(user_id, status, error_category)
    WHERE deleted_at IS NULL;

-- ==================== review_records ====================
CREATE INDEX idx_review_user_date ON review_records(user_id, reviewed_at DESC);
CREATE INDEX idx_review_question ON review_records(question_id, reviewed_at DESC);
CREATE INDEX idx_review_user_date_only ON review_records(user_id, (reviewed_at::date));

-- ==================== knowledge_points ====================
CREATE INDEX idx_kp_stage_level ON knowledge_points(stage, level, sort_order);
CREATE INDEX idx_kp_parent ON knowledge_points(parent_id, sort_order);

-- ==================== question_knowledge ====================
-- 按知识点查错题数（薄弱知识点排行）
CREATE INDEX idx_qk_kp ON question_knowledge(knowledge_point_id);
-- 注：联合主键已覆盖按question_id查询

-- ==================== weekly_reports ====================
CREATE INDEX idx_report_user_created ON weekly_reports(user_id, week_number DESC);

-- ==================== sync_queue ====================
CREATE INDEX idx_sync_pending ON sync_queue(user_id, created_at)
    WHERE status IN ('PENDING', 'FAILED') AND next_retry_at <= NOW();
CREATE INDEX idx_sync_user_status ON sync_queue(user_id, status);

-- ==================== user_devices ====================
CREATE INDEX idx_device_user_login ON user_devices(user_id, last_login_at DESC);
```

---

## 1.4 数据初始化脚本

```sql
-- ============================================================
-- 数据初始化脚本（示意数据，完整版由教研团队交付）
-- ============================================================

-- 小学数学一级分类
INSERT INTO knowledge_points (name, level, stage, sort_order, version) VALUES
('数与代数', 1, 'PRIMARY', 1, '2026A'),
('图形与几何', 1, 'PRIMARY', 2, '2026A'),
('统计与概率', 1, 'PRIMARY', 3, '2026A'),
('综合与实践', 1, 'PRIMARY', 4, '2026A');

-- 初中数学一级分类
INSERT INTO knowledge_points (name, level, stage, sort_order, version) VALUES
('数与式', 1, 'JUNIOR', 1, '2026A'),
('方程与不等式', 1, 'JUNIOR', 2, '2026A'),
('函数', 1, 'JUNIOR', 3, '2026A'),
('图形与几何', 1, 'JUNIOR', 4, '2026A'),
('统计与概率', 1, 'JUNIOR', 5, '2026A'),
('综合与实践', 1, 'JUNIOR', 6, '2026A');

-- 示例二级（以"数与代数"为例，parent_id=1）
INSERT INTO knowledge_points (parent_id, name, level, stage, keywords, sort_order, version) VALUES
(1, '整数运算', 2, 'PRIMARY', '["整数","加减","乘除","四则运算"]'::jsonb, 1, '2026A'),
(1, '小数与分数', 2, 'PRIMARY', '["小数","分数","通分","约分"]'::jsonb, 2, '2026A'),
(1, '比与比例', 2, 'PRIMARY', '["比","比例","百分数"]'::jsonb, 3, '2026A'),
(1, '简易方程', 2, 'PRIMARY', '["方程","未知数","等式"]'::jsonb, 4, '2026A');

-- 示例三级
INSERT INTO knowledge_points (parent_id, name, level, stage, keywords, sort_order, version) VALUES
(7, '加减法', 3, 'PRIMARY', '["加法","减法","进位","退位"]'::jsonb, 1, '2026A'),
(7, '乘除法', 3, 'PRIMARY', '["乘法","除法","乘法表","余数"]'::jsonb, 2, '2026A'),
(8, '小数运算', 3, 'PRIMARY', '["小数","加减","乘除","小数点"]'::jsonb, 1, '2026A'),
(8, '分数运算', 3, 'PRIMARY', '["分数","通分","约分","分子","分母"]'::jsonb, 2, '2026A'),
(8, '小数分数互化', 3, 'PRIMARY', '["互化","转换","小数","分数"]'::jsonb, 3, '2026A');

-- 注意：完整知识点树由教研团队整理后以JSON格式批量导入
```

---

## 1.5 数据库设计决策备注

| # | 决策 | 原因 | 替代方案 |
|---|------|------|---------|
| 1 | PostgreSQL原生ENUM | 类型安全，防止非法值写入 | VARCHAR+CHECK |
| 2 | JSONB而非JSON | 支持索引和高效查询内部字段 | JSON/独立关联表 |
| 3 | TIMESTAMPTZ | 避免时区歧义，统一UTC存储 | TIMESTAMP+时区约定 |
| 4 | BIGSERIAL主键 | 分布式友好，避免序列冲突 | UUID（空间开销大） |
| 5 | deleted_at软删除 | 可追溯删除时间，支持30天恢复 | BOOLEAN is_deleted |
| 6 | sync_queue独立建表 | 解耦同步逻辑与业务逻辑 | 业务表加sync_status |
| 7 | user_devices独立建表 | 精确设备管理和踢出逻辑 | Redis缓存设备信息 |
| 8 | revive_check_interval冗余 | 避免每次查询计算递进间隔 | 根据mastered_at动态算 |
| 9 | solution_steps用JSONB数组 | 步骤数量不定，无需独立表 | question_steps表 |
| 10 | weekly_reports冗余prev_week | 避免每次JOIN上一周数据 | 实时JOIN查询 |

---

# 第2章：API接口设计

> 本章为**实现事实文档**：以 `src/errorhunter_server/cmd/server/main.go` 路由注册 +
> `internal/handler/*.go` + `internal/service/*.go` 的实际行为为权威。前端
> `src/errorhunter_app/lib/data/remote/api_endpoints.dart` 与后端一致，无契约偏离。
> 凡历史设计稿曾出现但后端未实现的端点（`/auth/register`、`/auth/login`、
> `/auth/send-code`、`/users/profile`、`/images/upload-url`、`/images/signed-url`、
> `/reviews/today`、`/reviews/complete`、`/reviews/revive-check`、`/reports/dashboard`、
> `/sync/upload`、`/sync/status`、`/sync/retry` 等）均已下线，不再列入。

## 2.0 全局约定

### 基础URL

```
开发环境：http://localhost:8080/v1   （或部署域名 + /v1 前缀）
生产环境：https://api.errorhunter.com/v1
```

> 后端 Gin 路由组为 `/v1`，所有端点（除 `/health` 外）均挂在该组下。

> ℹ️ 实际部署：客户端默认指向本机后端 `http://localhost:8080/v1`（见 `src/errorhunter_app/lib/config/app_config.dart` 的 `apiBaseUrl`），生产环境通过 `--dart-define=API_BASE_URL=http://<your-server>:8080/v1`（或启用 HTTPS 域名 `https://api.errorhunter.com/v1`）指定。

### 认证方式

```
Authorization: Bearer <access_token>
```

- Access Token 由 `/auth/otp/verify` 或 `/auth/refresh` 返回；过期需用 refresh_token 刷新。
- 中间件 `middleware.Auth` 校验 JWT，失败返回 `90005(401)`。
- 登出会把当前 access_token 加入 Redis 黑名单、删除 refresh_token。
- `/v1/files/*key` 与 `/health` **无需认证**（objectKey 含 UUID 不可猜测）。

### 统一响应格式

成功（`respondSuccess`，HTTP 200）：

```json
{ "code": 0, "message": "success", "data": { ... } }
```

创建成功（`respondCreated`，HTTP 201）：

```json
{ "code": 0, "message": "created", "data": { ... } }
```

错误（`respondError`，HTTP 由错误码定义）：

```json
{ "code": 10002, "message": "验证码错误或已过期", "data": null }
```

> 注意：除 `/auth/otp/verify` 内联返回 `"message":"success"` 外，其余成功响应统一 `message:"success"`；
> 写操作（删除/恢复/清空/更新设置/注销）的 `data` 通常为 `{ "message": "..." }` 文案对象，非资源对象。

### 分页约定

请求：`GET /v1/questions?page=1&page_size=20`

响应 data 含：

```json
{ "list": [...], "pagination": { "page": 1, "page_size": 20, "total": 156 } }
```

> 不同端点的分页键名以各端点实际为准：questions 列表用 `list`+`pagination`；
> reviews 历史用 `list`+`pagination`；reports/weekly 列表用 `items`+`pagination`。

### 通用HTTP状态码

| 状态码 | 含义 | 场景 |
|--------|------|------|
| 200 | OK | GET / PUT / POST（非创建）/ DELETE 成功 |
| 201 | Created | POST 创建错题成功（`/questions`） |
| 400 | Bad Request | 参数校验失败 |
| 401 | Unauthorized | Token 无效/过期/未登录 |
| 403 | Forbidden | 无权访问 / 账号已注销 |
| 404 | Not Found | 资源不存在 |
| 409 | Conflict | 资源冲突（如重复复习） |
| 429 | Too Many Requests | 限流 / 验证码频率限制 |
| 500 | Internal Server Error | 服务端异常 |
| 503 | Service Unavailable | 图片服务（MinIO/OSS）不可用 |

> 注意：后端**未使用 204 No Content**。删除类端点一律返回 200 + `{code:0, message, data:{message:...}}`。

---

## 2.1 认证模块

### 2.1.1 POST /auth/otp/send — 发送验证码

**描述：** 注册/登录合一，先发验证码。支持白名单号码（任意码可通过，跳过真实短信）。

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | phone | string | Y | 11位手机号 | 归一化去 `+`/`86` 前缀后比对白名单 |
| Body | scene | string | Y | REGISTER / LOGIN | 业务场景 |

**成功(200)：**
```json
{ "code": 0, "message": "success", "data": { "expire_in": 300, "resend_after": 60 } }
```

**错误：**
- 10007(429): 今日验证码发送次数已达上限
- 90003(500): 短信发送失败（回退内部错误）
- 90009(400): 参数校验失败

### 2.1.2 POST /auth/otp/verify — 验证验证码并登录/注册

**描述：** 手机号已存在则登录（账号已注销则拒绝），不存在则注册。注册时 `grade` 必填。
返回 access_token + refresh_token + 用户信息。前端年级数字（3-9）会被映射为 DB 枚举（31-34/71-73）。

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | phone | string | Y | 11位手机号 | - |
| Body | code | string | Y | 6位验证码 | 白名单号码任意码可通过 |
| Body | scene | string | Y | REGISTER / LOGIN | - |
| Body | grade | string | 注册必填 | 3-9 或 31-34/71-73 | 新用户注册时映射为 DB enum |
| Body | nickname | string | N | 2-12字符（Unicode） | 不填自动生成 `用户<手机后4位>` |
| Body | device_name | string | 登录选填 | - | 设备名 |
| Body | device_type | string | 登录选填 | IOS / ANDROID | 设备类型 |
| Body | push_token | string | N | - | 推送 token |

**成功(200)：**（注意：此端点 message 固定 `success`，由 handler 内联返回）
```json
{
  "code": 0, "message": "success",
  "data": {
    "user_id": 10001,
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "expires_in": 2592000,
    "user": {
      "id": 10001,
      "phone": "138****8000",
      "nickname": "小明",
      "grade": "34",
      "avatar_url": "http://host/v1/files/...",
      "streak_days": 15,
      "reminder_enabled": true,
      "mastered_animation": true,
      "daily_review_limit": 20
    }
  }
}
```

**错误：**
- 10002(400): 验证码错误或已过期
- 10014(403): 该账号已注销（拒绝登录已注销账号）
- 10010(400): 昵称长度应为2-12个字符
- 90009(400): 参数校验失败（grade 非法等）
- 90003(500): 服务端错误

### 2.1.3 POST /auth/refresh — 刷新令牌

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | refresh_token | string | Y | 有效的 refresh_token |

**成功(200)：** 新 access_token + refresh_token + expires_in + user（结构同 2.1.2 data）。

> 刷新会作废旧 refresh_token（Redis 单点存储，覆盖更新）。

**错误：**
- 10008(401): 登录已过期，请重新登录（token 非法/已登出/已被覆盖）
- 10005(404): 用户不存在
- 90009(400): 参数校验失败

### 2.1.4 POST /auth/logout — 退出登录

需 Bearer Token。删除 refresh_token、把 access_token 加入黑名单（TTL=剩余有效期）。

**成功(200)：** `{ "code": 0, "message": "success", "data": null }`

**错误：**
- 90005(401): 未登录
- 90003(500): 服务端错误

---

## 2.2 用户模块

### 2.2.1 GET /users/me — 获取当前用户信息

需 Bearer Token。返回当前用户全量字段（手机号脱敏）。

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "id": 10001,
    "phone": "138****8000",
    "nickname": "小明",
    "avatar_url": "http://host/v1/files/avatar/10001.jpg",
    "grade": "34",
    "storage_used": 1073741824,
    "storage_limit": 5368709120,
    "storage_percent": 20.0,
    "streak_days": 15,
    "review_reminder_time": "19:00:00",
    "reminder_enabled": true,
    "mastered_animation": true,
    "daily_review_limit": 20,
    "created_at": "2026-06-01T10:00:00+08:00"
  }
}
```

**错误：**
- 90005(401): 未登录
- 10005(404): 用户不存在

### 2.2.2 GET /users/me/settings — 获取设置子集

需 Bearer Token。仅返回设置相关字段（供设置页回显）。

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "reminder_enabled": true,
    "review_reminder_time": "19:00:00",
    "mastered_animation": true,
    "daily_review_limit": 20
  }
}
```

**错误：** 90005(401) 未登录，10005(404) 用户不存在。

### 2.2.3 PUT /users/me/settings — 更新设置

需 Bearer Token。部分更新，所有字段选填（指针语义，未传不更新）。

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | nickname | string | N | 2-12字符（Unicode） | 昵称 |
| Body | avatar_url | string | N | URL | 头像地址 |
| Body | grade | string | N | 31-34/71-73 | 年级（透传 DB enum，不做 3-9 映射） |
| Body | review_reminder_time | string | N | HH:mm:ss | 复习提醒时间 |
| Body | reminder_enabled | bool | N | - | 是否开启提醒 |
| Body | mastered_animation | bool | N | - | 消灭动画开关 |
| Body | daily_review_limit | int | N | 10-30 | 每日复习上限 |

**成功(200)：** `{ "code": 0, "message": "success", "data": { "message": "设置已更新" } }`

**错误：**
- 10010(400): 昵称长度应为2-12个字符
- 10013(400): 每日复习上限应在10-30之间
- 90005(401) / 10005(404) / 90009(400) / 90003(500)

### 2.2.4 POST /users/me/deactivate — 注销账号

需 Bearer Token。软删除账号（`deleted_at` 置位），此后登录会被 10014 拒绝。

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | confirm | bool | Y | 必须为 true，二次确认 |

**成功(200)：** `{ "code": 0, "message": "success", "data": { "message": "账号已注销" } }`

**错误：**
- 90009(400): 请确认注销操作（confirm 缺失或非 true）
- 90005(401) / 10005(404) / 90003(500)

---

## 2.3 错题模块

### 2.3.1 POST /questions — 创建错题

需 Bearer Token。录入新错题，自动加入复习计划（status=NOT_STARTED, review_round=1, next_review_date=明天）。

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | image_url | string | Y | URL | 题目图片地址 |
| Body | ocr_text | string | N | - | OCR 识别文本 |
| Body | ocr_confirmed | bool | N | 默认 false | 用户是否已确认 OCR |
| Body | my_answer | string | N | - | 我的答案 |
| Body | correct_answer | string | N | - | 正确答案 |
| Body | solution_steps | string[] | N | JSON 数组 | 解题步骤 |
| Body | error_step_index | int | N | >= 0 | 错误步骤序号 |
| Body | error_category | string | Y | KNOWLEDGE/SKILL/PSYCHOLOGY/HABIT/UNKNOWN | 错因粗分类 |
| Body | sub_categories | string[] | N | - | 细分错因（多选） |
| Body | knowledge_point_ids | int[] | 条件必填 | 最多 10 个 | 知识点 ID 列表 |
| Body | knowledge_points | object[] | 条件必填 | `{id,name}` | 知识点对象；name 未命中则按用户学段 find-or-create（自定义知识点） |
| Body | custom_tags | string[] | N | 最多 5 个 | 自定义标签 |

> `knowledge_point_ids` 与 `knowledge_points` 至少传其一，否则 20014。
> 自定义知识点名含 U+FFFD（GBK 残片）会被 90009 拒绝。

**成功(201)：** 返回完整 Question 对象（含 `knowledge_points` 关联、`total_review_rounds=5`）。

```json
{
  "code": 0, "message": "created",
  "data": {
    "id": 50001, "user_id": 10001, "status": "NOT_STARTED",
    "image_url": "http://host/v1/files/questions/10001/uuid.png",
    "ocr_text": "计算：3/4 + 2/3 = ?", "ocr_confirmed": false,
    "error_category": "SKILL", "sub_categories": ["计算错误"],
    "master_count": 0, "review_round": 1, "next_review_date": "2026-06-18",
    "total_review_rounds": 5,
    "knowledge_points": [{ "id": 10, "name": "分数运算", "level": 3, "stage": "PRIMARY", "version": "2026A" }],
    "custom_tags": ["分数", "易错题"],
    "created_at": "2026-06-17T15:30:00+08:00", "updated_at": "..."
  }
}
```

**错误：**
- 20008(400): 无效错因分类
- 20014(400): 部分知识点不存在（或未传任何知识点）
- 20002(400): 每道错题最多关联10个知识点
- 20006(400): 自定义标签最多5个
- 10005(404): 用户不存在
- 90005(401) / 90009(400) / 90003(500)

### 2.3.2 GET /questions — 错题列表

需 Bearer Token。仅返回当前用户的错题。

| Query | 类型 | 必填 | 说明 |
|-------|------|------|------|
| page | int | N | 默认 1；<1 钳制为 1 |
| page_size | int | N | 默认 20；<1→20，>50→50 |
| q | string | N | 搜索关键词（优先于 keyword）；搜 ocr_text |
| keyword | string | N | 搜索关键词（q 为空时回退） |
| status | string | N | 状态筛选，逗号分隔多选（NOT_STARTED/REVIEWING/MASTERED/PERMANENTLY_MASTERED） |
| error_category | string | N | 错因筛选 |
| knowledge_point_id | int | N | 知识点筛选 |
| start_date | string | N | YYYY-MM-DD，created_at >= 当天 00:00 |
| end_date | string | N | YYYY-MM-DD，覆盖当天全天（[end, end+1day)） |
| sort_by | string | N | 默认 created_at |
| sort_order | string | N | asc / desc，默认 desc |

> 关键词参数：后端同时接受 `q` 与 `keyword`，`q` 优先。前端 `searchQuestions` 发 `q`，
> 列表筛选可能发 `keyword`，两者等价。文档以 `q` 为准。

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "list": [ /* Question 对象数组 */ ],
    "pagination": { "page": 1, "page_size": 20, "total": 156 }
  }
}
```

**错误：** 90005(401) / 90003(500)

### 2.3.3 GET /questions/:id — 错题详情

需 Bearer Token。Path: id (long)。返回完整 Question（含 `knowledge_points`、`total_review_rounds`）。

**错误：**
- 20004(404): 错题不存在或已被删除
- 20010(403): 无权操作该错题（不属于当前用户）
- 90009(400): id 非法
- 90005(401) / 90003(500)

### 2.3.4 PUT /questions/:id — 更新错题

需 Bearer Token。部分更新，所有字段指针语义（未传不更新；显式传 `[]` 会清空数组字段）。

| 参数位置 | 字段 | 类型 | 说明 |
|---------|------|------|------|
| Body | ocr_text | string | - |
| Body | ocr_confirmed | bool | - |
| Body | my_answer | string | - |
| Body | correct_answer | string | - |
| Body | solution_steps | string[] | nil 不更新；[] 清空 |
| Body | error_step_index | int | - |
| Body | error_category | string | KNOWLEDGE/SKILL/PSYCHOLOGY/HABIT/UNKNOWN |
| Body | sub_categories | string[] | nil 不更新；[] 清空 |
| Body | knowledge_point_ids | int[] | - |
| Body | knowledge_points | object[] | `{id,name}`，自定义知识点 find-or-create |
| Body | custom_tags | string[] | 最多 5 个 |

**成功(200)：** 更新后的完整 Question 对象。

**错误：** 20004(404) / 20010(403) / 20006(400) / 90005(401) / 90009(400) / 90003(500)

### 2.3.5 DELETE /questions/:id — 软删除

需 Bearer Token。软删除，30 天内可在回收站恢复。

**成功(200)：**
```json
{ "code": 0, "message": "success", "data": { "message": "删除成功，30天内可在回收站恢复" } }
```

**错误：** 20004(404) / 20010(403) / 90005(401) / 90003(500)

### 2.3.6 GET /questions/recycle-bin — 回收站列表

需 Bearer Token。Query: page, page_size（同 2.3.2 钳制规则）。返回软删除的错题。

**成功(200)：** `{ "list": [...], "pagination": { page, page_size, total } }`

**错误：** 90005(401) / 90003(500)

### 2.3.7 POST /questions/:id/restore — 恢复错题

需 Bearer Token。Path: id (long)。把软删除的错题恢复；未删除的题调用幂等成功。

**成功(200)：** `{ "code": 0, "message": "success", "data": { "message": "恢复成功" } }`

**错误：** 20004(404) / 20010(403) / 90009(400) / 90005(401) / 90003(500)

### 2.3.8 DELETE /questions/:id/permanent — 永久删除

需 Bearer Token。Path: id (long)。先删 DB（含关联知识点），再尽力清理 MinIO 图片（失败仅记日志，不阻断）。

**成功(200)：** `{ "code": 0, "message": "success", "data": { "message": "永久删除成功" } }`

**错误：** 20004(404) / 20010(403) / 90009(400) / 90005(401) / 90003(500)

### 2.3.9 DELETE /questions/recycle-bin/clear — 清空回收站

需 Bearer Token。二次确认；先取回收站图片 URL，DB 删除后再清理 MinIO 图片。

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | confirm | bool | Y | 必须为 true |

**成功(200)：** `{ "code": 0, "message": "success", "data": { "deleted_count": 5 } }`

**错误：**
- 20005(400): 请确认清空操作，此操作不可恢复
- 90005(401) / 90003(500)

---

## 2.4 知识点模块

### 2.4.1 GET /knowledge-points — 查询知识点

需 Bearer Token。按年级 + 学科查询知识点（版本固定 `2026A`，与 seeder 一致）。

| Query | 类型 | 必填 | 校验 | 说明 |
|-------|------|------|------|------|
| grade | string | Y | 31/32/33/34/71/72/73 | 年级（DB enum，不接受 3-9） |
| subject | string | N | 默认 `数学` | 学科 |

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "items": [
      { "id": 10, "name": "分数运算", "subject": "数学", "parent_id": "num", "is_recommended": true }
    ]
  }
}
```

> `parent_id` 实为领域标识（num/geo/stat/custom，从 keywords.domain 解析），非外键。
> 自定义知识点 `is_recommended=false`、`parent_id=custom`。

**错误：**
- 90009(400): invalid grade（grade 缺失或非法）
- 90005(401) / 90003(500)

---

## 2.5 复习模块

### 2.5.1 GET /reviews/queue — 今日复习队列

需 Bearer Token。返回正常复习题 + 复活检测题。每日复习上限取自 `users.daily_review_limit`（10-30，取不到回退 20）。

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "review_items": [ /* Question 对象数组（status=NOT_STARTED/REVIEWING）*/ ],
    "revive_items": [ /* Question 对象数组（status=MASTERED，最多 3 道）*/ ],
    "total_count": 8,
    "revive_count": 2,
    "has_more": false,
    "overflow_count": 0
  }
}
```

> `review_items` / `revive_items` 均为完整 `model.Question`（与错题列表序列化结构一致，含 `total_review_rounds`）。
> 客户端靠 `status=MASTERED` 识别复活检测题。超出 daily_limit 的题计入 `overflow_count` 且不入 review_items。

**错误：** 90005(401) / 90003(500)

### 2.5.2 POST /reviews/result — 提交复习结果

需 Bearer Token。提交一次自评或复活检测结果。当日重复提交同一题返回 30005。

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | question_id | long | Y | - | 错题 ID |
| Body | self_rating | string | Y | MASTERED / PARTIAL / FAILED | 自评结果 |
| Body | review_duration_sec | int | N | >= 0 | 复习用时（秒） |
| Body | is_revive_check | bool | N | 默认 false | 是否复活检测 |
| Body | revive_result | string | 条件必填 | REMEMBERED / FORGOTTEN | `is_revive_check=true` 时必填 |

**正常复习成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "question_id": 50001,
    "new_status": "REVIEWING",
    "new_review_round": 2,
    "new_master_count": 2,
    "next_review_date": "2026-06-21",
    "just_mastered": false,
    "streak_days": 16
  }
}
```

> `just_mastered=true` 表示本次复习让 `master_count` 达到 3，状态升为 MASTERED。
> `next_review_date` 为 `YYYY-MM-DD`；永久消灭时该字段省略。
> 复活检测成功推进间隔（30→60→90→0永久消灭）；失败则重置为 REVIEWING、review_round=1。

**复活失败成功(200)：** `data` 含 `is_revive_failed:true`、`encourage_message:"这道题需要再巩固一下哦！加油"`。

**错误：**
- 30002(400): 无效的自评结果
- 30003(400): 复活检测需提供检测结果
- 30004(400): 无效复活检测结果
- 30005(409): 今日已完成该题的复习
- 30008(400): 复习用时不能为负
- 30007(400): 该错题不需要复活检测（非 MASTERED 状态题发起复活检测）
- 20004(404) / 20010(403) / 90005(401) / 90009(400) / 90003(500)

### 2.5.3 GET /reviews — 复习历史

需 Bearer Token。分页返回历史复习记录。

| Query | 类型 | 必填 | 说明 |
|-------|------|------|------|
| page | int | N | 默认 1；<1→1 |
| page_size | int | N | 默认 20；<1→20，>100→100 |

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "list": [
      {
        "id": 9001, "question_id": 50001, "user_id": 10001,
        "review_round": 2, "self_rating": "MASTERED",
        "master_count_after": 3, "review_duration_sec": 45,
        "reviewed_at": "2026-06-17T15:30:00+08:00"
      }
    ],
    "pagination": { "page": 1, "page_size": 20, "total": 42 }
  }
}
```

**错误：** 90005(401) / 90003(500)

---

## 2.6 报告模块

### 2.6.1 GET /reports — Dashboard 概览

需 Bearer Token。首页 Dashboard 数据。

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "greeting": { "nickname": "小明", "streak_days": 15 },
    "today_task": {
      "pending_review_count": 8,
      "has_overflow": false,
      "overflow_count": 0
    },
    "statistics": {
      "total_questions": 156,
      "mastered_count": 50,
      "elimination_rate": 32.1
    },
    "error_distribution": [
      { "category": "SKILL", "count": 45 }
    ],
    "weekly_trend": [
      { "date": "2026-06-11", "new_questions": 3, "mastered_count": 2 }
    ],
    "weak_knowledge_top": [
      { "id": 10, "name": "分数运算", "count": 8 }
    ],
    "weekly_completed": [true, false, true, true, false, false, false]
  }
}
```

> - `elimination_rate` = round(mastered_count/total_questions*1000)/10，保留 1 位小数。
> - `today_task.overflow_count` = max(0, pending_review - daily_review_limit)。
> - `weekly_completed` 为周一至周日的布尔数组（当天有 review_records 才算打卡；今天及未来天为 false）。
> - `error_distribution` / `weekly_trend` / `weak_knowledge_top` 各项仅含 `category+count` / `date+new_questions+mastered_count` / `id+name+count`，无 label/percent/path 字段。

**错误：** 90005(401) / 10005(404) / 90003(500)

### 2.6.2 GET /reports/weekly — 周报列表

需 Bearer Token。

| Query | 类型 | 必填 | 说明 |
|-------|------|------|------|
| page | int | N | 默认 1；<1→1 |
| page_size | int | N | 默认 10；<1→10，>20→20 |

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "items": [ /* WeeklyReport 对象数组 */ ],
    "pagination": { "page": 1, "page_size": 10, "total": 12 }
  }
}
```

> WeeklyReport 字段：`id, user_id, week_number, week_start, week_end, new_questions, mastered_questions, review_count, review_accuracy, prev_week_new, prev_week_mastered, top_error_category, top_error_category_percentage, weak_knowledge_top, created_at`。

**错误：** 90005(401) / 90003(500)

### 2.6.3 GET /reports/weekly/:id — 周报详情

需 Bearer Token。Path: id (long)。返回单个 WeeklyReport 对象（data 为对象，非分页）。

**错误：**
- 40001(404): 周报不存在
- 90006(403): 无权访问（周报不属于当前用户）
- 90009(400): id 非法
- 90005(401) / 90003(500)

---

## 2.7 上传与存储模块

### 2.7.1 POST /upload — 上传图片

需 Bearer Token。multipart 表单上传到 MinIO，返回通过后端代理可访问的 URL。

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Form | image | file | Y | <= 20MB；jpg/jpeg/png/heic | 图片文件 |

> objectKey 格式：`questions/<userID>/<uuid>.<ext>`。
> 返回的 `image_url` 形如 `http://<请求Host>/v1/files/questions/<userID>/<uuid>.<ext>`，客户端 `Image.network` 可直接加载。

**成功(200)：**
```json
{ "code": 0, "message": "success", "data": { "image_url": "http://host/v1/files/questions/10001/uuid.png" } }
```

**错误：**
- 60001(400): 文件大小超过20MB限制
- 60003(400): 不支持的图片格式，仅支持JPG/PNG/HEIC
- 60008(503): 图片服务暂时不可用，请稍后重试（MinIO PutObject 失败）
- 90005(401) / 90009(400)

### 2.7.2 POST /upload/ocr — OCR 识别

需 Bearer Token。从图片 URL 提取 objectKey，优先从 MinIO 直接下载传给 OCR（避免内网 URL 外网不可达）。

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | image_url | string | Y | 支持 `/v1/files/<key>` 代理 URL 或 `http://endpoint/bucket/<key>` 直连 URL |

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "text": "计算：3/4 + 2/3 = ?",
    "confidence": 0.92,
    "has_handwriting": true,
    "has_formula": false,
    "figures": [],
    "degraded": false
  }
}
```

> `degraded=true` 时附带 `degrade_reason`。`figures` 为图片区域数组。

**错误：** 60008(503) / 90009(400) / 90005(401) / 90003(500)

### 2.7.3 GET /upload/signed-url — 获取签名 URL

需 Bearer Token。为指定图片生成 MinIO 预签名访问 URL。

| Query | 类型 | 必填 | 说明 |
|-------|------|------|------|
| file_url | string | Y | 形如 `http://endpoint/bucket/<key>`，取第 5 段为 objectKey |
| expires | int | N | 60-3600 秒，默认 1800；越界回退 1800 |

**成功(200)：**
```json
{ "code": 0, "message": "success", "data": { "signed_url": "https://minio.../...", "expires_in": 1800 } }
```

**错误：**
- 60008(503): 图片服务暂时不可用（预签名失败）
- 90009(400): 参数校验失败（file_url 缺失或格式不符）
- 90005(401)

### 2.7.4 GET /storage — 存储用量

需 Bearer Token。统计当前用户在 MinIO 的错题图片总量，返回图片对象列表（按 last_modified 倒序，最多 200 张）。

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "used_bytes": 1073741824,
    "image_count": 42,
    "images": [
      {
        "url": "http://host/v1/files/questions/10001/uuid.png",
        "size": 262144,
        "last_modified": "2026-06-17T15:30:00Z",
        "key": "questions/10001/uuid.png"
      }
    ],
    "total": 42,
    "has_more": false
  }
}
```

> `used_bytes` / `image_count` / `total` 统计全量；`images` 最多 200 项，超出时 `has_more=true`。
> `total` 与 `image_count` 同值。

**错误：**
- 60008(503): 图片服务暂时不可用（ListObjects 失败）
- 90005(401)

### 2.7.5 GET /files/*key — 图片代理访问

**无需认证。** 从 MinIO 流式转发图片。Path: `*key`（含前导 `/`，去掉前导 `/` 后为 objectKey）。

**成功(200)：** 原图字节流，透传 `Content-Type` / `Content-Length`。

**错误：** 400（key 为空）/ 404（对象不存在或下载失败）。无统一 JSON envelope。

> 设计依据：objectKey 含 UUID 不可猜测，故免鉴权以便 `Image.network` 直接加载。

---

## 2.8 同步模块（V1.1 桩实现）

> 当前为桩实现，`Push` 永远返回 SUCCESS，`Pull` 永远返回空变更集。实际同步逻辑 TODO。

### 2.8.1 POST /sync/push — 推送本地变更

需 Bearer Token。

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | items | array | Y | 1-50 个 |
| Body[].local_id | string | Y | 本地 ID |
| Body[].entity_type | string | Y | QUESTION / REVIEW_RECORD |
| Body[].operation | string | Y | CREATE / UPDATE / DELETE |
| Body[].payload | object | Y | 完整实体数据 |

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "results": [ { "local_id": "uuid-abc", "status": "SUCCESS", "remote_id": 1 } ],
    "success_count": 1,
    "fail_count": 0
  }
}
```

**错误：**
- 50001(400): 同步数据格式无效
- 50004(400): 批量同步不能超过50条
- 90005(401)

### 2.8.2 GET /sync/pull — 拉取远端变更

需 Bearer Token。

| Query | 类型 | 必填 | 说明 |
|-------|------|------|------|
| last_sync_at | string | N | 客户端上次同步时间，原样回显 |

**成功(200)：**
```json
{
  "code": 0, "message": "success",
  "data": {
    "changes": [],
    "has_more": false,
    "server_time": "2026-06-19T00:00:00Z",
    "last_sync": "<last_sync_at 原值>"
  }
}
```

**错误：** 90005(401)

---

## 2.9 健康检查

### GET /health

**无需认证。**

**成功(200)：** `{ "status": "ok" }`（非标准 envelope，仅状态字段）

---

## 2.10 API 汇总矩阵

| 模块 | 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|------|
| 认证 | POST | /auth/otp/send | N | 发送验证码 |
| 认证 | POST | /auth/otp/verify | N | 验证码登录/注册 |
| 认证 | POST | /auth/refresh | N | 刷新令牌 |
| 认证 | POST | /auth/logout | Y | 退出登录 |
| 用户 | GET | /users/me | Y | 当前用户信息 |
| 用户 | GET | /users/me/settings | Y | 设置子集 |
| 用户 | PUT | /users/me/settings | Y | 更新设置 |
| 用户 | POST | /users/me/deactivate | Y | 注销账号 |
| 错题 | POST | /questions | Y | 创建错题 |
| 错题 | GET | /questions | Y | 错题列表 |
| 错题 | GET | /questions/:id | Y | 错题详情 |
| 错题 | PUT | /questions/:id | Y | 更新错题 |
| 错题 | DELETE | /questions/:id | Y | 软删除 |
| 错题 | GET | /questions/recycle-bin | Y | 回收站列表 |
| 错题 | DELETE | /questions/recycle-bin/clear | Y | 清空回收站 |
| 错题 | POST | /questions/:id/restore | Y | 恢复错题 |
| 错题 | DELETE | /questions/:id/permanent | Y | 永久删除 |
| 知识点 | GET | /knowledge-points | Y | 查询知识点 |
| 复习 | GET | /reviews/queue | Y | 今日复习队列 |
| 复习 | POST | /reviews/result | Y | 提交复习结果 |
| 复习 | GET | /reviews | Y | 复习历史 |
| 报告 | GET | /reports | Y | Dashboard 概览 |
| 报告 | GET | /reports/weekly | Y | 周报列表 |
| 报告 | GET | /reports/weekly/:id | Y | 周报详情 |
| 上传 | POST | /upload | Y | 上传图片 |
| 上传 | POST | /upload/ocr | Y | OCR 识别 |
| 上传 | GET | /upload/signed-url | Y | 获取签名 URL |
| 存储 | GET | /storage | Y | 存储用量 |
| 文件 | GET | /files/*key | N | 图片代理访问 |
| 同步 | POST | /sync/push | Y | 推送变更（桩） |
| 同步 | GET | /sync/pull | Y | 拉取变更（桩） |
| 系统 | GET | /health | N | 健康检查 |

> **共 32 个端点。** 同步模块为 V1.1 桩实现，行为见 2.8。

---

# 第3章：错误码规范

## 3.1 错误码分段规则

| 段位 | 模块 | 说明 |
|------|------|------|
| 10000-19999 | 用户认证与信息 | 注册、登录、验证码、个人信息 |
| 20000-29999 | 错题管理 | CRUD、回收站 |
| 30000-39999 | 复习引擎 | 待复习、自评、复活检测 |
| 40000-49999 | 学情报告 | Dashboard、周报 |
| 50000-59999 | 离线同步 | 上传、重试、队列 |
| 60000-69999 | 图片/OSS | 上传、签名URL |
| 90000-99999 | 系统级 | 限流、服务不可用 |

## 3.2 Go代码定义

```go
package errcode

// AppError 统一错误结构
type AppError struct {
    Code       int         `json:"code"`
    Message    string      `json:"message"`
    Data       interface{} `json:"data,omitempty"`
    HTTPStatus int         `json:"-"` // 不序列化，用于设置HTTP状态码
}

func (e *AppError) Error() string { return e.Message }

func New(code int, message string, httpStatus int) *AppError {
    return &AppError{Code: code, Message: message, HTTPStatus: httpStatus}
}

func (e *AppError) WithData(data interface{}) *AppError {
    e.Data = data
    return e
}

// ===== 10000-19999 用户模块 =====
const (
    ErrPhoneAlreadyRegistered = 10001 // 手机号已注册
    ErrVerifyCodeInvalid      = 10002 // 验证码错误或已过期
    ErrParentConsentRequired  = 10003 // 未勾选家长知情同意
    ErrVerifyCodeLocked       = 10004 // 验证码输错过多，已锁定
    ErrUserNotFound           = 10005 // 用户不存在
    ErrSendCodeTooFrequent    = 10006 // 验证码发送过于频繁
    ErrSendCodeDailyLimit     = 10007 // 今日验证码发送次数已达上限
    ErrRefreshTokenExpired    = 10008 // Refresh Token已过期
    ErrStorageWarning         = 10009 // 存储空间即将不足（90%）
    ErrNicknameInvalid        = 10010 // 昵称长度不合规
    ErrGradeInvalid           = 10011 // 无效的年级值
    ErrReminderTimeInvalid    = 10012 // 提醒时间不在有效范围
    ErrDailyLimitInvalid      = 10013 // 每日复习上限不在有效范围
    ErrAccountDeleted         = 10014 // 账号已注销
    ErrDeviceLimitExceeded    = 10015 // 设备数已达上限
    ErrPushTokenInvalid       = 10016 // 推送Token格式无效
)

// ===== 20000-29999 错题模块 =====
const (
    ErrStorageFull               = 20001 // 存储空间已满
    ErrKnowledgePointMaxExceeded = 20002 // 知识点超过3个
    ErrKnowledgeStageMismatch    = 20003 // 知识点与年级不匹配
    ErrQuestionNotFound          = 20004 // 错题不存在或已删除
    ErrRecycleBinConfirmRequired = 20005 // 清空回收站需二次确认
    ErrCustomTagsMaxExceeded     = 20006 // 自定义标签超过5个
    ErrErrorCategoryRequired     = 20007 // 错因粗分类必填
    ErrErrorCategoryInvalid      = 20008 // 无效错因分类
    ErrImageUrlRequired          = 20009 // 题目图片URL必填
    ErrQuestionBelongsToOther    = 20010 // 错题不属于当前用户
    ErrExportLimitExceeded       = 20011 // PDF导出超50道
    ErrSolutionStepInvalid       = 20012 // 解题步骤格式无效
    ErrOcrTextTooLong            = 20013 // OCR文字超长
)

// ===== 30000-39999 复习模块 =====
const (
    ErrReviewQuestionNotDue    = 30001 // 该错题今日不在复习计划中
    ErrReviewSelfRatingInvalid = 30002 // 无效自评结果
    ErrReviveResultRequired    = 30003 // 复活检测需提供结果
    ErrReviveResultInvalid     = 30004 // 无效复活检测结果
    ErrReviewAlreadyCompleted  = 30005 // 今日已完成该题复习
    ErrReviewRecordConflict    = 30006 // 复习记录并发冲突
    ErrReviveCheckNotAllowed   = 30007 // 该错题不需要复活检测
    ErrReviewDurationNegative  = 30008 // 复习用时不能为负
)

// ===== 40000-49999 报告模块 =====
const (
    ErrReportNotFound       = 40001 // 周报不存在
    ErrReportWeekInvalid    = 40002 // 无效周编号
    ErrReportGenerateFailed = 40003 // 周报生成失败
    ErrDashboardCacheError  = 40004 // Dashboard缓存读取失败
)

// ===== 50000-59999 同步模块 =====
const (
    ErrSyncPayloadInvalid       = 50001 // 同步数据格式无效
    ErrSyncEntityTypeInvalid    = 50002 // 无效实体类型
    ErrSyncOperationInvalid     = 50003 // 无效操作类型
    ErrSyncBatchSizeExceeded    = 50004 // 批量超50条上限
    ErrSyncRelatedEntityMissing = 50005 // 关联实体不存在
    ErrSyncRetryIdNotFound      = 50006 // 重试行不存在
    ErrSyncRetryNotFailed       = 50007 // 只能重试FAILED项
    ErrSyncLocalIdDuplicate     = 50008 // 本地ID重复
)

// ===== 60000-69999 图片模块 =====
const (
    ErrImageTooLarge            = 60001 // 图片超20MB
    ErrImageStorageInsufficient = 60002 // 存储空间不足
    ErrImageFormatUnsupported   = 60003 // 不支持的图片格式
    ErrImageUploadUrlExpired    = 60004 // 上传URL已过期
    ErrImageSignedUrlInvalid    = 60005 // 签名URL参数无效
    ErrImageFileNameInvalid     = 60006 // 文件名含非法字符
    ErrImageCategoryInvalid     = 60007 // 无效图片类别
    ErrOssServiceUnavailable    = 60008 // OSS服务不可用
)

// ===== 90000-99999 系统级 =====
const (
    ErrRateLimited        = 90001 // 全局限流
    ErrServiceUnavailable = 90002 // 服务不可用
    ErrInternalServer     = 90003 // 内部错误
    ErrInvalidRequest     = 90004 // 请求格式错误
    ErrUnauthorized       = 90005 // 未认证
    ErrForbidden          = 90006 // 无权访问
    ErrResourceNotFound   = 90007 // 资源不存在
    ErrMethodNotAllowed   = 90008 // 方法不允许
    ErrParamValidation    = 90009 // 参数校验失败
)

// ===== 预定义错误变量 =====
var (
    // 用户
    EPhoneAlreadyRegistered = New(10001, "该手机号已注册，是否直接登录？", 409)
    EVerifyCodeInvalid      = New(10002, "验证码错误或已过期", 400)
    EParentConsentRequired  = New(10003, "请勾选家长知情同意", 400)
    EVerifyCodeLocked       = New(10004, "验证码输错次数过多，请30分钟后再试", 429)
    EUserNotFound           = New(10005, "该手机号未注册", 404)
    ESendCodeTooFrequent    = New(10006, "发送过于频繁，请60秒后再试", 429)
    ESendCodeDailyLimit     = New(10007, "今日验证码发送次数已达上限", 429)
    ERefreshTokenExpired    = New(10008, "登录已过期，请重新登录", 401)
    EStorageWarning         = New(10009, "存储空间即将不足", 200)
    ENicknameInvalid        = New(10010, "昵称长度应为2-12个字符", 400)
    EAccountDeleted         = New(10014, "该账号已注销", 403)

    // 错题
    EStorageFull            = New(20001, "存储空间已满，请清理空间或升级", 403)
    EKnowledgePointMax      = New(20002, "每道错题最多关联3个知识点", 400)
    EKnowledgeStageMismatch = New(20003, "所选知识点与当前年级不匹配", 400)
    EQuestionNotFound       = New(20004, "错题不存在或已被删除", 404)
    ERecycleBinConfirm      = New(20005, "请确认清空操作，此操作不可恢复", 400)
    ECustomTagsMax          = New(20006, "自定义标签最多5个", 400)
    EErrorCategoryRequired  = New(20007, "请选择错因粗分类", 400)
    EQuestionBelongsToOther = New(20010, "无权操作该错题", 403)

    // 复习
    EReviewNotDue         = New(30001, "该错题今日不在复习计划中", 400)
    ESelfRatingInvalid    = New(30002, "无效的自评结果", 400)
    EReviveResultRequired = New(30003, "复活检测需提供检测结果", 400)
    EReviewAlreadyDone    = New(30005, "今日已完成该题的复习", 409)

    // 报告
    EReportNotFound = New(40001, "周报不存在", 404)

    // 同步
    ESyncPayloadInvalid = New(50001, "同步数据格式无效", 400)
    ESyncBatchExceeded  = New(50004, "批量同步不能超过50条", 400)
    ESyncRelatedMissing = New(50005, "关联的实体不存在", 400)

    // 图片
    EImageTooLarge          = New(60001, "文件大小超过20MB限制", 400)
    EImageStorageInsuff     = New(60002, "存储空间不足，请清理后重试", 403)
    EImageFormatUnsupported = New(60003, "不支持的图片格式，仅支持JPG/PNG/HEIC", 400)
    EOssUnavailable         = New(60008, "图片服务暂时不可用，请稍后重试", 503)

    // 系统
    ERateLimited        = New(90001, "请求过于频繁，请稍后再试", 429)
    EServiceUnavailable = New(90002, "服务暂时不可用，请稍后重试", 503)
    EInternalServer     = New(90003, "服务器内部错误", 500)
    EInvalidRequest     = New(90004, "请求格式错误", 400)
    EUnauthorized       = New(90005, "请先登录", 401)
    EForbidden          = New(90006, "无权访问", 403)
    EParamValidation    = New(90009, "参数校验失败", 400)
)
```

## 3.3 错误码使用规范

| 规则 | 说明 |
|------|------|
| 唯一性 | 每个错误码全局唯一，不跨模块复用 |
| 可扩展 | 各模块预留空位，新增递增分配 |
| HTTP映射 | 每个错误码绑定默认HTTP状态码 |
| 客户端处理 | 按code判断逻辑，message仅展示 |
| 国际化预留 | message后续可替换为i18n key |
| 日志记录 | 服务端记完整错误码+上下文 |
| 敏感信息 | 不暴露DB字段名、SQL、内部路径 |

---

## 附录：设计检查清单

| # | 检查项 | 状态 |
|---|--------|------|
| 1 | PRD数据字典全部字段体现在DDL中 | Done |
| 2 | AI预留4字段加入questions(nullable) | Done |
| 3 | PERMANENTLY_MASTERED加入枚举 | Done |
| 4 | UNKNOWN错因加入枚举 | Done |
| 5 | sync_queue支持GR-002单向上传 | Done |
| 6 | user_devices支持FR-001-5/6 | Done |
| 7 | revive_check_interval降频字段 | Done |
| 8 | API覆盖全部PRD功能需求 | Done |
| 9 | 错误码按模块分段Go代码可用 | Done |
| 10 | 图片签名URL符合NFR-001-4 | Done |
| 11 | 软删除+30天恢复有API和索引 | Done |
| 12 | 存储校验贯穿创建/上传流程 | Done |

---

**下一步：**
- Part 2：后端架构（Go项目结构、中间件、艾宾浩斯引擎算法、定时任务）
- Part 3：客户端架构（Flutter结构、离线SQLite、状态管理）
- Part 4：部署运维（CI/CD、监控告警、备份策略）
