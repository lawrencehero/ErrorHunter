#!/usr/bin/env bash
# ============================================================
# 错题猎手（ErrorHunter）本地开发环境启动脚本
# 适用于 Linux / macOS
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- 1. 检查 Docker ----------
if ! command -v docker &>/dev/null; then
    error "未检测到 Docker，请先安装 Docker Desktop"
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    error "Docker 未运行，请先启动 Docker Desktop"
    exit 1
fi
info "Docker 运行正常 ✓"

# ---------- 2. 加载环境变量 ----------
if [ -f .env ]; then
    info "加载 .env 配置文件"
    set -a
    source .env
    set +a
else
    warn "未找到 .env 文件，将使用默认值"
    warn "建议执行: cp .env.example .env 并按需修改"
fi

# ---------- 3. 拉取镜像 ----------
info "拉取最新镜像..."
docker compose pull

# ---------- 4. 启动服务 ----------
info "启动基础设施服务..."
docker compose up -d

# ---------- 5. 等待健康检查 ----------
info "等待服务就绪..."

wait_healthy() {
    local service=$1
    local max_retries=30
    local count=0
    while [ $count -lt $max_retries ]; do
        status=$(docker compose ps --format json "$service" 2>/dev/null | grep -o '"Health":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
        if [ "$status" = "healthy" ]; then
            return 0
        fi
        sleep 2
        count=$((count + 1))
    done
    return 1
}

ALL_OK=true

if wait_healthy postgres; then
    info "PostgreSQL 就绪 ✓"
else
    warn "PostgreSQL 健康检查超时，请手动确认"
    ALL_OK=false
fi

if wait_healthy redis; then
    info "Redis 就绪 ✓"
else
    warn "Redis 健康检查超时，请手动确认"
    ALL_OK=false
fi

if wait_healthy minio; then
    info "MinIO 就绪 ✓"
else
    warn "MinIO 健康检查超时，请手动确认"
    ALL_OK=false
fi

# ---------- 6. 打印连接信息 ----------
echo ""
echo "============================================================"
echo "  错题猎手（ErrorHunter）本地开发环境"
echo "============================================================"
echo ""
echo "  📦 PostgreSQL"
echo "     Host:     localhost"
echo "     Port:     ${POSTGRES_PORT:-5432}"
echo "     Database: ${POSTGRES_DB:-errorhunter}"
echo "     User:     ${POSTGRES_USER:-errorhunter}"
echo "     Password: ${POSTGRES_PASSWORD:-errorhunter_dev}"
echo "     JDBC:     jdbc:postgresql://localhost:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-errorhunter}"
echo ""
echo "  🔴 Redis"
echo "     Host:     localhost"
echo "     Port:     ${REDIS_PORT:-6379}"
echo "     URL:      redis://localhost:${REDIS_PORT:-6379}"
echo ""
echo "  🪣 MinIO (S3-compatible)"
echo "     API:      http://localhost:${MINIO_API_PORT:-9000}"
echo "     Console:  http://localhost:${MINIO_CONSOLE_PORT:-9001}"
echo "     User:     ${MINIO_ROOT_USER:-minioadmin}"
echo "     Password: ${MINIO_ROOT_PASSWORD:-minioadmin123}"
echo ""
echo "============================================================"

if [ "$ALL_OK" = true ]; then
    info "🎉 所有服务已就绪！"
else
    warn "⚠️  部分服务可能仍在启动中，请稍后重试"
fi
