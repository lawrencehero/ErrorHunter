# 🧪 错题猎手 V1.0 — P0 冒烟测试报告

```
┌──────────────────────────────────────────────────┐
│                  文档信息                          │
├──────────────┬───────────────────────────────────┤
│ 文档名称      │ P0 冒烟测试报告                    │
│ 所属产品      │ 错题猎手（ErrorHunter）V1.0         │
│ 文档版本      │ V1.0                              │
│ 编写人        │ @QA（赵测）                        │
│ 测试日期      │ 2026-06-20                        │
│ 测试方式      │ 代码审查 + 单元测试执行              │
│ 上游输入      │ test-cases-V1.1.md                │
│              │ PRD-错题猎手-V1.0.md               │
│ 测试环境      │ Windows / WSL, Go 1.x, Flutter    │
│ 结论          │ ⛔ 未通过 — 3个P0 Bug未修复         │
└──────────────┴───────────────────────────────────┘
```

---

## 一、已知 Bug 验证状态（10 个）

### 总结

| 状态 | 数量 | Bug ID |
|------|------|--------|
| ✅ 已修复 | 2 | BUG-004, BUG-008 |
| ❌ 未修复 | 3 | **BUG-002, BUG-003, BUG-005** |
| ⚠️ 部分修复 | 2 | BUG-007, BUG-010 |
| 🔍 无法完全验证 | 3 | BUG-001, BUG-006, BUG-009 |

### 逐项详情

#### BUG-001 (P0): POST /v1/questions 返回 500（GORM many2many 外键约束）

**验证状态：🔍 无法完全验证（代码层面有风险）**

**证据：**
- `model.go:158` 定义了 `KnowledgePoints []KnowledgePoint gorm:"many2many:question_knowledge;"`，关联声明正确
- `question_service.go:95-97` 中构建关联：`question.KnowledgePoints = append(question.KnowledgePoints, model.KnowledgePoint{ID: kpID})`，仅设置 ID
- `question_repository.go:22` 使用 `r.db.WithContext(ctx).Create(question).Error` 创建
- GORM 的 many2many 在 Create 时会自动写入关联表，但前提是 `knowledge_points` 表中存在对应 ID 的记录
- **风险点**：如果知识点 ID 不存在于 `knowledge_points` 表，GORM 会因外键约束报错 500。当前代码没有预校验知识点是否存在
- migrations 目录为空，无法确认数据库表结构是否已正确建立外键约束

**结论**：代码逻辑本身没有明显错误，但缺少知识点存在性校验，且无迁移文件可验证。**需要运行集成测试才能最终确认**。

---

#### BUG-002 (P0): Logout 后 Access Token 仍有效

**验证状态：❌ 未修复**

**证据：**
- `auth_service.go:315-318` Logout 实现：
  ```go
  func (s *AuthService) Logout(ctx context.Context, userID int64) error {
      refreshKey := fmt.Sprintf("token:refresh:%d", userID)
      return s.redis.Del(ctx, refreshKey).Err()
  }
  ```
  仅删除了 Redis 中的 refresh_token
- `middleware/auth.go:18-44` Auth 中间件：
  ```go
  claims, err := jwtMgr.ParseAccessToken(tokenString)
  // ... 仅验证 JWT 签名和过期时间
  c.Set(ContextKeyUserID, claims.UserID)
  ```
  **只验证 JWT 本身的合法性，不检查 Redis 黑名单**
- Access Token 是纯 JWT，有效期内在任何请求中都有效
- Logout 后旧的 Access Token 不会被撤销，直到其自然过期

**影响**：攻击者截获 Access Token 后，即使用户退出登录，Token 在有效期内仍可正常使用。这是一个安全漏洞。

**修复建议**：Logout 时将 Access Token 加入 Redis 黑名单（TTL = Token 剩余有效期），Auth 中间件增加黑名单检查。

---

#### BUG-003 (P0): 中文昵称验证用字节长度而非字符数

**验证状态：❌ 未修复**

**证据：**
- `user_handler.go:88-89`：
  ```go
  nickLen := len(*req.Nickname)
  if nickLen < 2 || nickLen > 12 {
  ```
  使用 Go 的 `len()` 函数，对字符串返回的是**字节数**而非字符数
- 一个中文字符在 UTF-8 中占 3 字节，"小明同学" 4 个汉字 = 12 字节 → 刚好通过
- 但 "小明同学们" 5 个汉字 = 15 字节 → 被拒绝（实际只有 5 个字符，应该允许）
- 反之，"AB" 2 个英文字母 = 2 字节 → 通过，但如果用 `utf8.RuneCountInString` 也是 2 → 行为一致
- **核心问题**：应使用 `utf8.RuneCountInString(*req.Nickname)` 替代 `len(*req.Nickname)`

**影响**：中文用户设置 5-12 个汉字的昵称会被错误拒绝。

---

#### BUG-004 (P1): 注销后登录提示错误码不对

**验证状态：✅ 已修复**

**证据：**
- `auth_service.go:266-268` loginUser 方法：
  ```go
  if user.DeletedAt != nil {
      return nil, errcode.EAccountDeleted
  }
  ```
- `errcode.go:143`：`EAccountDeleted = New(ErrAccountDeleted, "该账号已注销", http.StatusForbidden)`
- ErrAccountDeleted = 10014，HTTP 状态码 403
- 符合 PRD 要求：注销账号后登录返回 403, code=10014

---

#### BUG-005 (P1): Dashboard 返回硬编码假数据

**验证状态：❌ 未修复**

**证据：**
- `report_handler.go:23-51` GetDashboard 方法：
  ```go
  // TODO: 实现完整的Dashboard数据聚合
  // 目前返回简化版本
  respondSuccess(c, gin.H{
      "greeting": gin.H{
          "nickname":    "用户",
          "streak_days": 0,
      },
      "today_task": gin.H{
          "pending_review_count": 0,
          ...
      },
      "statistics": gin.H{
          "total_questions":   0,
          "mastered_count":    0,
          "elimination_rate":  0.0,
      },
      ...
  })
  ```
- 所有数据都是硬编码的零值/空值
- 注释明确标注 "TODO: 实现完整的Dashboard数据聚合"
- 未从数据库查询任何真实数据

**影响**：首页 Dashboard 对所有用户都显示相同假数据，核心功能不可用。

---

#### BUG-006 (P1): 底部导航栏与 PRD 不一致

**验证状态：🔍 代码已实现5项布局，需UI验证**

**证据：**
- `bottom_nav_bar.dart:2` 注释："5项布局：[首页] [错题本] [FAB录入] [周报] [我的]"
- 代码实现了 4 个 Tab + 中间 FAB 按钮的结构
- assert 检查 `items.length == 4`，FAB 自动插入中间位置
- Tab 标签映射：0=首页, 1=错题本, 2=周报, 3=我的
- **代码结构与 PRD 描述一致**（首页/错题本/+录入/周报/我的）
- 但无法在无设备环境下验证实际渲染效果

**结论**：代码层面看起来已按 PRD 实现，标记为代码审查通过，需真机验证。

---

#### BUG-007 (P1): "不确定"选项未按年级控制

**验证状态：⚠️ 组件支持但调用处硬编码**

**证据：**
- `error_category_selector.dart:35` 定义了 `showUnknown` 参数，组件本身支持按条件显示
- `error_category_selector.dart:93-99` 正确使用 `if (showUnknown)` 条件渲染
- **但是** `add_question_page.dart:459`：
  ```dart
  showUnknown: true, // MVP: always show for demo
  ```
  硬编码为 `true`，注释说明是 MVP demo 用途
- 应该根据用户年级判断：小学生(grade 31-34)显示，初中生(grade 71-73)不显示

**影响**：初中生也会看到"不确定"选项，不符合 PRD 要求。

---

#### BUG-008 (P1): 复习退出文案与 PRD 矛盾

**验证状态：✅ 已修复**

**证据：**
- `review_page.dart:150-158` 退出确认弹窗：
  ```dart
  title: '确定退出复习吗？',
  content: '当前进度将不会保存',
  confirmText: '退出',
  cancelText: '继续复习',
  ```
- 文案清晰表达"进度不保存"，确认按钮为"退出"，取消按钮为"继续复习"
- 符合 PRD 对退出确认的要求

---

#### BUG-009 (P2): 20+ TODO/FIXME 遗留

**验证状态：⚠️ 仍有 33 处**

**证据：**
- 后端 Go 代码：5 处 TODO（分布在 auth_service、review_handler、sync_handler、report_handler、ocr）
- 前端 Dart 代码：28 处 TODO/FIXME（分布在 15 个文件中）
- 总计 33 处，比上轮报告的 20+ 有所增加（可能是新增代码引入了更多 TODO）
- 关键 TODO 包括：
  - `report_handler.go:30`: Dashboard 数据聚合未实现
  - `review_handler.go:31`: 每日上限未从用户配置获取
  - `auth_service.go:85`: 短信发送未对接
  - 多个前端页面的功能桩实现

---

#### BUG-010 (P2): Review Queue 返回 null 而非空数组

**验证状态：⚠️ 取决于 JSON 序列化行为**

**证据：**
- `review_service.go:89,135`：
  ```go
  var reviewItems []ReviewItem
  var reviveItems []ReviveItem
  ```
  使用 `var` 声明切片，初始值为 `nil`
- 当没有待复习题目时，`reviewItems` 保持 `nil`
- Go 的 `encoding/json` 将 `nil` slice 序列化为 `null`，而非 `[]`
- `ReviewQueueResponse` 结构体中没有 `omitempty` tag
- **修复方案**：初始化时使用 `make([]ReviewItem, 0)` 或在返回前做 nil→empty 转换

**影响**：前端收到 `null` 而非 `[]`，可能导致 NullPointerException 或需要额外判空。

---

## 二、测试执行结果

### 2.1 Go 后端单元测试

| 包 | 测试数 | 通过 | 失败 | 耗时 |
|----|--------|------|------|------|
| internal/model | 10 | 10 | 0 | 1.32s |
| internal/pkg/errcode | 7 | 7 | 0 | 1.21s |
| internal/pkg/jwt | 9 | 9 | 0 | 1.38s |
| internal/pkg/scheduler | 10 | 10 | 0 | 1.20s |
| internal/service | 17 | 17 | 0 | 1.34s |
| **合计** | **53** | **53** | **0** | **~6.5s** |

**无测试文件的包**：cmd/server, config, handler, middleware, ocr, repository

> ⚠️ 注意：handler 层和 repository 层完全没有单元测试，这是测试覆盖的重大缺口。

### 2.2 Flutter 前端单元测试

| 测试文件 | 测试数 | 通过 | 失败 |
|----------|--------|------|------|
| auth_bloc_test.dart | 19 | 19 | 0 |
| question_bloc_test.dart | 18 | 18 | 0 |
| review_bloc_test.dart | 6 | 6 | 0 |
| **合计** | **43** | **43** | **0** |

> ⚠️ 注意：仅有 BLoC 层测试，无 Widget 测试、无集成测试。

### 2.3 测试覆盖率评估

| 层级 | 有测试 | 缺失 |
|------|--------|------|
| Model/Entity | ✅ | - |
| Error Code | ✅ | - |
| JWT | ✅ | - |
| Scheduler | ✅ | - |
| Service (业务逻辑) | ✅ 部分 | 缺少 auth_service 完整测试 |
| Handler (API) | ❌ | 全部缺失 |
| Repository (数据访问) | ❌ | 全部缺失 |
| Middleware | ❌ | 全部缺失 |
| Flutter BLoC | ✅ 部分 | - |
| Flutter Widget | ❌ | 全部缺失 |
| Flutter Integration | ❌ | 全部缺失 |

---

## 三、P0 测试用例覆盖评估

> 以下为基于代码审查的评估，非实际运行验证。

### 3.1 认证模块 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| AUTH-001-01 | 正常发送注册验证码 | PASS (代码) | OTP 生成+Redis 存储逻辑完整 |
| AUTH-001-02 | 正常发送登录验证码 | PASS (代码) | 同上 |
| AUTH-001-05 | 60秒内重复发送 | PASS (代码) | Redis resendKey TTL 控制 |
| AUTH-002-01 | 新用户注册成功 | PASS (代码) | registerUser 流程完整 |
| AUTH-002-02 | 已注册用户登录成功 | PASS (代码) | loginUser 流程完整 |
| AUTH-002-03 | 验证码错误 | PASS (代码) | Redis 比对 + retry 计数 |
| AUTH-002-04 | 验证码过期 | PASS (代码) | Redis TTL 自动过期 |
| AUTH-002-05 | 连续输错5次锁定 | PASS (代码) | MaxRetry + lockKey 逻辑 |
| AUTH-002-08 | 手机号已注册再注册 | PASS (代码) | FindByPhone 检查 |
| AUTH-002-16 | 注销账号后登录 | PASS (代码) | DeletedAt 检查 + EAccountDeleted |
| AUTH-003-01 | 正常刷新 Token | PASS (代码) | RefreshToken 方法完整 |
| AUTH-003-02 | refresh_token 过期 | PASS (代码) | ParseRefreshToken 错误处理 |
| AUTH-003-03 | refresh_token 被篡改 | PASS (代码) | JWT 签名验证 |
| AUTH-003-04 | 已登出用户的 refresh | PASS (代码) | Redis token 比对 |
| AUTH-004-01 | 正常退出 | PASS (代码) | Redis Del 操作 |
| **AUTH-004-04** | **退出后用旧 access_token [BUG-002]** | **FAIL** | **Auth 中间件不检查黑名单** |
| PM-01 | 第4台设备登录踢出 | SKIP | 未找到设备踢出逻辑实现 |
| PM-02 | 被踢设备数据保留 | SKIP | 依赖 PM-01 |
| PM-08 | 冷静期内登录取消注销 | SKIP | 未找到冷静期逻辑实现 |
| PM-09 | 冷静期后登录不可取消 | SKIP | 未找到冷静期逻辑实现 |

### 3.2 用户模块 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| USER-001-01 | 正常获取个人信息 | PASS (代码) | GetMe handler 完整 |
| USER-002-01 | 修改昵称(正常) | PASS (代码) | UpdateSettings 逻辑完整 |
| **USER-002-05** | **中文昵称 [BUG-003]** | **FAIL** | **len() 而非 RuneCountInString** |
| USER-003-01 | 正常注销 | PASS (代码) | SoftDelete + confirm 检查 |
| USER-003-05 | 注销后再登录 [BUG-004] | PASS (代码) | EAccountDeleted 正确返回 |

### 3.3 错题模块 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| Q-001-01 | 完整字段创建 | PASS (代码) | Create 方法字段映射完整 |
| Q-001-02 | 仅必填字段创建 | PASS (代码) | binding:"required" 校验 |
| Q-001-03 | 缺少 image_url | PASS (代码) | binding:"required" |
| Q-001-04 | 缺少 error_category | PASS (代码) | binding:"required" |
| Q-001-05 | 缺少 knowledge_point_ids | PASS (代码) | binding:"required,min=1" |
| **Q-001-13** | **[BUG-001 回归]** | **UNCERTAIN** | **需集成测试验证** |
| Q-002-01 | 默认分页 | PASS (代码) | List 方法分页逻辑完整 |
| Q-002-04 | 按状态筛选 | PASS (代码) | WHERE status IN 查询 |
| Q-002-09 | 关键词搜索 | PASS (代码) | ILIKE 模糊查询 |
| Q-002-12 | 只返回当前用户数据 | PASS (代码) | WHERE user_id = ? |
| Q-003-01 | 正常获取详情 | PASS (代码) | Preload KnowledgePoints |
| Q-003-03 | 访问他人错题 | PASS (代码) | UserID 比对 |
| Q-004-01 | 部分更新 | PASS (代码) | nil 检查后应用更新 |
| Q-004-05 | 更新他人错题 | PASS (代码) | UserID 比对 |
| Q-005-01 | 正常软删除 | PASS (代码) | Update deleted_at |
| Q-005-02 | 删除他人错题 | PASS (代码) | UserID 比对 |
| Q-006-01 | 正常查看回收站 | PASS (代码) | Unscoped + deleted_at IS NOT NULL |
| Q-007-01 | 正常恢复 | PASS (代码) | Update deleted_at = nil |
| Q-008-01 | 正常永久删除 | PASS (代码) | Unscoped Delete |
| Q-008-02 | 永久删除他人错题 | PASS (代码) | UserID 比对 |
| Q-009-01 | 正常清空 | PASS (代码) | ClearRecycleBin |
| Q-009-02 | 不确认 | PASS (代码) | confirm 检查 |

### 3.4 复习模块 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| R-001-01 | 有待复习题目 | PASS (代码) | GetDueQuestions 查询逻辑 |
| R-001-02 | 无待复习题目 | **RISK [BUG-010]** | nil slice → JSON null |
| R-001-03 | 超每日上限 | PASS (代码) | dailyLimit 截断逻辑 |
| R-001-04 | 含复活检测题目 | PASS (代码) | GetReviveCandidates |
| R-002-01 ~ R-002-04 | 自评结果处理 | PASS (代码+单测) | scheduler 有完整测试 |
| R-002-08 | 今日已复习再提交 | PASS (代码) | FindByQuestionAndDate 检查 |
| R-002-12 | 他人 question_id | PASS (代码) | UserID 比对 |
| R-003-01 ~ R-003-04 | 复活检测 | PASS (代码) | handleReviveCheck 逻辑完整 |

### 3.5 报告模块 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| RPT-001-01 | 正常获取 Dashboard | PASS (代码) | 返回结构正确 |
| **RPT-001-02** | **[BUG-005] Dashboard 真实数据** | **FAIL** | **全部硬编码零值** |
| RPT-001-04 | 错因分布排除 UNKNOWN | SKIP | Dashboard 未实现 |

### 3.6 安全测试 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| SEC-01 | 无 Token 访问 | PASS (代码) | Auth 中间件检查 |
| SEC-02 | 过期 Token | PASS (代码) | JWT 过期验证 |
| SEC-03 | 篡改 Token | PASS (代码) | JWT 签名验证 |
| SEC-04 | 跨用户隔离(错题) | PASS (代码) | UserID 比对 |
| SEC-05 | 跨用户隔离(周报) | PASS (代码) | UserID 比对 |
| SEC-06 | SQL注入 | PASS (代码) | GORM 参数化查询 |
| SEC-08 | 暴力破解验证码 | PASS (代码) | MaxRetry + Lockout |
| SEC-09 | 限流防护 | PASS (代码) | RateLimiter 中间件 |
| **SEC-14** | **[BUG-002] Logout后access_token** | **FAIL** | **同 BUG-002** |

### 3.7 前端 UI P0 用例（代码审查）

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| UI-HM-12 | [BUG-006] 底部导航栏 | PASS (代码) | 4Tab+FAB 结构正确 |
| **UI-AQ-12** | **[BUG-007] "不确定"选项** | **FAIL** | **showUnknown 硬编码 true** |
| UI-AQ-13 | "不确定"初中生不显示 | FAIL | 同上 |
| UI-RV-05 | 三个自评按钮 | PASS (代码) | SelfEvalButtons 3 按钮 |
| UI-RV-08 | 中途退出 | PASS (代码) | PopScope + 确认弹窗 |
| UED-10 | 自评后4秒撤销窗口 | PASS (代码) | EHSnackbar 4秒 + UndoEvaluation |

### 3.8 引擎 P0 用例

| 编号 | 用例 | 评估 | 依据 |
|------|------|------|------|
| ENG-SCH-01 ~ 05 | 艾宾浩斯调度 | PASS (单测) | scheduler_test.go 全覆盖 |
| ENG-EXT-01 ~ 06 | 消灭状态机 | PASS (代码+单测) | review_service 逻辑完整 |
| ENG-OCR-01 | 印刷体识别 | SKIP | Mock 模式，需真实 OCR 服务 |
| ENG-SYN-01 ~ 05 | 离线同步 | SKIP | 桩实现 |
| ENG-STAT-01 | Dashboard统计 | FAIL | 同 BUG-005 |

---

## 四、阻塞项

| # | 阻塞描述 | 影响范围 | 优先级 |
|---|---------|---------|--------|
| B1 | **BUG-002 未修复**：Logout 后 Access Token 仍有效 | 安全模块全部用例 | P0 |
| B2 | **BUG-003 未修复**：中文昵称验证错误 | 用户设置相关用例 | P0 |
| B3 | **BUG-005 未修复**：Dashboard 全假数据 | 首页+报告模块 | P0 |
| B4 | 无集成测试环境（DB+Redis 未启动） | 所有 API 端到端验证 | P1 |
| B5 | Handler 层无单元测试 | API 行为验证 | P1 |
| B6 | 设备管理/冷静期功能未实现 | PM-01/02/08/09 | P1 |
| B7 | 无 Flutter Widget 测试 | UI 渲染验证 | P2 |

---

## 五、建议

### 5.1 必须修复（下一轮测试前）

1. **BUG-002**：在 Auth 中间件中增加 Token 黑名单检查
   - Logout 时将 access_token_jti 写入 Redis，TTL = Token 剩余有效期
   - Auth 中间件解析 JWT 后检查黑名单
   - 预计工时：2h

2. **BUG-003**：替换 `len()` 为 `utf8.RuneCountInString()`
   - 文件：`internal/handler/user_handler.go:88`
   - 一行代码修复
   - 预计工时：0.5h

3. **BUG-005**：实现 Dashboard 真实数据聚合
   - 从 questions 表统计 total/mastered
   - 从 review_records 表统计今日任务
   - 从 users 表获取 greeting 信息
   - 预计工时：4h

4. **BUG-007**：根据用户年级控制 showUnknown
   - 在 add_question_page 中获取当前用户 grade
   - `showUnknown: grade.stage == StagePrimary`
   - 预计工时：0.5h

5. **BUG-010**：确保空数组返回 `[]` 而非 `null`
   - 将 `var reviewItems []ReviewItem` 改为 `reviewItems := make([]ReviewItem, 0)`
   - 预计工时：0.5h

### 5.2 建议补充

6. 补充 Handler 层单元测试（至少覆盖 Auth + Question + Review Handler）
7. 补充 Repository 层集成测试（使用 testcontainers 或 SQLite mock）
8. 实现设备管理功能（PM-01/02）和冷静期功能（PM-08/09）
9. 建立 CI/CD 流水线，自动化运行 `go test` + `flutter test`
10. 清理 TODO/FIXME，尤其是 report_handler 和 review_handler 中的关键 TODO

### 5.3 风险评估

| 风险 | 等级 | 说明 |
|------|------|------|
| BUG-002 安全漏洞 | 🔴 高 | Token 不可撤销，存在会话劫持风险 |
| BUG-005 核心功能缺失 | 🔴 高 | 首页是用户第一触点，假数据严重影响体验 |
| 无集成测试 | 🟡 中 | 代码审查无法发现运行时问题（如 DB 约束） |
| Handler 无测试 | 🟡 中 | API 行为仅靠人工验证，回归风险高 |
| 设备管理未实现 | 🟡 中 | PRD 明确要求的多设备管控功能缺失 |

---

## 六、附录

### A. 测试执行命令

```bash
# Go 后端测试
cd src/errorhunter_server && go test ./... -v

# Flutter 前端测试
cd src/errorhunter_app && flutter test
```

### B. 代码审查文件清单

| 文件 | 审查目的 |
|------|---------|
| internal/model/model.go | BUG-001 GORM 关联定义 |
| internal/service/question_service.go | BUG-001 创建逻辑 |
| internal/repository/question_repository.go | BUG-001 数据库操作 |
| internal/service/auth_service.go | BUG-002/004 Logout+登录逻辑 |
| internal/middleware/auth.go | BUG-002 Token 验证 |
| internal/handler/user_handler.go | BUG-003 昵称验证 |
| internal/handler/report_handler.go | BUG-005 Dashboard |
| lib/widgets/common/bottom_nav_bar.dart | BUG-006 导航栏 |
| lib/features/question/pages/add_question_page.dart | BUG-007 不确定选项 |
| lib/features/review/pages/review_page.dart | BUG-008 退出文案 |
| internal/service/review_service.go | BUG-010 空数组 |

### C. 统计摘要

```
总 P0 用例数:     ~130 条
代码审查 PASS:    ~85 条 (65%)
代码审查 FAIL:    5 条 (4%)  ← BUG-002×2, BUG-003, BUG-005, BUG-007
UNCERTAIN:        1 条 (1%)  ← BUG-001
SKIP:             ~39 条 (30%) ← 未实现功能/需真机/需集成环境
Go 单元测试:      53/53 PASS
Flutter 单元测试: 43/43 PASS
```

---

*报告生成时间：2026-06-20 | QA Agent（赵测）| 第一轮 P0 冒烟测试*
