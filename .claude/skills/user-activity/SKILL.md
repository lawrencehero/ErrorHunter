---
name: user-activity
description: 查询 ErrorHunter 用户学习活动记录。支持单用户明细（错题统计、今日待复习、最近复习、打卡连击、周报、同步队列）和全局概览（所有用户活跃度、待复习积压、同步积压、长期未活跃用户），直连 PostgreSQL 查库，无需用户 token
---

# 查询用户活动记录

直连 PostgreSQL 查询用户学习活动。两种模式：
- **单用户明细**：按手机号或 user_id 查某个用户的当前活动状态。用于客服排查、定位问题用户。
- **全局概览**：查所有用户的活跃度与积压情况。用于 PM 看整体健康度、发现异常用户。

## 入参

$ARGUMENTS

- 手机号（11 位）：`REDACTED_PHONE` → 单用户明细
- user_id（纯数字）：`42` → 单用户明细
- `all` 或留空：→ 全局概览
- 任意模式后可附加 `prod` 查生产库，默认查本地开发库。例：`/user-activity all prod`、`/user-activity REDACTED_PHONE prod`

## 执行方式

> 本地 Windows 无 `psql` 客户端，且生产 postgres 容器 5432 未映射到宿主，**不能直连**。统一通过 SSH 在容器内执行 psql。

### 环境

| 环境 | 怎么连 | 凭据 |
|------|--------|------|
| 本地（默认） | SSH 到生产机后连本地？否。本地库需本机自己跑 docker 或装 psql。**默认走生产库**——开发库基本不在线，日常排查都查生产 | 生产：容器内 `PGPASSWORD` 已设，无需传 |
| 生产（带 `prod` 或默认） | `ssh` 到 47.108.190.116，`docker exec` 进 `errorhunter-postgres` 容器跑 psql | host=容器名、user=`errorhunter`、db=`errorhunter` |

SSH 私钥：`D:/aliyun/ecs-Docker-dtxf.pem`，root 登录。

> **默认就查生产**。除非用户显式说"查本地"，否则按生产库执行。涉及真实用户数据，只读查询。

### 命令模板（生产）

**单条 SQL**（外层双引号，SQL 内字符串用单引号；SQL 内若出现双引号需 `\"` 转义）：

```bash
ssh -i D:/aliyun/ecs-Docker-dtxf.pem -o StrictHostKeyChecking=no root@47.108.190.116 "docker exec errorhunter-postgres psql -U errorhunter -d errorhunter -c \"<把SQL放这里>\""
```

**多条 SQL**（推荐——避免引号地狱，且一次拿全）：把 SQL 写到一个临时 `.sql` 文件，用 `\echo === 段名 ===` 分段，通过 stdin 喂给容器内 psql：

```bash
ssh -i D:/aliyun/ecs-Docker-dtxf.pem -o StrictHostKeyChecking=no root@47.108.190.116 "docker exec -i errorhunter-postgres psql -U errorhunter -d errorhunter" < <临时sql文件路径>
```

执行完删除临时文件。所有 SQL 都是**只读 SELECT**。

## 执行步骤

> 先判定模式：入参含 `all` 或为空 → 走【全局概览】；含手机号/user_id → 走【单用户明细】。

### 模式 A：单用户明细

#### 1. 解析 user_id

按手机号或 user_id 查用户基本信息（用单条 SQL 模板）：

```sql
SELECT id, phone, nickname, grade, streak_days, last_active_at, last_review_date, storage_used, storage_limit, created_at FROM users WHERE phone='REDACTED_PHONE' AND deleted_at IS NULL;
-- 或 WHERE id=42
```

记下返回的 `id` 作为后续 `<UID>`。若查不到，**直接报告"用户不存在"并停止**。

#### 2–6. 一次性跑完剩余查询

拿到 `<UID>` 后，把下面 5 段 SQL 写进一个临时 `.sql` 文件，用「多条 SQL」模板一次执行：

```sql
\echo === QUESTION_STATUS ===
SELECT status, COUNT(*) FROM questions WHERE user_id=<UID> AND deleted_at IS NULL GROUP BY status ORDER BY status;

\echo === DUE_TODAY ===
SELECT id, status, next_review_date, review_round, master_count FROM questions WHERE user_id=<UID> AND deleted_at IS NULL AND status='REVIEWING' AND next_review_date <= CURRENT_DATE ORDER BY next_review_date;

\echo === RECENT_REVIEWS ===
SELECT id, question_id, review_round, self_rating, master_count_after, reviewed_at FROM review_records WHERE user_id=<UID> ORDER BY reviewed_at DESC LIMIT 10;

\echo === WEEKLY ===
SELECT week_number, week_start, week_end, new_questions, mastered_questions, review_count, review_accuracy, top_error_category FROM weekly_reports WHERE user_id=<UID> ORDER BY week_start DESC LIMIT 1;

\echo === SYNC ===
SELECT status, COUNT(*) FROM sync_queue WHERE user_id=<UID> GROUP BY status;
```

状态含义：`NOT_STARTED` 未开始 / `REVIEWING` 复习中 / `MASTERED` 已掌握 / `PERMANENTLY_MASTERED` 永久掌握。同步队列重点看 `PENDING` / `FAILED`，>0 说明客户端有未同步操作或同步失败。

### 模式 B：全局概览

把下面 5 段 SQL 写进一个临时 `.sql` 文件，用「多条 SQL」模板一次执行：

```sql
\echo === OVERVIEW ===
SELECT COUNT(*) AS total_users, COUNT(*) FILTER (WHERE last_active_at > NOW() - INTERVAL '7 days') AS active_7d, COUNT(*) FILTER (WHERE last_active_at > NOW() - INTERVAL '1 day') AS active_1d, COUNT(*) FILTER (WHERE last_review_date = CURRENT_DATE) AS reviewed_today FROM users WHERE deleted_at IS NULL;

\echo === USERS ===
SELECT u.id, u.nickname, u.grade, u.streak_days, u.last_active_at, u.last_review_date, COUNT(q.id) FILTER (WHERE q.deleted_at IS NULL) AS total_questions, COUNT(q.id) FILTER (WHERE q.deleted_at IS NULL AND q.status='REVIEWING' AND q.next_review_date <= CURRENT_DATE) AS due_today, COUNT(q.id) FILTER (WHERE q.deleted_at IS NULL AND q.status='MASTERED') AS mastered FROM users u LEFT JOIN questions q ON q.user_id = u.id WHERE u.deleted_at IS NULL GROUP BY u.id ORDER BY u.last_active_at DESC NULLS LAST LIMIT 50;

\echo === DUE_TOP ===
SELECT u.id, u.nickname, COUNT(*) AS due_today FROM questions q JOIN users u ON u.id = q.user_id WHERE q.deleted_at IS NULL AND q.status='REVIEWING' AND q.next_review_date <= CURRENT_DATE GROUP BY u.id, u.nickname ORDER BY due_today DESC LIMIT 10;

\echo === SYNC_BACKLOG ===
SELECT u.id, u.nickname, s.status, COUNT(*) AS cnt FROM sync_queue s JOIN users u ON u.id = s.user_id WHERE s.status IN ('PENDING','FAILED') GROUP BY u.id, u.nickname, s.status ORDER BY cnt DESC LIMIT 20;

\echo === INACTIVE ===
SELECT u.id, u.nickname, u.last_active_at, COUNT(q.id) AS questions FROM users u JOIN questions q ON q.user_id = u.id AND q.deleted_at IS NULL WHERE u.deleted_at IS NULL AND (u.last_active_at IS NULL OR u.last_active_at < NOW() - INTERVAL '14 days') GROUP BY u.id, u.nickname, u.last_active_at ORDER BY u.last_active_at NULLS FIRST LIMIT 20;
```

## 汇总报告格式

### 单用户明细

用 👤【用户活动】开头，按以下结构输出（数字均为当前真实数据，不要编造）：

```
👤【用户活动】<昵称或手机号脱敏> (id=<UID>, grade=<年级>)

• 活跃：last_active_at=<时间>，last_review_date=<日期>，streak_days=<连击>
• 存储：<已用>/<上限> MB
• 错题分布：NOT_STARTED=.. REVIEWING=.. MASTERED=.. PERMANENTLY_MASTERED=..（共 ..）
• 今日待复习：.. 道（最早到期 <日期>）
• 最近复习：最近一次 <reviewed_at>，rating=<SELF_RATING>，已掌握 .. 题
• 本周周报：第..周，新增..道，掌握..道，复习..次，准确率..%，首要错因=<..>
• 同步队列：PENDING=.. FAILED=..
```

末尾用一句话给结论：用户当前是否健康（如"待复习积压 0，活跃正常" / "已 X 天未活跃，待复习积压 Y 道，建议推送提醒"）。

### 全局概览

用 📊【用户活动·全局】开头，按以下结构输出：

```
📊【用户活动·全局】

• 用户总数：..（近 1 天活跃 ..，近 7 天活跃 ..，今日已复习 ..）
• 待复习积压 TOP：用户A=..道 / 用户B=..道 / ...（共 .. 个用户有积压，合计 .. 道）
• 同步积压：PENDING 共 .. 条（.. 个用户），FAILED 共 .. 条（.. 个用户）
• 长期未活跃(>14天)且有错题：.. 个用户，最早 <last_active_at>
```

末尾给整体结论，例如"整体健康，无积压" / "X 个用户待复习积压严重，Y 个用户长期未活跃建议召回"。

## 规则

1. 所有数字必须来自上面 SQL 的真实返回，不要凭推断
2. 手机号在报告里脱敏显示（前 3 + **** + 后 4）
3. 查不到用户或某项无数据，如实写"无"，不要省略该行
4. 默认查生产库；只读查询，绝不执行任何 INSERT/UPDATE/DELETE
5. 全局模式不要逐个遍历所有用户——用聚合 SQL 一次性出结果，列表类查询一律加 `LIMIT`
6. 临时 SQL 文件用完即删，不要留在仓库里
7. SSH 输出开头的 post-quantum 警告是噪音，忽略即可
