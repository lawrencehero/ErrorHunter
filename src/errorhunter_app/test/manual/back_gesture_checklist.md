# 返回手势手工回归 Checklist（修复3）

> 适用：`lib/router/app_router.dart` 的 `_MainShell` PopScope 逻辑（修复3）。
> 修复3 用 PopScope(canPop: 动态, onPopInvokedWithResult) 放在 ShellRoute
> 的 `_MainShell` build 顶层；AndroidManifest **未设**
> `enableOnBackInvokedCallback`（走传统返回路径，PopScope 才稳定触发）。
>
> **自动测试覆盖**：`test/features/back_gesture_intercept_test.dart` 用
> `tester.binding.handlePopRoute()` 模拟系统返回，已覆盖错题本/周报/我的
> tab 根页回首页、首页放行退出、错题详情子页正常 pop、全屏页不被误拦截。
> 该测试在 flutter_test 环境验证拦截机制（go_router popRoute → maybePop →
> PopScope.onPopInvokedWithResult）能被触发并正确重定向。
>
> **仍需真机回归**：predictive back（侧滑）/系统返回键的真实平台事件流、
> 各 Android 版本/ROM 的 OnBackPressedDispatcher 差异，需真机验证。
> 每次改动 `_MainShell`、`AndroidManifest` 或升级 Flutter/GoRouter 后执行。

## 前置

- 真机：Android 13+（API 33+，支持 predictive back）至少 1 台
- 真机：Android 12 及以下（API < 33）至少 1 台
- 已登录账号、各 tab 均有可进入的页面

## 用例

### A. 非首页 tab → 系统返回/侧滑 → 回首页 tab（不退桌面）

| # | 步骤 | 期望 |
|---|------|------|
| A1 | 进入「错题本」tab（`/questions`），首页 tab 高亮切换到第 2 个 | 当前 tab = 错题本 |
| A2 | 触发系统返回手势（侧滑边沿 / 系统返回键） | **回到首页 tab**，App **不退出**到桌面 |
| A3 | 进入「周报」tab，系统返回 | 回首页 tab，不退桌面 |
| A4 | 进入「我的」tab，系统返回 | 回首页 tab，不退桌面 |
| A5 | 进入错题本 → 系统返回到首页 → 再次系统返回 | 第二次返回才退出 App（见 B） |

**失败判据**：在非首页 tab 系统返回直接退到桌面 = 回归。

### B. 首页 tab → 系统返回 → 退出 App

| # | 步骤 | 期望 |
|---|------|------|
| B1 | 停在首页 tab（`/home`，currentIndex==0） | 底部高亮 = 首页 |
| B2 | 触发系统返回手势 | App 退到桌面（`SystemNavigator.pop()` 生效） |

**失败判据**：首页返回无反应，或抛异常 / 卡死 = 回归。

### C. 全屏推入页 → 返回 → 退出该页（回到来源 tab）

| # | 页面 | 路由 | 返回后期望 |
|---|------|------|-----------|
| C1 | 添加错题页 | `/add` | 回到来源 tab（通常是首页） |
| C2 | 复习页 | `/review` | 回到来源 tab |
| C3 | 复习报告页 | `/review/report` | 回到来源 tab |
| C4 | 消灭动画页 | `/eliminate` | 回到来源 tab |
| C5 | 周报详情页 | `/reports/weekly/:id` | 回到周报列表 tab |
| C6 | 提醒设置 | `/settings/reminder` | 回到「我的」 |
| C7 | 存储管理 | `/settings/storage` | 回到「我的」 |
| C8 | 主题选择 | `/settings/theme` | 回到「我的」 |
| C9 | 回收站 | `/recycle-bin` | 回到「我的」 |
| C10 | PDF 导出 | `/export/pdf` | 回到来源 tab |
| C11 | 注销账号 | `/account/deactivate` | 回到「我的」 |
| C12 | 用户协议 / 隐私政策 | `/legal/*` | 回到来源页 |

**失败判据**：全屏页返回后落到错误的 tab、或栈错乱（如回到首页却仍显示半屏页）= 回归。

### D. Android 12 及以下（API < 33）不退化

| # | 步骤 | 期望 |
|---|------|------|
| D1 | 在 API < 33 设备上重复 A1~A5 | 行为与 13+ 一致（非首页回首页） |
| D2 | 在 API < 33 设备上重复 B1~B2 | 首页返回退出 App |
| D3 | 在 API < 33 设备上重复 C 表 | 全屏页正常返回 |

**说明**：修复3 不设 `enableOnBackInvokedCallback`，全版本走经典返回路径，
PopScope.onPopInvokedWithResult 在传统 OnBackPressedDispatcher 上稳定触发。
若低版本出现「无反应」或「直接退桌面」= 回归。

### E. 边界 / 状态

| # | 场景 | 期望 |
|---|------|------|
| E1 | 复习进行中（ReviewInProgress）按系统返回 | 退出复习页，回到来源 tab，复习流程中断可接受（不崩） |
| E2 | 添加错题页填了一半内容按返回 | 退出该页，未保存内容丢失（当前设计如此，无确认弹窗——若后续加确认弹窗需更新本用例） |
| E3 | 键盘弹起状态下侧滑返回 | 键盘收起 + 正常返回，不卡死 |
| E4 | 快速连点系统返回 | 不出现栈错乱 / 黑屏 / ANR |
| E5 | 全屏页返回后立即再进同一页 | 正常进入，不残留旧状态 |

## 记录

- 执行人 / 日期 / 设备型号 / Android 版本：
- 发现的问题：
