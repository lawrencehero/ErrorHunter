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

## 2.0 全局约定

### 基础URL

```
开发环境：https://api-dev.errorhunter.com/v1
生产环境：https://api.errorhunter.com/v1
```

### 认证方式

```
Authorization: Bearer <JWT_TOKEN>
```

- Token有效期：30天（FR-001-7）
- Refresh Token有效期：90天
- 所有需认证接口返回401当Token过期或无效

### 统一响应格式

成功：`{"code": 0, "message": "success", "data": {...}}`

错误：`{"code": 10001, "message": "手机号格式不正确", "data": null}`

### 分页约定

请求：`GET /v1/questions?page=1&page_size=20`

响应data含：`{"list": [...], "pagination": {"page": 1, "page_size": 20, "total": 156}}`

### 通用HTTP状态码

| 状态码 | 含义 | 场景 |
|--------|------|------|
| 200 | OK | GET/PUT/PATCH成功 |
| 201 | Created | POST创建成功 |
| 204 | No Content | DELETE成功 |
| 400 | Bad Request | 参数校验失败 |
| 401 | Unauthorized | Token无效/过期 |
| 403 | Forbidden | 无权访问 |
| 404 | Not Found | 资源不存在 |
| 409 | Conflict | 资源冲突 |
| 429 | Too Many Requests | 限流 |
| 500 | Internal Server Error | 服务端异常 |

---

## 2.1 用户认证模块

### 2.1.1 POST /auth/register — 用户注册

**描述：** 新用户手机号+验证码注册（FR-100）

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | phone | string | Y | `^1[3-9]\d{9}$` | 11位手机号 |
| Body | verify_code | string | Y | `^\d{6}$` | 6位验证码 |
| Body | grade | string | Y | 31-34/71-73 | 年级 |
| Body | parent_consent | bool | Y | 必须true | 家长同意(FR-001-3) |
| Body | nickname | string | N | 2-12字符 | 不填自动生成 |

**成功(201)：**
```json
{
    "code": 0, "message": "注册成功",
    "data": {
        "user_id": 10001,
        "access_token": "eyJhbGciOiJIUzI1NiIs...",
        "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
        "expires_in": 2592000,
        "user": {"id": 10001, "phone": "138****8000", "nickname": "小明", "grade": "34"}
    }
}
```

**错误：**
- 10001(409): 手机号已注册
- 10002(400): 验证码错误/过期
- 10003(400): 未勾选家长同意
- 10004(429): 验证码锁定30分钟

### 2.1.2 POST /auth/login — 用户登录

**描述：** 手机号+验证码登录（FR-101），含设备管理

| 参数位置 | 字段 | 类型 | 必填 | 校验 | 说明 |
|---------|------|------|------|------|------|
| Body | phone | string | Y | `^1[3-9]\d{9}$` | 手机号 |
| Body | verify_code | string | Y | `^\d{6}$` | 验证码 |
| Body | device_name | string | Y | 1-64字符 | 设备名 |
| Body | device_type | string | Y | IOS/ANDROID | 设备类型 |
| Body | push_token | string | N | max 256 | 推送token |

**成功(200)：**
```json
{
    "code": 0, "message": "登录成功",
    "data": {
        "user_id": 10001,
        "access_token": "eyJ...", "refresh_token": "eyJ...", "expires_in": 2592000,
        "user": {
            "id": 10001, "phone": "138****8000", "nickname": "小明", "grade": "34",
            "avatar_url": "https://...", "streak_days": 15,
            "reminder_enabled": true, "mastered_animation": true, "daily_review_limit": 20
        },
        "kicked_device": null
    }
}
```

> kicked_device非null时有设备被踢出(FR-001-6)，客户端展示提示

**错误：** 10005(404) 用户不存在, 10002(400) 验证码错误

### 2.1.3 POST /auth/send-code — 发送验证码

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | phone | string | Y | 手机号 |
| Body | scene | string | Y | REGISTER/LOGIN/RESET_PASSWORD |

**成功(200)：** `{"code":0,"data":{"expire_in":300,"resend_after":60}}`

**错误：** 10006(429) 频率限制60秒, 10007(429) 当日10次上限

### 2.1.4 POST /auth/refresh — 刷新Token

Body: refresh_token (string, 必填)

**成功(200)：** 新access_token + refresh_token + expires_in

**错误：** 10008(401) Token过期需重新登录

### 2.1.5 POST /auth/logout — 退出登录

需Bearer Token。**成功(200)：** `{"code":0,"message":"退出成功","data":null}`

---

## 2.2 用户信息模块

### 2.2.1 GET /users/profile — 获取个人信息

需Bearer Token。

**成功(200)：**
```json
{
    "code": 0, "data": {
        "id": 10001, "phone": "138****8000", "nickname": "小明",
        "avatar_url": "https://oss.errorhunter.com/avatar/10001.jpg",
        "grade": "34", "storage_used": 1073741824, "storage_limit": 5368709120,
        "storage_percent": 20.0, "streak_days": 15,
        "review_reminder_time": "19:00", "reminder_enabled": true,
        "mastered_animation": true, "daily_review_limit": 20,
        "created_at": "2026-06-01T10:00:00+08:00"
    }
}
```

### 2.2.2 PATCH /users/profile — 更新个人信息

支持部分更新，所有字段选填：

| 字段 | 类型 | 校验 |
|------|------|------|
| nickname | string | 2-12字符 |
| avatar_url | string | URL, max 512 |
| grade | string | 枚举值 |
| review_reminder_time | string | HH:mm 18:00-22:00 |
| reminder_enabled | bool | - |
| mastered_animation | bool | - |
| daily_review_limit | int | 10/15/20/25/30 |

**成功(200)：** 更新后完整profile对象

**错误：** 10010(400) 昵称不合规, 10011(400) 年级无效

---

## 2.3 错题模块

### 2.3.1 POST /questions — 创建错题

**描述：** 录入新错题（FR-200第三步提交）

| 参数位置 | 字段 | 类型 | 必填 | 校验 |
|---------|------|------|------|------|
| Body | image_url | string | Y | URL, max 512 |
| Body | ocr_text | string | N | max 10000 |
| Body | ocr_confirmed | bool | Y | - |
| Body | my_answer | string | N | max 5000 |
| Body | correct_answer | string | N | max 5000 |
| Body | solution_steps | array | N | JSON数组 |
| Body | error_step_index | int | N | >= 0 |
| Body | error_category | string | Y | KNOWLEDGE/SKILL/PSYCHOLOGY/HABIT/UNKNOWN |
| Body | error_sub_category | string | N | max 32 |
| Body | knowledge_point_ids | int[] | Y | 1-3个元素 |
| Body | custom_tags | string[] | N | 最多5个,每个max 20字符 |

**成功(201)：**
```json
{
    "code": 0, "message": "录入成功，已加入复习计划",
    "data": {
        "id": 50001, "status": "NOT_STARTED",
        "image_url": "https://...?sign=xxx&expire=xxx",
        "ocr_text": "计算：3/4 + 2/3 = ?",
        "error_category": "SKILL", "error_sub_category": "计算错误",
        "review_round": 1, "next_review_date": "2026-06-18",
        "knowledge_points": [{"id": 10, "name": "分数运算", "level": 3}],
        "custom_tags": ["分数", "易错题"],
        "created_at": "2026-06-17T15:30:00+08:00"
    }
}
```

**错误：** 20001(403) 存储满, 20002(400) 知识点超3个, 20003(400) 知识点年级不匹配, 20007(400) 错因必填

### 2.3.2 GET /questions — 错题列表

| Query | 类型 | 必填 | 说明 |
|-------|------|------|------|
| page | int | N | 默认1 |
| page_size | int | N | 1-50, 默认20 |
| status | string | N | 可逗号分隔多选 |
| error_category | string | N | 错因筛选 |
| knowledge_point_id | int | N | 知识点筛选 |
| start_date | string | N | YYYY-MM-DD |
| end_date | string | N | YYYY-MM-DD |
| keyword | string | N | 搜ocr_text, max 100 |
| sort_by | string | N | created_at/updated_at, 默认created_at |
| sort_order | string | N | asc/desc, 默认desc |

**成功(200)：** `{list: [...], pagination: {page, page_size, total}}`

### 2.3.3 GET /questions/:id — 错题详情

Path: id (long)。返回完整错题+review_history+knowledge_points带path。

**错误：** 20004(404) 不存在, 20010(403) 不属于当前用户

### 2.3.4 PATCH /questions/:id — 更新错题

同POST但所有字段选填。knowledge_point_ids和custom_tags为全量替换。

**成功(200)：** 更新后完整对象

### 2.3.5 DELETE /questions/:id — 软删除

**成功(200)：**
```json
{"code":0,"message":"删除成功，30天内可在回收站恢复",
 "data":{"id":50001,"deleted_at":"...","recover_before":"..."}}
```

### 2.3.6 GET /questions/recycle-bin — 回收站列表

Query: page, page_size。每项含days_remaining。

### 2.3.7 POST /questions/recycle-bin/restore — 恢复错题

Body: question_ids (long[], 1-50个)

**成功(200)：** `{"data":{"restored_count":2,"failed_ids":[]}}`

### 2.3.8 DELETE /questions/recycle-bin — 清空回收站

Body: confirm (bool, 必须true)。二次确认(FR-202-6)。

**成功(200)：** `{"data":{"deleted_count":5}}`

**错误：** 20005(400) 未确认

---

## 2.4 复习模块

### 2.4.1 GET /reviews/today — 今日待复习列表

**描述：** 含正常复习+复活检测（FR-400/401/500-4）

**成功(200)：**
```json
{
    "code": 0, "data": {
        "review_items": [
            {"id": 50001, "type": "NORMAL", "image_url": "...", "ocr_text": "...",
             "correct_answer": "17/12", "my_answer": "5/7", "solution_steps": [],
             "error_category": "SKILL", "error_sub_category": "计算错误",
             "review_round": 2,
             "knowledge_points": [{"id": 10, "name": "分数运算"}]}
        ],
        "revive_items": [
            {"id": 48000, "type": "REVIVE_CHECK", "label": "复习巩固",
             "image_url": "...", "ocr_text": "求解一元一次方程：2x+3=7",
             "correct_answer": "x=2", "mastered_at": "...",
             "revive_check_interval": 30}
        ],
        "total_count": 8, "revive_count": 2,
        "has_more": false, "overflow_count": 0
    }
}
```

> review_items按优先级排序(FR-400-5)；revive_items最多3道在列表末尾(FR-500-4a)

### 2.4.2 POST /reviews/complete — 提交复习自评

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | question_id | long | Y | 错题ID |
| Body | self_rating | string | Y | MASTERED/PARTIAL/FAILED |
| Body | review_duration_sec | int | N | 用时秒 |
| Body | is_revive_check | bool | N | 默认false |
| Body | revive_result | string | 条件 | REMEMBERED/FORGOTTEN(复活检测时必填) |

**正常复习(200)：**
```json
{"code":0,"data":{"question_id":50001,"new_status":"REVIEWING",
  "new_review_round":2,"new_master_count":2,"next_review_date":"2026-06-21",
  "just_mastered":false,"streak_days":16}}
```

**消灭触发(200)：** just_mastered=true, total_mastered=51

**复活失败(200)：**
```json
{"code":0,"message":"这道题需要再巩固一下哦！",
 "data":{"question_id":48000,"new_status":"REVIEWING","new_review_round":1,
  "new_master_count":0,"is_revive_failed":true,
  "encourage_message":"这道题需要再巩固一下哦！加油"}}
```

**错误：** 30001(400) 不在复习计划, 30002(400) 无效自评, 30005(409) 今日已完成

### 2.4.3 GET /reviews/revive-check — 复活检测预览

**成功(200)：** `{count, items: [{id, ocr_text, mastered_at, revive_check_interval, check_label}]}`

---

## 2.5 报告模块

### 2.5.1 GET /reports/dashboard — 首页Dashboard

**成功(200)：**
```json
{
    "code": 0, "data": {
        "greeting": {"nickname": "小明", "streak_days": 15},
        "today_task": {"pending_review_count": 8, "has_overflow": false, "overflow_count": 0},
        "statistics": {"total_questions": 156, "mastered_count": 50, "elimination_rate": 32.05},
        "error_distribution": [
            {"category": "SKILL", "label": "技能性错误", "count": 45, "percent": 42.9},
            {"category": "KNOWLEDGE", "label": "知识性错误", "count": 30, "percent": 28.6},
            {"category": "PSYCHOLOGY", "label": "心理性错误", "count": 18, "percent": 17.1},
            {"category": "HABIT", "label": "习惯性错误", "count": 12, "percent": 11.4}
        ],
        "weekly_trend": [
            {"date": "2026-06-11", "new_count": 3, "mastered_count": 2},
            {"date": "2026-06-17", "new_count": 2, "mastered_count": 1}
        ],
        "weak_knowledge_top": [
            {"knowledge_point_id": 10, "name": "分数运算", "unmastered_count": 8,
             "path": "数与代数 > 小数与分数 > 分数运算"}
        ],
        "calendar": {
            "year": 2026, "month": 6,
            "days": {"2026-06-01": {"has_review": true, "has_mastered": false}}
        }
    }
}
```

> error_distribution不包含UNKNOWN类别(FR-300-9)

### 2.5.2 GET /reports/weekly — 周报列表

Query: page, page_size(1-20)。

**成功(200)：** 分页列表含week_number/new/mastered/review_count/accuracy/对比/薄弱知识点

### 2.5.3 GET /reports/weekly/:id — 周报详情

Path: id。额外返回achievements数组和focus_knowledge(含suggestion)。

**错误：** 40001(404) 周报不存在

---

## 2.6 同步模块

### 2.6.1 POST /sync/upload — 批量上传离线数据

**描述：** GR-002-3/4单向上传

| 参数位置 | 字段 | 类型 | 必填 | 说明 |
|---------|------|------|------|------|
| Body | items | array | Y | 1-50个 |
| Body[].local_id | string | Y | UUID |
| Body[].entity_type | string | Y | QUESTION/REVIEW_RECORD |
| Body[].operation | string | Y | CREATE/UPDATE/DELETE |
| Body[].payload | object | Y | 完整实体数据 |

**成功(200)：**
```json
{"code":0,"data":{"results":[
  {"local_id":"uuid-abc","status":"SUCCESS","remote_id":50002},
  {"local_id":"uuid-def","status":"FAILED","error_code":50005,"error_message":"关联错题不存在"}
],"success_count":1,"fail_count":1}}
```

### 2.6.2 GET /sync/status — 同步状态

**成功(200)：** `{pending_count, failed_count, last_sync_at, failed_items:[...]}`

### 2.6.3 POST /sync/retry — 手动重试

Body: sync_ids (long[], 1-10个)

**成功(200)：** `{"data":{"retried_count":1}}`

---

## 2.7 图片模块

### 2.7.1 POST /images/upload-url — 获取OSS上传签名URL

| 参数位置 | 字段 | 类型 | 必填 | 校验 |
|---------|------|------|------|------|
| Body | file_name | string | Y | max 256 |
| Body | content_type | string | Y | image/jpeg,png,heic |
| Body | file_size | long | Y | <= 20971520 (20MB) |
| Body | category | string | Y | QUESTION/AVATAR |

**成功(200)：** `{upload_url, file_url, expires_in: 300}`

**错误：** 60001(400) 超大, 60002(403) 空间不足, 60003(400) 格式不支持

### 2.7.2 GET /images/signed-url — 图片签名访问URL

Query: file_url(必填), expires(60-3600, 默认1800)

**成功(200)：** `{signed_url, expires_in: 1800}`

---

## 2.8 API汇总矩阵

| 模块 | 方法 | 路径 | 认证 | 阶段 | PRD |
|------|------|------|------|------|-----|
| 认证 | POST | /auth/send-code | N | MVP | FR-100/101 |
| 认证 | POST | /auth/register | N | MVP | FR-100 |
| 认证 | POST | /auth/login | N | MVP | FR-101 |
| 认证 | POST | /auth/refresh | N | MVP | FR-001-7 |
| 认证 | POST | /auth/logout | Y | MVP | FR-800 |
| 用户 | GET | /users/profile | Y | MVP | FR-800-1 |
| 用户 | PATCH | /users/profile | Y | MVP | FR-800-1 |
| 错题 | POST | /questions | Y | MVP | FR-200 |
| 错题 | GET | /questions | Y | MVP | 错题本 |
| 错题 | GET | /questions/:id | Y | MVP | FR-201 |
| 错题 | PATCH | /questions/:id | Y | MVP | FR-201 |
| 错题 | DELETE | /questions/:id | Y | MVP | FR-202 |
| 错题 | GET | /questions/recycle-bin | Y | MVP | FR-202-4 |
| 错题 | POST | /questions/recycle-bin/restore | Y | MVP | FR-202-5 |
| 错题 | DELETE | /questions/recycle-bin | Y | MVP | FR-202-5/6 |
| 复习 | GET | /reviews/today | Y | MVP | FR-400/401 |
| 复习 | POST | /reviews/complete | Y | MVP | FR-401 |
| 复习 | GET | /reviews/revive-check | Y | MVP | FR-500-4 |
| 报告 | GET | /reports/dashboard | Y | MVP | FR-600 |
| 报告 | GET | /reports/weekly | Y | MVP | FR-602 |
| 报告 | GET | /reports/weekly/:id | Y | MVP | FR-602-5 |
| 同步 | POST | /sync/upload | Y | MVP | GR-002 |
| 同步 | GET | /sync/status | Y | MVP | GR-002-6 |
| 同步 | POST | /sync/retry | Y | MVP | GR-002-6 |
| 图片 | POST | /images/upload-url | Y | MVP | FR-200 |
| 图片 | GET | /images/signed-url | Y | MVP | NFR-001-4 |

> **共26个API端点，全部MVP范围。** V1.1新增AI分析相关API。

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
