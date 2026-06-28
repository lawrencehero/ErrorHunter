-- =====================================================================
-- 迁移：weekly_reports 新增 top_error_category_percentage 列
-- 日期：2026-06-29
-- 背景：
--   周报详情页"本周最多错因"占比前端原硬编码 0.0，后端 WeeklyReport
--   模型也未存该百分比字段。现于生成周报时计算 top error_category 计数
--   占本周新建错题总数的比例(%)，落库为本列，前端读取真实值。
--
--   新库（deploy/init-db.sql / deploy/docker/init-db.sql）已直接建该列，
--   本脚本仅用于已存在的存量库补列。
--
-- 存量数据：
--   存量已生成的周报行该列默认 0.00（即占比显示 0.0%）。
--   下周起定时任务新生成的周报才会写入真实占比。可接受，不回填。
--   若需回填历史行，需按各行 week_start/week_end 重新统计本周新建错题
--   分布，复杂度较高，暂不做。
--
-- 执行方式：手动 psql 执行
--   psql -U <user> -d <db> -f migrations/20260629_weekly_reports_top_pct.sql
--
-- 回滚：
--   ALTER TABLE weekly_reports DROP COLUMN IF EXISTS top_error_category_percentage;
-- =====================================================================

BEGIN;

ALTER TABLE weekly_reports
    ADD COLUMN IF NOT EXISTS top_error_category_percentage DECIMAL(5,2) NOT NULL DEFAULT 0.00;

COMMENT ON COLUMN weekly_reports.top_error_category_percentage IS '本周最多错因占新建错题比例(%)';

COMMIT;
