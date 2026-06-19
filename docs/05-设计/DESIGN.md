# 错题猎手 (ErrorHunter) DESIGN.md

> 基于 Open Design 设计系统框架，融合 Duolingo 游戏化 + Colorful 高饱和 + Friendly 亲和力三大设计语言
> 版本：V2.0 | 更新日期：2026-06-19

## 1. Visual Theme & Atmosphere

**设计关键词：** 游戏化成就感 × 友好亲和力 × 精致现代感

错题猎手的用户是 8-15 岁学生，界面应传递"有趣但有质感"的体验。借鉴 Duolingo 的游戏化元素（chunky 按钮、进度反馈、成就激励），但避免过度卡通化。保持品牌蓝 `#4F6EF7` 作为主调，辅以温暖橙 `#FF8C42` 传递成就感。

**核心设计策略：**

| 维度 | 旧版（V1.0） | 新版（V2.0） | 来源 |
|------|-------------|-------------|------|
| 按钮风格 | 扁平无边框 | **3D chunky 底影** + 按压下沉动效 | Duolingo |
| 卡片阴影 | 单一浅阴影 (opacity 0.06) | **3 级阴影层级** (elevation-1/2/3) | Open Design |
| 色彩使用 | 纯色平铺 | **渐变色** + 状态色浅底 + 品牌色渐变 | Colorful |
| 圆角 | 8-16px | **12-20px** 更圆润友好 | Friendly |
| 字体 | 400-600 字重 | **700-800 字重** + 大号数据数字 | Duolingo |
| 边框 | 0.5px 发丝线 | **1.5-2px 实线** | Duolingo |
| 动效 | 无 | **有目的的微动效**（反馈、进度、状态变化） | Duolingo + Flutter |

---

## 2. Color Palette & Roles

### 2.1 Brand Colors (保留)

| Token | 色值 | 用途 |
|-------|------|------|
| `brandPrimary` | `#4F6EF7` 活力蓝 | 主按钮、Tab 激活、链接 |
| `brandPrimaryDark` | `#3A56D4` | 按钮底影 (chunky shadow) |
| `brandPrimaryLight` | `#7B93FF` | Hover 态、浅填充 |
| `brandPrimaryPale` | `#EEF1FE` | 浅底色、选中背景 |
| `brandSecondary` | `#FF8C42` 温暖橙 | 打卡、里程碑、次要强调 |
| `brandSecondaryDark` | `#E6732E` | 橙色按钮底影 |
| `brandSecondaryLight` | `#FFB07A` | 橙色浅填充 |

### 2.2 Semantic Colors (保留 + 增强)

| Token | 色值 | 用途 |
|-------|------|------|
| `success` | `#34C759` 消灭绿 | 已消灭、正确、完成 |
| `successDark` | `#28A745` | 绿色底影 |
| `warning` | `#FFB830` 复习黄 | 复习中、部分记得 |
| `warningDark` | `#E5A32B` | 黄色底影 |
| `danger` | `#D32F2F` 未掌握红 | 未掌握、完全不会 |
| `dangerDark` | `#B71C1C` | 红色底影 |

### 2.3 Gradient System (新增)

| Token | 渐变 | 用途 |
|-------|------|------|
| `gradientPrimary` | `#4F6EF7` → `#7B93FF` (135°) | 主按钮、顶栏背景、CTA |
| `gradientWarm` | `#FF8C42` → `#FFB07A` (135°) | 打卡条、成就卡片 |
| `gradientSuccess` | `#34C759` → `#66D97A` (135°) | 消灭动画、进度条填充 |
| `gradientSunset` | `#FF8C42` → `#FF6B6B` (135°) | 复习倒计时、紧急提醒 |
| `gradientCard` | `#FFFFFF` → `#F8F9FC` (180°) | 卡片微渐变底色 |
| `gradientHero` | `#4F6EF7` → `#6C5CE7` (135°) | 个人中心顶栏、周报头部 |

### 2.4 Neutral Colors (保留)

| Token | 色值 | 用途 |
|-------|------|------|
| `textPrimary` | `#1A1A2E` | 标题、正文 |
| `textSecondary` | `#6B7280` | 辅助说明 |
| `textTertiary` | `#9CA3AF` | 占位符、禁用态 |
| `border` | `#E5E7EB` | 分割线、卡片边框 |
| `background` | `#F8F9FC` | 页面底色 |
| `surface` | `#FFFFFF` | 卡片表面 |

---

## 3. Typography

### 3.1 Font Scale (字重增强)

| 层级 | 小学生 | 初中生 | 字重 | 变化说明 |
|------|--------|--------|------|---------|
| H1 | 26px | 24px | **Bold 800** | 字重从 700→800，更自信 |
| H2 | 22px | 20px | **Bold 700** | 模块标题更有存在感 |
| H3 | 18px | 16px | Semibold 600 | 不变 |
| Body | 16px | 14px | Regular 400 | 不变 |
| Caption | 14px | 12px | Regular 400 | 不变 |
| Button | 16px | 15px | **Bold 700** | 字重从 500→700 |
| **Number (数据)** | **32px** | **28px** | **Bold 800** | 加大加粗，Duolingo 式数据展示 |
| **Streak** | 18px | 16px | **Bold 800** | 新增：打卡天数专用 |

### 3.2 Principles

- **数据即主角**：统计数字使用 32px/800 超大字重，一眼看到成就感
- **标题要自信**：H1/H2 使用 700-800 字重，传递信心感
- **按钮要有力**：按钮文字 700 字重 + 0.02em 字间距

---

## 4. Elevation & Shadow System (新增)

### 3 级阴影层级

| 层级 | 参数 | 用途 | 视觉效果 |
|------|------|------|---------|
| `elevation-1` | blur: 8, offset: (0,2), opacity: 0.06 | 静态卡片、列表项 | 轻微浮起 |
| `elevation-2` | blur: 16, offset: (0,4), opacity: 0.10 | 交互卡片、统计卡 | 明显浮起 |
| `elevation-3` | blur: 24, offset: (0,8), opacity: 0.15 | 弹窗、浮动按钮、底部导航 | 高层级元素 |

### Chunky Bottom Shadow (Duolingo 风格)

| 组件 | 底影参数 | 说明 |
|------|---------|------|
| 主按钮 | 3px solid `brandPrimaryDark` | 3D 可按压感 |
| 次要按钮 | 3px solid `border` | 白色底 + 灰色底影 |
| 交互卡片 | 3px solid `border` | 卡片也有按压感 |
| 活跃节点 | 4px solid darker variant | 圆形按钮、Tab 图标 |

### 按压效果

```
Normal:   border-bottom: 3px solid darkColor
Pressed:  border-bottom: 0, transform: translateY(3px)
```

---

## 5. Spacing & Layout

### 4px 基准网格 (保留)

| Token | 值 | 用途 |
|-------|-----|------|
| xs | 4px | 图标与文字间距 |
| sm | 8px | 同组元素间距 |
| md | 12px | 卡片内元素间距 |
| base | 16px | 页面水平安全边距、卡片间距 |
| lg | 20px | 模块间距 |
| xl | 24px | 区块间距 |
| xxl | 32px | 页面顶部/底部留白 |
| xxxl | 48px | 大区块分隔 |

### 新增 Token

| Token | 值 | 用途 |
|-------|-----|------|
| `buttonGap` | 12px | 按钮组内间距 |
| `cardSectionGap` | 16px | 卡片内区块间距 |
| `listItemGap` | 8px | 列表项间距 |

---

## 6. Border & Radius

### 圆角系统 (增强)

| Token | 值 | 用途 | 变化 |
|-------|-----|------|------|
| sm | 8px | 标签、小 Chip | 4→8 |
| md | 12px | 输入框、下拉菜单 | 8→12 |
| lg | 16px | 卡片、面板 | 12→16 |
| xl | 20px | 大卡片、弹窗、底部 Sheet | 16→20 |
| full | 999px | 圆形按钮、头像、进度条 | 不变 |

### 边框系统 (增强)

| 类型 | 参数 | 用途 |
|------|------|------|
| 标准边框 | 1.5px solid `border` | 卡片、输入框 |
| 强调边框 | 2px solid `brandPrimary` | 选中态、焦点 |
| 底影边框 | 3px solid `darkerColor` | 按钮、交互卡片 |
| 无可见边框 | elevation-2 阴影替代 | 统计卡片、浮动元素 |

---

## 7. Component Stylings

### 7.1 Buttons

**Primary Button (渐变 + Chunky)**
```
background: gradientPrimary (#4F6EF7 → #7B93FF)
text: #FFFFFF
padding: 14px 28px
radius: 16px (full for FAB)
border-bottom: 3px solid #3A56D4
font-weight: 700
letter-spacing: 0.02em
pressed: translateY(3px), border-bottom: 0
```

**Secondary Button**
```
background: #FFFFFF
text: #4F6EF7
border: 2px solid #4F6EF7
border-bottom: 3px solid #3A56D4
radius: 16px
padding: 14px 28px
pressed: translateY(3px), border-bottom: 0
```

**Success Button (消灭)**
```
background: gradientSuccess (#34C759 → #66D97A)
text: #FFFFFF
border-bottom: 3px solid #28A745
```

**Danger Button**
```
background: #D32F2F
text: #FFFFFF
border-bottom: 3px solid #B71C1C
```

### 7.2 Cards

**Base Card (3 级阴影可选)**
```
background: #FFFFFF
border: 1.5px solid #E5E7EB
radius: 16px (lg)
shadow: elevation-1 (默认) / elevation-2 (交互)
padding: 16px
```

**Stat Card (统计卡片)**
```
background: gradientCard (#FFFFFF → #F8F9FC)
border: none
shadow: elevation-2
radius: 16px
number: 32px / 800 weight
accent-line: 3px solid statusColor (左侧竖线)
```

**Interactive Card (可点击卡片)**
```
border-bottom: 3px solid #E5E7EB
hover: lift 2px, shadow elevation-2
pressed: translateY(3px), border-bottom: 0
```

### 7.3 Chips / Tags

**Status Chip**
```
background: statusColor.withOpacity(0.1)
border: 1.5px solid statusColor.withOpacity(0.3)
radius: full (999px)
padding: 4px 12px
left-bar: 3px solid statusColor (圆角内左侧竖线)
text: statusColor, font-weight 600
```

**Filter Chip (选中态)**
```
selected-bg: brandPrimaryPale (#EEF1FE)
selected-border: 2px solid brandPrimary
selected-text: brandPrimary, weight 600
unselected-bg: #FFFFFF
unselected-border: 1.5px solid border
```

### 7.4 Progress Bar

**Standard**
```
track: #E5E7EB, radius full, height 8px
fill: gradientPrimary or gradientSuccess
radius: full
animation: 320ms ease-out
```

**Chunky (打卡/消灭进度)**
```
track: #E5E7EB, radius full, height 16px
fill: gradientWarm or gradientSuccess
radius: full
animation: 480ms cubic-bezier(0.34, 1.56, 0.64, 1) // overshoot
```

### 7.5 Bottom Navigation Bar

```
background: #FFFFFF (不透明，保持清晰)
height: 64px
shadow: elevation-3 (顶部阴影)
selected-icon: brandPrimary, size 24
selected-label: brandPrimary, weight 600
unselected: textTertiary
indicator: brandPrimaryPale circle behind icon
```

### 7.6 Checkin Streak Bar (打卡条)

```
background: gradientWarm (#FF8C42 → #FFB07A)
radius: 16px
padding: 14px 16px
border-bottom: 3px solid #E6732E
streak-number: 24px, weight 800, white
fire-icon: 24px, pulse animation (1.0 → 1.1, 1.6s loop)
```

### 7.7 Inputs

```
background: #FFFFFF
border: 1.5px solid #E5E7EB
radius: 12px (md)
padding: 12px 16px
focus: border 2px solid brandPrimary, ring 3px brandPrimaryPale
error: border 2px solid danger
```

---

## 8. Motion & Animation

### Duration Scale

| 类型 | 时长 | 用途 |
|------|------|------|
| `micro` | 120ms | 按钮按压、Chip 切换 |
| `short` | 200ms | 卡片 hover、状态切换 |
| `medium` | 320ms | 页面过渡、进度条填充 |
| `long` | 480ms | 消灭动画、弹窗出现 |
| `pulse` | 1600ms | 打卡火焰脉动、活跃节点呼吸 |

### Easing Curves

| 曲线 | 参数 | 用途 |
|------|------|------|
| `standard` | Cubic(0.4, 0.0, 0.2, 1.0) | 通用过渡 |
| `decelerate` | Cubic(0.0, 0.0, 0.2, 1.0) | 元素进入 |
| `accelerate` | Cubic(0.4, 0.0, 1.0, 1.0) | 元素退出 |
| `overshoot` | Cubic(0.34, 1.56, 0.64, 1.0) | 弹跳效果、成就解锁 |
| `spring` | SpringSimulation(mass:1, stiffness:200, damping:15) | 物理弹性 |

### Key Animations

| 动画 | 描述 |
|------|------|
| Button Press | translateY(3px) + border-bottom 消失, 120ms |
| Card Lift | translateY(-2px) + shadow elevation-2, 200ms |
| Streak Fire | scale 1.0→1.1→1.0, 1600ms loop |
| Progress Fill | width 0→target, 480ms overshoot |
| Eliminate | scale 1→1.2→0 + confetti particles, 480ms |
| Page Slide | SlideTransition + FadeTransition, 320ms |
| Today Pulse | opacity 0.8→1.0, 1600ms loop |

---

## 9. Iconography

| 属性 | 规格 |
|------|------|
| 库 | Material Icons (现有) + 关键位置增强 Emoji |
| 标准尺寸 | 24×24px |
| 线宽 | 1.5px (线性) |
| 激活色 | 跟随 brandPrimary |
| 禁用色 | textTertiary |
| Tab 栏 | 24px, 未选中 textTertiary, 选中 brandPrimary |
| 圆形底色 | 40×40px, statusColor.withOpacity(0.1), radius full |

### 小学生增强

| 分类 | Emoji | 底色 |
|------|-------|------|
| 知识性错误 | 🧠 | `#6C5CE7`.withOpacity(0.1) |
| 技能性错误 | ✏️ | `#0984E3`.withOpacity(0.1) |
| 心理性错误 | 😰 | `#E17055`.withOpacity(0.1) |
| 习惯性错误 | 📖 | `#FDCB6E`.withOpacity(0.1) |

---

## 10. Accessibility

- 所有文字与背景对比度 ≥ 4.5:1 (WCAG AA)
- 危险色 `#D32F2F` 在白底对比度 4.63:1 ✓
- 焦点态使用 3px ring 而非仅颜色变化
- 动效提供 `reduceMotion` 开关
- 最小触摸目标 48×48px (Material Design 标准)

---

## 11. Anti-patterns (避免)

| ❌ 不要 | ✅ 应该 |
|---------|---------|
| 所有按钮扁平无层次 | 主按钮 chunky 底影，次按钮边框 |
| 所有卡片同一种阴影 | 按交互重要性选 elevation-1/2/3 |
| 纯色背景按钮 | 渐变背景 + 底影，更有层次 |
| 数据数字和正文同大 | 数据数字 32px/800，制造视觉焦点 |
| 发丝线边框 (0.5px) | 1.5-2px 实线，更清晰 |
| 无反馈的点击 | 按压下沉 + 涟漪 + 状态变化 |
| 装饰性渐变滥用 | 仅在 CTA、进度、成就处使用渐变 |
| 每个元素都弹跳 | 仅在里程碑、消灭、打卡时使用 overshoot 曲线 |
