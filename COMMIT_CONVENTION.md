# Git 提交规范

本项目采用 [Conventional Commits](https://www.conventionalcommits.org/) 规范。

## 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Type 类型

| type | 说明 |
|------|------|
| feat | 新功能 |
| fix | 修复 bug |
| docs | 文档变更 |
| style | 代码格式（不影响功能） |
| refactor | 重构（非新功能、非修复） |
| perf | 性能优化 |
| test | 测试相关 |
| build | 构建系统/外部依赖 |
| ops | 部署/基础设施（Ops agent） |
| chore | 杂项（不修改 src/test） |
| revert | 回滚 |

## Scope 范围

- `frontend` — Flutter 前端
- `backend` — Go 后端
- `infra` — 基础设施/Docker/CI
- `docs` — 文档
- `api` — API 契约

## 示例

```
feat(backend): 实现用户注册接口

- 支持手机号+短信验证码登录
- JWT 双 token 机制
- 单元测试覆盖率 > 80%

Closes #12
```

```
ops(infra): docker-compose 一键启动 PG/Redis/MinIO

- 配置阿里云镜像源
- 持久化卷配置
- 健康检查

Co-Authored-By: Claude Opus 4.1 <noreply@anthropic.com>
```
