# 🧪 错题猎手 V1.0 全面测试报告

执行日期: 2026-06-20 | 执行人: 🧪 赵测

## 一、测试概览

| 维度 | 数量 |
|------|------|
| 测试用例总数 | 78 |
| P0（核心阻塞） | 12 |
| P1（重要功能） | 34 |
| P2（一般/体验） | 32 |
| 已执行 | 52 |
| 通过 | 38 |
| 失败（Bug） | 10 |
| 需手动验证 | 4 |
| 未执行 | 26 |

已有单元测试: 63 tests ALL PASS

---

## 二、发现的 Bug 清单 (10个)

### BUG-001 [P0/Critical] 创建错题始终返回500
- 模块: POST /v1/questions
- 根因: GORM many2many关联写入question_knowledge时外键约束违反
- 影响: MVP核心录入流程完全不可用

### BUG-002 [P0/Critical] Logout后Access Token仍有效
- 模块: auth middleware + logout
- 根因: Logout仅删refresh_token, middleware不检查黑名单
- 影响: 安全漏洞

### BUG-003 [P0/Critical] 中文昵称验证用字节长度
- 模块: PUT /v1/users/me/settings
- 根因: len(string)返回字节数而非rune数
- 修复: utf8.RuneCountInString()

### BUG-004 [P1] 注销后登录提示错误(应为10014实际10005)
### BUG-005 [P1] Dashboard返回硬编码假数据
### BUG-006 [P1] 底部导航栏与PRD不一致(周报占了第3tab)
### BUG-007 [P1] 不确定选项未按年级控制(showUnknown硬编码true)
### BUG-008 [P1] 复习退出文案与PRD矛盾
### BUG-009 [P2] 20+处TODO/FIXME遗留
### BUG-010 [P2] Review Queue返回null而非空数组

---

## 三、测试结论: 不建议上线

阻塞项: BUG-001, BUG-002, BUG-003

详细报告请参见对话中的完整内容。
