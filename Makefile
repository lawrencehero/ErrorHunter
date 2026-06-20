# ============================================================
# 错题猎手（ErrorHunter）项目根 Makefile
# 统一管理 Docker、测试、开发常用命令
# ============================================================

.PHONY: help up down restart logs status test test-local db-shell redis-cli minio-console clean build dev lint fmt

# 变量
DEPLOY_DIR := deploy
COMPOSE_FILE := $(DEPLOY_DIR)/docker-compose.yml
COMPOSE_TEST_FILE := $(DEPLOY_DIR)/docker-compose.test.yml
SERVER_DIR := src/errorhunter_server

# ==================== 默认目标 ====================

help: ## 显示帮助信息
	@echo ""
	@echo "🎯 错题猎手（ErrorHunter）常用命令"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ==================== Docker Compose ====================

up: ## 启动所有服务
	@echo "🚀 启动 ErrorHunter 服务..."
	@cd $(DEPLOY_DIR) && docker compose up -d
	@echo ""
	@echo "✅ 服务已启动！"
	@echo "   API:      http://localhost:8080"
	@echo "   MinIO:    http://localhost:9001"
	@echo "   Health:   curl http://localhost:8080/health"

down: ## 停止并移除所有服务
	@echo "⏹️  停止 ErrorHunter 服务..."
	@cd $(DEPLOY_DIR) && docker compose down

restart: ## 重启所有服务
	@$(MAKE) down
	@$(MAKE) up

logs: ## 查看所有服务日志（Ctrl+C 退出）
	@cd $(DEPLOY_DIR) && docker compose logs -f

status: ## 查看服务状态
	@cd $(DEPLOY_DIR) && docker compose ps

build: ## 重新构建 server 镜像
	@echo "🔨 构建 server 镜像..."
	@cd $(DEPLOY_DIR) && docker compose build server

# ==================== 测试 ====================

test: ## 运行 Docker 集成测试
	@echo "🧪 运行集成测试..."
	@cd $(DEPLOY_DIR) && docker compose -f docker-compose.test.yml up \
		--abort-on-container-exit \
		--exit-code-from test-runner \
		--build
	@cd $(DEPLOY_DIR) && docker compose -f docker-compose.test.yml down -v

test-local: ## 本地运行 Go 测试（需先启动基础设施）
	@echo "🧪 运行本地测试..."
	@cd $(SERVER_DIR) && go test -v -race -cover ./...

test-coverage: ## 本地运行测试并生成覆盖率报告
	@echo "📊 生成测试覆盖率报告..."
	@cd $(SERVER_DIR) && go test -v -race -coverprofile=coverage.out ./...
	@cd $(SERVER_DIR) && go tool cover -html=coverage.out -o coverage.html
	@echo "✅ 覆盖率报告: $(SERVER_DIR)/coverage.html"

# ==================== 数据库 & Redis ====================

db-shell: ## 进入 PostgreSQL 命令行
	@docker exec -it errorhunter-postgres psql -U errorhunter -d errorhunter

redis-cli: ## 进入 Redis 命令行
	@docker exec -it errorhunter-redis redis-cli

minio-console: ## 打开 MinIO 控制台地址
	@echo "🗄️  MinIO Console: http://localhost:9001"
	@echo "   User: minioadmin"
	@echo "   Password: minioadmin123"

db-reset: ## 重置数据库（⚠️ 清除所有数据）
	@echo "⚠️  即将清除所有数据库数据..."
	@cd $(DEPLOY_DIR) && docker compose down -v
	@cd $(DEPLOY_DIR) && docker compose up -d postgres
	@echo "✅ 数据库已重置"

# ==================== 开发 ====================

dev: ## 本地开发模式（热重载，需安装 air）
	@cd $(SERVER_DIR) && air

lint: ## 运行代码检查
	@cd $(SERVER_DIR) && golangci-lint run ./...

fmt: ## 格式化代码
	@cd $(SERVER_DIR) && go fmt ./...

deps: ## 下载和整理依赖
	@cd $(SERVER_DIR) && go mod download && go mod tidy

# ==================== 清理 ====================

clean: ## 停止服务并清除所有数据卷 ⚠️
	@echo "⚠️  即将清除所有服务和数据..."
	@cd $(DEPLOY_DIR) && docker compose down -v --remove-orphans
	@cd $(DEPLOY_DIR) && docker compose -f docker-compose.test.yml down -v --remove-orphans 2>/dev/null || true
	@echo "✅ 清理完成"

clean-images: ## 清除构建的 Docker 镜像
	@docker rmi errorhunter-server 2>/dev/null || true
	@docker image prune -f
	@echo "✅ 镜像已清理"
