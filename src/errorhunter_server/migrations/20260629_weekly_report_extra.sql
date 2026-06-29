-- =====================================================================
-- 迁移：weekly_reports 新增周报对比/成就相关列
-- 日期：2026-06-29
-- 背景：
--   周报详情页此前三处 TODO 占位（reviewCountVsLastWeek / accuracyRateVsLastWeek
--   / achievements），后端 WeeklyReport 模型未存上周复习次数、上周正确率、
--   及本周成就列表。现补三列：
--     prev_week_review_count  上周复习次数（取上周周报行，无则 NULL）
--     prev_week_accuracy      上周复习正确率(%)(取上周周报行，无则 NULL)
--     achievements            本周成就文案列表 JSONB []string（默认空数组）
--
--   新库（deploy/init-db.sql / deploy/docker/init-db.sql）已直接建这三列，
--   本脚本仅用于已存在的存量库补列。
--
-- 存量数据：
--   prev_week_review_count / prev_week_accuracy：存量已生成的周报行该列默认
--     NULL（前端据此显示「持平 vs 上周」，与无上周周报一致）。下周起定时任务
--     新生成的周报才会写入真实上周值。可接受，不回填。
--   achievements：存量行默认 '[]'（空数组，前端显示「本周暂无成就」）。
--     下周起定时任务新生成的周报才会写入真实成就列表。可接受，不回填。
--
-- 执行方式：手动 psql 执行
--   psql -U <user> -d <db> -f migrations/20260629_weekly_report_extra.sql
--
-- 回滚：
--   ALTER TABLE weekly_reports
--       DROP COLUMN IF EXISTS prev_week_review_count,
--       DROP COLUMN IF EXISTS prev_week_accuracy,
--       DROP COLUMN IF EXISTS achievements;
-- =====================================================================

BEGIN;

ALTER TABLE weekly_reports
    ADD COLUMN IF NOT EXISTS prev_week_review_count INTEGER;

ALTER TABLE weekly_reports
    ADD COLUMN IF NOT EXISTS prev_week_accuracy DECIMAL(5,2);

ALTER TABLE weekly_reports
    ADD COLUMN IF NOT EXISTS achievements JSONB DEFAULT '[]';

COMMENT ON COLUMN weekly_reports.prev_week_review_count IS '上周复习次数(取上周周报行)';
COMMENT ON COLUMN weekly_reports.prev_week_accuracy IS '上周复习正确率(%)(取上周周报行)';
COMMENT ON COLUMN weekly_reports.achievements IS '本周成就文案列表JSON数组[]string';

-- 存量行 achievements 可能为 NULL（若该列以无默认方式补过），统一兜底为 '[]'
UPDATE weekly_reports
   SET achievements = '[]'
 WHERE achievements IS NULL;

COMMIT;
