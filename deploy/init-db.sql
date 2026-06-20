-- ============================================================
-- 错题猎手（ErrorHunter）数据库初始化脚本
-- 说明：此脚本在 PostgreSQL 容器首次启动时自动执行
-- 包含：枚举类型 + 表结构 + 索引 + 基础数据 + 测试数据库
-- ============================================================

-- ==================== 枚举类型 ====================

CREATE TYPE grade_enum AS ENUM (
    '31',  -- 小学三年级
    '32',  -- 小学四年级
    '33',  -- 小学五年级
    '34',  -- 小学六年级
    '71',  -- 初中一年级
    '72',  -- 初中二年级
    '73'   -- 初中三年级
);

CREATE TYPE question_status_enum AS ENUM (
    'NOT_STARTED',
    'REVIEWING',
    'MASTERED',
    'PERMANENTLY_MASTERED'
);

CREATE TYPE error_category_enum AS ENUM (
    'KNOWLEDGE',
    'SKILL',
    'PSYCHOLOGY',
    'HABIT',
    'UNKNOWN'
);

CREATE TYPE self_rating_enum AS ENUM (
    'MASTERED',
    'PARTIAL',
    'FAILED'
);

CREATE TYPE stage_enum AS ENUM (
    'PRIMARY',
    'JUNIOR'
);

CREATE TYPE sync_operation_enum AS ENUM (
    'CREATE',
    'UPDATE',
    'DELETE'
);

CREATE TYPE sync_status_enum AS ENUM (
    'PENDING',
    'UPLOADING',
    'SUCCESS',
    'FAILED'
);

CREATE TYPE device_type_enum AS ENUM (
    'IOS',
    'ANDROID'
);

-- ==================== 表结构 ====================

-- users 用户表
CREATE TABLE IF NOT EXISTS users (
    id                   BIGSERIAL PRIMARY KEY,
    phone                VARCHAR(11)    NOT NULL,
    nickname             VARCHAR(24),
    avatar_url           VARCHAR(512),
    grade                grade_enum     NOT NULL,
    storage_used         BIGINT         NOT NULL DEFAULT 0,
    storage_limit        BIGINT         NOT NULL DEFAULT 5368709120,
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

-- questions 错题表
CREATE TABLE IF NOT EXISTS questions (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT              NOT NULL,
    status                  question_status_enum NOT NULL DEFAULT 'NOT_STARTED',
    image_url               VARCHAR(512)        NOT NULL,
    ocr_text                TEXT,
    ocr_confirmed           BOOLEAN             NOT NULL DEFAULT FALSE,
    my_answer               TEXT,
    correct_answer          TEXT,
    solution_steps          JSONB,
    error_step_index        INT,
    error_category          error_category_enum NOT NULL,
    error_sub_category      VARCHAR(32),
    custom_tags             JSONB,
    master_count            INT                 NOT NULL DEFAULT 0,
    review_round            INT                 NOT NULL DEFAULT 1,
    next_review_date        DATE                NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 day'),
    mastered_at             TIMESTAMPTZ,
    revive_check_date       DATE,
    revive_check_interval   INT                 DEFAULT 30,
    ai_error_analysis       TEXT,
    ai_knowledge_gaps       JSONB,
    ai_suggested_exercises  JSONB,
    ai_analyzed_at          TIMESTAMPTZ,
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

-- review_records 复习记录表
CREATE TABLE IF NOT EXISTS review_records (
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

COMMENT ON TABLE review_records IS '复习记录表';

-- knowledge_points 知识点表
CREATE TABLE IF NOT EXISTS knowledge_points (
    id          SERIAL PRIMARY KEY,
    parent_id   INT,
    name        VARCHAR(64)  NOT NULL,
    level       SMALLINT     NOT NULL,
    stage       stage_enum   NOT NULL,
    keywords    JSONB,
    sort_order  INT          NOT NULL DEFAULT 0,
    version     VARCHAR(16)  NOT NULL DEFAULT '2026A',

    CONSTRAINT fk_kp_parent FOREIGN KEY (parent_id) REFERENCES knowledge_points(id),
    CONSTRAINT chk_kp_level CHECK (level BETWEEN 1 AND 3),
    CONSTRAINT chk_kp_sort CHECK (sort_order >= 0),
    CONSTRAINT uk_kp_parent_name_ver UNIQUE (parent_id, name, version)
);

COMMENT ON TABLE knowledge_points IS '知识点树表';

-- question_knowledge 关联表
CREATE TABLE IF NOT EXISTS question_knowledge (
    question_id        BIGINT NOT NULL,
    knowledge_point_id INT    NOT NULL,

    CONSTRAINT pk_qk PRIMARY KEY (question_id, knowledge_point_id),
    CONSTRAINT fk_qk_question FOREIGN KEY (question_id) REFERENCES questions(id),
    CONSTRAINT fk_qk_kp FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points(id)
);

-- weekly_reports 周报表
CREATE TABLE IF NOT EXISTS weekly_reports (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT         NOT NULL,
    week_number         INT            NOT NULL,
    week_start          DATE           NOT NULL,
    week_end            DATE           NOT NULL,
    new_questions       INT            NOT NULL DEFAULT 0,
    mastered_questions  INT            NOT NULL DEFAULT 0,
    review_count        INT            NOT NULL DEFAULT 0,
    review_accuracy     DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
    prev_week_new       INT,
    prev_week_mastered  INT,
    top_error_category  error_category_enum,
    weak_knowledge_top  JSONB,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_report_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uk_report_user_week UNIQUE (user_id, week_number),
    CONSTRAINT chk_rpt_dates CHECK (week_end > week_start),
    CONSTRAINT chk_rpt_accuracy CHECK (review_accuracy BETWEEN 0 AND 100),
    CONSTRAINT chk_rpt_counts CHECK (
        new_questions >= 0 AND mastered_questions >= 0 AND review_count >= 0
    )
);

COMMENT ON TABLE weekly_reports IS '学情周报表';

-- sync_queue 同步队列表
CREATE TABLE IF NOT EXISTS sync_queue (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT             NOT NULL,
    entity_type     VARCHAR(16)        NOT NULL,
    entity_id       VARCHAR(64),
    operation       sync_operation_enum NOT NULL,
    payload         JSONB              NOT NULL,
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

COMMENT ON TABLE sync_queue IS '离线同步队列';

-- user_devices 设备表
CREATE TABLE IF NOT EXISTS user_devices (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT           NOT NULL,
    device_name    VARCHAR(64)      NOT NULL,
    device_type    device_type_enum NOT NULL,
    push_token     VARCHAR(256),
    last_login_at  TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    created_at     TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_device_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uk_device_user_push UNIQUE (user_id, push_token)
);

COMMENT ON TABLE user_devices IS '设备管理表';

-- ==================== 索引 ====================

CREATE INDEX IF NOT EXISTS idx_users_last_active ON users(last_active_at) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_questions_user_status ON questions(user_id, status)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_questions_user_next_review ON questions(user_id, next_review_date)
    WHERE deleted_at IS NULL AND status IN ('NOT_STARTED', 'REVIEWING');
CREATE INDEX IF NOT EXISTS idx_questions_user_category ON questions(user_id, error_category)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_questions_user_created ON questions(user_id, created_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_questions_revive_check ON questions(mastered_at, revive_check_date)
    WHERE deleted_at IS NULL AND status = 'MASTERED';
CREATE INDEX IF NOT EXISTS idx_questions_deleted_expired ON questions(deleted_at)
    WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_questions_user_stats ON questions(user_id, status, error_category)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_review_user_date ON review_records(user_id, reviewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_review_question ON review_records(question_id, reviewed_at DESC);
-- 注：reviewed_at::date 索引因 timezone 转换非 IMMUTABLE 而跳过
-- 应用层可按 reviewed_at 范围查询替代
-- CREATE INDEX IF NOT EXISTS idx_review_user_date_only ON review_records(user_id, (reviewed_at::date));

CREATE INDEX IF NOT EXISTS idx_kp_stage_level ON knowledge_points(stage, level, sort_order);
CREATE INDEX IF NOT EXISTS idx_kp_parent ON knowledge_points(parent_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_qk_kp ON question_knowledge(knowledge_point_id);

CREATE INDEX IF NOT EXISTS idx_report_user_created ON weekly_reports(user_id, week_number DESC);

-- 注：部分索引条件含 NOW() 非 IMMUTABLE，改为不含时间条件的部分索引
CREATE INDEX IF NOT EXISTS idx_sync_pending ON sync_queue(user_id, created_at)
    WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX IF NOT EXISTS idx_sync_user_status ON sync_queue(user_id, status);

CREATE INDEX IF NOT EXISTS idx_device_user_login ON user_devices(user_id, last_login_at DESC);

-- ==================== 基础知识点数据 ====================

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

-- 二级知识点（数与代数 -> parent_id=1）
INSERT INTO knowledge_points (parent_id, name, level, stage, keywords, sort_order, version) VALUES
(1, '整数运算', 2, 'PRIMARY', '["整数","加减","乘除","四则运算"]'::jsonb, 1, '2026A'),
(1, '小数与分数', 2, 'PRIMARY', '["小数","分数","通分","约分"]'::jsonb, 2, '2026A'),
(1, '比与比例', 2, 'PRIMARY', '["比","比例","百分数"]'::jsonb, 3, '2026A'),
(1, '简易方程', 2, 'PRIMARY', '["方程","未知数","等式"]'::jsonb, 4, '2026A');

-- 三级知识点
INSERT INTO knowledge_points (parent_id, name, level, stage, keywords, sort_order, version) VALUES
(11, '加减法', 3, 'PRIMARY', '["加法","减法","进位","退位"]'::jsonb, 1, '2026A'),
(11, '乘除法', 3, 'PRIMARY', '["乘法","除法","乘法表","余数"]'::jsonb, 2, '2026A'),
(12, '小数运算', 3, 'PRIMARY', '["小数","加减","乘除","小数点"]'::jsonb, 1, '2026A'),
(12, '分数运算', 3, 'PRIMARY', '["分数","通分","约分","分子","分母"]'::jsonb, 2, '2026A'),
(12, '小数分数互化', 3, 'PRIMARY', '["互化","转换","小数","分数"]'::jsonb, 3, '2026A');
