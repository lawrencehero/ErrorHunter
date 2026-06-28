-- =====================================================================
-- 迁移：users 新增 last_review_date DATE 列，用于 streak 判断
-- 日期：2026-06-28
-- 背景：
--   上一轮 UpdateStreakOnActivity 用 last_active_at 判断"今天是否已打卡"，
--   但登录（auth_service.go UpdateLastActive）也会更新 last_active_at，
--   导致用户登录后首次复习时 last_active_at 已是今天 → CASE 命中"今天已活跃"
--   → streak 不递增，恒为 0。
--   实测：后端 23:41 重启后，23:42 一次复习把 last_active_at 更新到 23:42:15，
--   但 streak_days 仍为 0。
--
--   新增 last_review_date 列：只由复习（UpdateStreakOnActivity）更新，
--   登录不动它，从而彻底隔离"登录活跃"与"复习打卡"两种语义。
--
-- 回填策略：不从 last_active_at 回填（它已被登录污染，无法区分登录与复习）。
--           列默认 NULL，streak 在用户下次复习时按 CASE 重算即可：
--             NULL → ELSE 分支 → streak = 1。
--
-- 适用：已存在 users 表的存量库。
--       新库（deploy/init-db.sql / deploy/docker/init-db.sql）已直接建
--       last_review_date DATE，无需执行本脚本。
--
-- 执行方式：手动 psql 执行
--   psql -U <user> -d <db> -f migrations/20260628_users_last_review_date.sql
--
-- 回滚：
--   ALTER TABLE users DROP COLUMN IF EXISTS last_review_date;
--   （注意：回滚后 UpdateStreakOnActivity 的 SQL 将引用不存在的列而失败，
--    需同时回滚 user_repository.go 至旧版本。）
-- =====================================================================

BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_review_date DATE;

COMMIT;
