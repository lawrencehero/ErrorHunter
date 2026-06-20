---
name: 🐛 Bug 报告
description: 提交一个 Bug 报告，帮助我们改进错题猎手
title: "[Bug] "
labels: ["bug", "triage"]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        感谢你花时间提交 Bug 报告！请填写以下信息，帮助我们快速定位问题。

  - type: textarea
    id: description
    attributes:
      label: 📋 Bug 描述
      description: 简要描述你遇到的问题
      placeholder: 当我执行 XX 操作时，出现了 YY 错误...
    validations:
      required: true

  - type: textarea
    id: reproduce
    attributes:
      label: 🔄 复现步骤
      description: 详细的复现步骤
      placeholder: |
        1. 打开 XX 页面
        2. 点击 YY 按钮
        3. 输入 ZZ 数据
        4. 看到错误
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: ✅ 预期行为
      description: 你期望看到什么结果？
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: ❌ 实际行为
      description: 实际发生了什么？如有报错信息请粘贴
    validations:
      required: true

  - type: dropdown
    id: component
    attributes:
      label: 🏷️ 影响组件
      options:
        - 后端 API
        - 前端 App
        - 部署/基础设施
        - 数据库
        - 其他
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: 📦 版本信息
      description: 出错时的版本号或 Git Commit SHA
      placeholder: v1.0.0 / abc1234

  - type: dropdown
    id: environment
    attributes:
      label: 🌍 运行环境
      options:
        - 本地开发
        - Staging
        - Production
        - CI/CD 流水线

  - type: textarea
    id: logs
    attributes:
      label: 📜 日志/截图
      description: 相关日志、错误截图或录屏（可选）
      render: shell

  - type: textarea
    id: additional
    attributes:
      label: 💡 附加信息
      description: 其他有助于排查的信息（可选）
