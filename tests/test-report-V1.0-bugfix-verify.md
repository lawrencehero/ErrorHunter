# 错题猎手 V1.0 Bug修复验证测试报告

| 项目 | 内容 |
|------|------|
| **测试日期** | 2026-06-20 |
| **测试人员** | QA Agent（赵测） |
| **测试范围** | BUG-002/003/005/007/010 修复验证 + P0/P1 回归测试 |
| **后端版本** | errorhunter_server (Go) |
| **前端版本** | errorhunter_app (Flutter) |

---

## 一、Bug修复逐项验证

### BUG-002 (P0): Logout后Access Token黑名单 ✅ PASS（附注意事项）

**修复方案审查：**

| 检查点 | 结果 | 说明 |
|--------|------|------|
| auth.go 增加 Redis 黑名单检查 | ✅ | L46-53，JWT解析通过后检查 `token:blacklist:{userID}:{exp}` |
| auth_service.go Logout 写入黑名单 | ✅ | L315-333，删除refresh token + access token加入黑名单 |
| auth_handler.go 提取 token 传给 service | ✅ | L104-108，从 Authorization header 提取并传递 |
| main.go Redis 注入中间件 | ✅ | L125 `middleware.Auth(jwtMgr, redisClient)` |
| 黑名单 key 格式一致性 | ✅ | 写入和读取均使用 `token:blacklist:%d:%d` (userID + expiresAt) |
| TTL 计算正确性 | ✅ | `time.Until(claims.ExpiresAt.Time)`，仅在 remaining > 0 时写入 |
| redis nil 安全 | ✅ | L46 `if redisClient != nil` 防御性检查 |
| OptionalAuth 同步更新 | ✅ | L61-88 也加入了黑名单检查，保持一致 |

**边界情况分析：**

| 场景 | 处理 | 评估 |
|------|------|------|
| Token已过期后Logout | `remaining <= 0`，不写入黑名单 | ✅ 正确，过期token本身无法通过JWT校验 |
| Redis连接失败 | `redis.Set` 错误被忽略 | ⚠️ 风险：Logout返回nil不报错，但黑名单未生效 |
| accessToken为空字符串 | L321 `if accessToken != ""` 跳过 | ✅ 正确处理 |
| 并发登出同一账号 | 相同key覆盖写入 | ✅ 幂等，无问题 |
| 刷新Token后再用旧Access Token | 旧token不在黑名单中 | ⚠️ 设计局限：刷新后旧access token仍可用直到过期 |

**⚠️ 发现的风险项（非阻塞）：**
1. **Redis故障时静默失败**：`auth_service.go:327` 的 `s.redis.Set()` 返回值未检查。若Redis不可用，Logout看似成功但黑名单未生效，已登出用户的token仍可继续使用直到自然过期。建议增加错误日志或告警。
2. **Token刷新后的旧Access Token**：当前设计仅将Logout时的access token加入黑名单。如果用户先Refresh再Logout，只有新access token被黑名单化，旧的access token（如果还在有效期内）不会被追溯黑名单。这是JWT无状态设计的固有局限，可接受但需文档说明。

---

### BUG-003 (P0): 中文昵称RuneCountInString ✅ PASS（附遗漏点）

**修复方案审查：**

| 检查点 | 结果 | 说明 |
|--------|------|------|
| user_handler.go 使用 RuneCountInString | ✅ | L90: `utf8.RuneCountInString(*req.Nickname)` |
| import unicode/utf8 | ✅ | L4 已导入 |
| 长度校验逻辑 | ✅ | L91: `< 2 \|\| > 12` 符合PRD要求 |

**⚠️ 发现的遗漏（BUG-003相关但未修复）：**

| 位置 | 问题 | 严重度 |
|------|------|--------|
| `auth_service.go:235-238` registerUser | 注册时接收 `req.Nickname` 但**未做长度校验**。若用户在注册时传入超长中文昵称（如13个汉字），将直接写入数据库。虽然DB有varchar(24)限制会截断或报错，但应在service层提前校验。 | P1 |
| `auth_service.go:235-238` registerUser | 注册时也未校验昵称最短长度。传入1个汉字的昵称可通过。 | P2 |

**建议**：在 `registerUser` 方法中增加与 `UpdateSettings` 相同的 `utf8.RuneCountInString` 校验逻辑。

---

### BUG-005 (P1): Dashboard真实数据 ✅ PASS

**修复方案审查：**

| 检查点 | 结果 | 说明 |
|--------|------|------|
| report_handler.go 查询真实数据 | ✅ | 调用 reportRepo 多个方法获取真实统计 |
| NewReportHandler 签名变更 | ✅ | 新增 userRepo 参数，main.go:89 已同步更新 |
| GetDashboardStats SQL正确 | ✅ | 分别查总题数、已消灭、待复习，条件包含 `deleted_at IS NULL` |
| 空数据处理 | ✅ | handler中使用 `make([]gin.H, 0, len(...))` 初始化，保证返回 `[]` 而非 null |
| elimination_rate 计算 | ✅ | L56: `math.Round(mastered/total*1000)/10` 保留一位小数，total=0时返回0 |
| error_distribution 排除 UNKNOWN | ✅ | repository L94: `error_category != model.ErrorUnknown` |
| weekly_trend 7天完整 | ✅ | repository L146-153: 从6天前到今天循环填充，缺失日期补0 |
| weak_knowledge_top Top3 | ✅ | repository L178: `Limit(3)` + 排除已消灭题目 |

**边界情况验证：**

| 场景 | 预期行为 | 实际代码 | 评估 |
|------|----------|----------|------|
| 新用户(0道题) | 全0/空数组 | stats各字段为0, make()初始化为[] | ✅ |
| 所有题都是UNKNOWN错因 | error_distribution为空数组 | WHERE排除了UNKNOWN | ✅ |
| pending_review > daily_limit | has_overflow=true | L98-99 正确计算 | ✅ |
| 7天内无数据 | 趋势图全0 | map查找miss返回0值 | ✅ |

**⚠️ 潜在性能注意：**
- `GetDashboardStats` 执行3次独立COUNT查询，`GetErrorDistribution`/`GetWeeklyTrend`/`GetWeakKnowledgeTop` 各有1-3次查询。总计约7-8次DB查询。对于V1.0可接受，后续可考虑合并优化。

---

### BUG-007 (P1): showUnknown按年级控制 ✅ PASS

**修复方案审查：**

| 检查点 | 结果 | 说明 |
|--------|------|------|
| _shouldShowUnknown() 方法存在 | ✅ | L560-569 |
| 初中(7x)不显示 | ✅ | `grade.startsWith('7')` → return false |
| 小学(3x)显示 | ✅ | 不匹配'7'开头 → fallthrough → return true |
| ErrorCategorySelector 接收 showUnknown | ✅ | L462 传入参数 |

**边界情况分析：**

| 场景 | grade值 | 行为 | 评估 |
|------|---------|------|------|
| 小学三年级 | "31" | startsWith('7')=false → 显示 | ✅ |
| 初中一年级 | "71" | startsWith('7')=true → 不显示 | ✅ |
| 初中三年级 | "73" | startsWith('7')=true → 不显示 | ✅ |
| 未登录/AuthState非Authenticated | - | fallthrough → 显示 | ✅ 合理默认值 |
| grade为空字符串"" | "" | startsWith('7')=false → 显示 | ✅ 安全降级 |
| grade为null | N/A | Dart中String不会为null(sound null safety) | ✅ |

**评估**：逻辑简洁正确，覆盖了所有年级枚举值和异常情况。

---

### BUG-010 (P2): 空数组返回[] ✅ PASS

**修复方案审查：**

| 检查点 | 结果 | 说明 |
|--------|------|------|
| review_service.go ReviewItems 初始化 | ✅ | L89: `make([]ReviewItem, 0)` |
| review_service.go ReviveItems 初始化 | ✅ | L135: `make([]ReviveItem, 0)` |
| JSON序列化结果 | ✅ | make初始化的空切片序列化为`[]`，非`null` |

**同类问题全局扫描：**

| 文件 | 行号 | 声明方式 | 是否经过handler包装 | 风险 |
|------|------|----------|---------------------|------|
| report_repository.go | L41 | `var reports []model.WeeklyReport` | handler L61 make()包装 | ✅ 安全 |
| report_repository.go | L90 | `var items []ErrorDistributionItem` | handler L61 make()包装 | ✅ 安全 |
| report_repository.go | L110 | `var items []WeeklyTrendItem` | handler L70 make()包装 | ✅ 安全 |
| report_repository.go | L167 | `var items []WeakKnowledgeItem` | handler L82 make()包装 | ✅ 安全 |
| question_repository.go | L119,162,187,199 | `var list []model.Question` | 需确认handler层 | ⚠️ 待确认 |
| review_repository.go | L46 | `var records []model.ReviewRecord` | 直接返回给handler | ⚠️ 待确认 |

**⚠️ 注意**：repository层的nil slice问题已在handler层通过make()重新包装解决（report_handler.go）。但 `question_repository.go` 和 `review_repository.go` 的返回值如果在handler中直接JSON序列化（未经make()重包装），仍可能返回null。建议在后续迭代中统一在repository层使用make()初始化。

---

## 二、测试执行结果

### 后端 Go Tests

```
?    cmd/server              [no test files]
?    internal/config          [no test files]
?    internal/handler         [no test files]
?    internal/middleware      [no test files]
ok   internal/model           (cached)
ok   internal/pkg/errcode     (cached)
ok   internal/pkg/jwt         (cached)
?    internal/pkg/ocr         [no test files]
ok   internal/pkg/scheduler   (cached)
?    internal/repository      [no test files]
ok   internal/service         (cached)
```

| 指标 | 结果 |
|------|------|
| 总包数 | 11 |
| 有测试包 | 5 |
| 通过 | 5/5 ✅ |
| 失败 | 0 |
| 无测试文件 | 6（handler/middleware/repository/config/ocr/cmd） |

### 前端 Flutter Tests

```
00:00 +43: All tests passed!
```

| 指标 | 结果 |
|------|------|
| 总用例数 | 43 |
| 通过 | 43 ✅ |
| 失败 | 0 |
| 覆盖模块 | auth_bloc, question_bloc, review_bloc |

---

## 三、回归问题分析

### 3.1 middleware.Auth 签名变更

| 检查项 | 结果 |
|--------|------|
| Auth() 新增 redisClient 参数 | ✅ main.go:125 已同步传入 |
| OptionalAuth() 同样新增参数 | ✅ 定义一致，当前未被路由使用 |
| 未认证路由是否受影响 | ✅ /health, /auth/* 路由不在 authenticated group 内，不受影响 |
| CORS/RateLimiter 中间件 | ✅ 在 router 级别，不受 Auth 变更影响 |

**结论**：无回归风险。

### 3.2 NewReportHandler 签名变更

| 检查项 | 结果 |
|--------|------|
| 新增 userRepo 参数 | ✅ main.go:89 已同步传入 |
| 其他调用方 | ✅ grep确认仅 main.go 一处调用 |

**结论**：无回归风险。

### 3.3 AuthService.Logout 签名变更

| 检查项 | 结果 |
|--------|------|
| 新增 accessToken 参数 | ✅ auth_handler.go:110 已同步传入 |
| 其他调用方 | ✅ grep确认仅 auth_handler.go 一处调用 |

**结论**：无回归风险。

### 3.4 编译验证

Go tests 全部通过（含 cached），说明编译无错误，接口兼容。Flutter tests 全部通过，说明前端无编译/运行时异常。

---

## 四、遗留风险汇总

| # | 风险描述 | 关联Bug | 严重度 | 建议 |
|---|----------|---------|--------|------|
| R1 | 注册流程缺少昵称长度校验（中文RuneCount） | BUG-003 | P1 | 在 registerUser 中增加 utf8.RuneCountInString 校验 |
| R2 | Logout时Redis写入失败静默忽略 | BUG-002 | P2 | 增加错误日志/告警，或在响应中标记部分失败 |
| R3 | Token刷新后旧Access Token不被追溯黑名单 | BUG-002 | P3 | JWT固有局限，建议在API文档中说明 |
| R4 | question_repository/review_repository 的nil slice未在repo层修复 | BUG-010 | P2 | 统一在repository层使用make()初始化 |
| R5 | Dashboard 7-8次DB查询，高并发下可能成为瓶颈 | BUG-005 | P3 | V1.1考虑合并查询或缓存 |
| R6 | handler/middleware/repository 无单元测试 | 全局 | P2 | 补充关键路径的单元测试 |

---

## 五、综合评估与建议

### 修复质量评分

| Bug | 修复完整性 | 代码质量 | 边界处理 | 评分 |
|-----|-----------|----------|----------|------|
| BUG-002 | ★★★★☆ | ★★★★☆ | ★★★☆☆ | B+ |
| BUG-003 | ★★★☆☆ | ★★★★★ | ★★★☆☆ | B |
| BUG-005 | ★★★★★ | ★★★★☆ | ★★★★★ | A |
| BUG-007 | ★★★★★ | ★★★★★ | ★★★★★ | A |
| BUG-010 | ★★★★☆ | ★★★★☆ | ★★★☆☆ | B+ |

### 🟢 是否可以进入下一轮？

**YES — 有条件通过**

**通过理由：**
1. 5个Bug的核心修复均已正确实现，代码逻辑清晰
2. 所有现有测试（Go 5包 + Flutter 43用例）全部通过
3. 无编译错误、无接口不兼容、无回归破坏
4. P0级安全问题（Token黑名单、中文昵称）已有效缓解

**附加条件：**
1. **必须修复**：R1（注册流程昵称校验遗漏）— 这是BUG-003的不完整修复，属于同级别P1问题
2. **建议修复**：R2（Redis静默失败）— 至少增加error log
3. **可延后**：R3-R6 纳入V1.1 backlog

---

*报告生成时间：2026-06-20T22:00:00+08:00*
*QA Agent: 赵测 | ErrorHunter V1.0 Bugfix Verification*
