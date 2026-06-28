-- =====================================================================
-- 迁移：sub_categories 由单值迁移为多值（JSONB 存 []string）
-- 日期：2026-06-28
-- 背景：
--   前端细分错因 UI 为多选，QuestionModel.subCategories 是 List<String>，
--   从Json 读 sub_categories（列表）、toJson 写 sub_categories（列表）。
--   后端旧字段 error_sub_category VARCHAR(32) 为单值，键名+结构均不匹配，
--   导致录入的细分错因存不下、读不出。
--   本次将后端对齐前端多值契约。
--
-- 适用：已存在 questions.error_sub_category 列的存量库。
--       新库（deploy/init-db.sql / deploy/docker/init-db.sql）已直接建
--       sub_categories JSONB，无需执行本脚本。
--
-- 执行方式：手动 psql 执行
--   psql -U <user> -d <db> -f migrations/20260628_sub_categories_multi.sql
--
-- 回滚（执行前可参考，执行后需手动逆操作）：
--   ALTER TABLE questions ADD COLUMN error_sub_category VARCHAR(32);
--   UPDATE questions SET error_sub_category = sub_categories->>0
--     WHERE sub_categories IS NOT NULL AND sub_categories <> '[]'::jsonb;
--   ALTER TABLE questions DROP COLUMN sub_categories;
-- =====================================================================

BEGIN;

-- 1) 新增多值列（默认空数组，与前端多选清空语义一致）
ALTER TABLE questions ADD COLUMN IF NOT EXISTS sub_categories JSONB DEFAULT '[]';

-- 2) 回填：旧单值 → 单元素数组 ["旧值"]；空串与 NULL 保持为 []
UPDATE questions
   SET sub_categories = jsonb_build_array(error_sub_category)
 WHERE error_sub_category IS NOT NULL
   AND error_sub_category <> '';

-- 3) 删除旧单值列
ALTER TABLE questions DROP COLUMN IF EXISTS error_sub_category;

COMMIT;
