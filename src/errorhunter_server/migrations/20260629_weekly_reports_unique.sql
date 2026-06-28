-- =====================================================================
-- 迁移：weekly_reports 新增 (user_id, week_start) 唯一约束
-- 日期：2026-06-29
-- 背景：
--   周报定时生成任务按 (user_id, week_start) 查重做幂等。原表仅有
--   (user_id, week_number) 唯一约束（uk_report_user_week）。
--   week_number 为 ISO 周数 year*100+week，理论上与 week_start 一一对应，
--   但为对齐生成逻辑的查重键、防止边界口径不一致导致重复行，显式再加
--   (user_id, week_start) 唯一约束，作为生成的强保证。
--
--   新库（deploy/init-db.sql / deploy/docker/init-db.sql）已直接建该约束，
--   本脚本仅用于已存在的存量库补约束。
--
-- 执行方式：手动 psql 执行
--   psql -U <user> -d <db> -f migrations/20260629_weekly_reports_unique.sql
--
-- 回滚：
--   ALTER TABLE weekly_reports DROP CONSTRAINT IF EXISTS uk_report_user_week_start;
-- =====================================================================

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uk_report_user_week_start'
          AND conrelid = 'weekly_reports'::regclass
    ) THEN
        ALTER TABLE weekly_reports
            ADD CONSTRAINT uk_report_user_week_start UNIQUE (user_id, week_start);
    END IF;
END $$;

COMMIT;
