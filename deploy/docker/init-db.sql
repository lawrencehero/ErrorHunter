-- ============================================================
-- 错题猎手（ErrorHunter）数据库初始化脚本
-- 基于：docs/04-技术设计/技术设计-Part1-数据库与API.md
-- 说明：此脚本在 PostgreSQL 容器首次启动时自动执行
-- ============================================================

-- ==================== 枚举类型 ====================

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

-- 错题状态枚举
CREATE TYPE question_status_enum AS ENUM (
    'NOT_STARTED',          -- 未掌握
    'REVIEWING',            -- 复习中
    'MASTERED',             -- 已消灭
    'PERMANENTLY_MASTERED'  -- 永久消灭（通过90天复活检测）
);

-- 错因粗分类枚举
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

-- ==================== 表结构 ====================

-- users 用户表
CREATE TABLE users (
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
COMMENT ON COLUMN users.grade IS '年级：31-34=小学, 71-73=初中';
COMMENT ON COLUMN users.storage_limit IS '存储上限，默认5GB（字节）';
COMMENT ON COLUMN users.daily_review_limit IS '每日复习上限，默认20，范围10-30';
COMMENT ON COLUMN users.deleted_at IS '注销时间，非NULL表示账号已注销';

-- questions 错题表
CREATE TABLE questions (
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

    -- AI预留字段（V1.1，MVP阶段均为NULL）
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
COMMENT ON COLUMN questions.status IS '状态：NOT_STARTED/REVIEWING/MASTERED/PERMANENTLY_MASTERED';
COMMENT ON COLUMN questions.solution_steps IS '解题步骤JSON数组，error_step_index标记出错步骤';
COMMENT ON COLUMN questions.master_count IS '连续掌握计数(0-3)，达到3时触发消灭';
COMMENT ON COLUMN questions.review_round IS '当前复习轮次(1-5)';
COMMENT ON COLUMN questions.revive_check_interval IS '复活检测间隔天数：30->60->90递进';

-- review_records 复习记录表
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

-- knowledge_points 知识点表
CREATE TABLE knowledge_points (
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

COMMENT ON TABLE knowledge_points IS '知识点树表，支持多级结构和版本管理';
COMMENT ON COLUMN knowledge_points.level IS '层级：1=一级, 2=二级, 3=三级知识点';
COMMENT ON COLUMN knowledge_points.keywords IS '关键词JSON数组，用于AI规则匹配推荐';
COMMENT ON COLUMN knowledge_points.version IS '版本号如2026A，支持每学期更新';

-- question_knowledge 错题-知识点关联表（M:N）
CREATE TABLE question_knowledge (
    question_id        BIGINT NOT NULL,
    knowledge_point_id INT    NOT NULL,

    CONSTRAINT pk_qk PRIMARY KEY (question_id, knowledge_point_id),
    CONSTRAINT fk_qk_question FOREIGN KEY (question_id) REFERENCES questions(id),
    CONSTRAINT fk_qk_kp FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points(id)
);

COMMENT ON TABLE question_knowledge IS '错题与知识点的多对多关联表';

-- weekly_reports 学情周报表
CREATE TABLE weekly_reports (
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

COMMENT ON TABLE weekly_reports IS '学情周报表，每周日20:00自动生成';
COMMENT ON COLUMN weekly_reports.week_number IS '周编号YYYYWW';
COMMENT ON COLUMN weekly_reports.review_accuracy IS '本周复习正确率(%)';
COMMENT ON COLUMN weekly_reports.weak_knowledge_top IS '薄弱知识点TOP3 JSON数组';

-- sync_queue 离线同步队列表
CREATE TABLE sync_queue (
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

COMMENT ON TABLE sync_queue IS '离线同步队列，支持GR-002单向上传';
COMMENT ON COLUMN sync_queue.entity_type IS '实体类型：QUESTION/REVIEW_RECORD';
COMMENT ON COLUMN sync_queue.payload IS '完整实体数据JSON';
COMMENT ON COLUMN sync_queue.retry_count IS '重试次数，最多3次，指数退避(1s->2s->4s)';

-- user_devices 设备管理表
CREATE TABLE user_devices (
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

COMMENT ON TABLE user_devices IS '设备管理表，每用户最多3台（FR-001-5）';
COMMENT ON COLUMN user_devices.push_token IS '推送token，用于APNs/FCM';
COMMENT ON COLUMN user_devices.last_login_at IS '最后登录时间，踢设备依据';

-- ==================== 索引 ====================

-- users
CREATE INDEX idx_users_last_active ON users(last_active_at) WHERE deleted_at IS NULL;

-- questions
CREATE INDEX idx_questions_user_status ON questions(user_id, status)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_questions_user_next_review ON questions(user_id, next_review_date)
    WHERE deleted_at IS NULL AND status IN ('NOT_STARTED', 'REVIEWING');
CREATE INDEX idx_questions_user_category ON questions(user_id, error_category)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_questions_user_created ON questions(user_id, created_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_questions_revive_check ON questions(mastered_at, revive_check_date)
    WHERE deleted_at IS NULL AND status = 'MASTERED';
CREATE INDEX idx_questions_deleted_expired ON questions(deleted_at)
    WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_questions_user_stats ON questions(user_id, status, error_category)
    WHERE deleted_at IS NULL;

-- review_records
CREATE INDEX idx_review_user_date ON review_records(user_id, reviewed_at DESC);
CREATE INDEX idx_review_question ON review_records(question_id, reviewed_at DESC);
CREATE INDEX idx_review_user_date_only ON review_records(user_id, (reviewed_at::date));

-- knowledge_points
CREATE INDEX idx_kp_stage_level ON knowledge_points(stage, level, sort_order);
CREATE INDEX idx_kp_parent ON knowledge_points(parent_id, sort_order);

-- question_knowledge
CREATE INDEX idx_qk_kp ON question_knowledge(knowledge_point_id);

-- weekly_reports
CREATE INDEX idx_report_user_created ON weekly_reports(user_id, week_number DESC);

-- sync_queue
CREATE INDEX idx_sync_pending ON sync_queue(user_id, created_at)
    WHERE status IN ('PENDING', 'FAILED') AND next_retry_at <= NOW();
CREATE INDEX idx_sync_user_status ON sync_queue(user_id, status);

-- user_devices
CREATE INDEX idx_device_user_login ON user_devices(user_id, last_login_at DESC);

-- ==================== 基础数据 ====================

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
(11, '加减法', 3, 'PRIMARY', '["加法","减法","进位","退位"]'::jsonb, 1, '2026A'),
(11, '乘除法', 3, 'PRIMARY', '["乘法","除法","乘法表","余数"]'::jsonb, 2, '2026A'),
(12, '小数运算', 3, 'PRIMARY', '["小数","加减","乘除","小数点"]'::jsonb, 1, '2026A'),
(12, '分数运算', 3, 'PRIMARY', '["分数","通分","约分","分子","分母"]'::jsonb, 2, '2026A'),
(12, '小数分数互化', 3, 'PRIMARY', '["互化","转换","小数","分数"]'::jsonb, 3, '2026A');

-- 注意：完整知识点树由教研团队整理后以JSON格式批量导入
