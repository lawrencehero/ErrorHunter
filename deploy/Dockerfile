# ============================================================
# 错题猎手（ErrorHunter）Go 后端 — 多阶段构建
# 用法：docker build -t errorhunter-server:latest .
# ============================================================

# -------------------- Stage 1: Build --------------------
FROM golang:1.22-alpine AS builder

WORKDIR /build

# 安装构建依赖
RUN apk add --no-cache git ca-certificates tzdata gcc musl-dev

# 先复制 go mod 文件，利用 Docker 缓存层
COPY go.mod go.sum ./

# 使用国内 Go 模块代理（中国大陆网络环境）
ENV GOPROXY=https://goproxy.cn,direct

RUN go mod download && go mod verify

# 复制源码
COPY . .

# 编译（静态链接，去除调试符号）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)" \
    -o /build/server \
    ./cmd/server

# -------------------- Stage 2: Runtime --------------------
FROM alpine:3.20

LABEL maintainer="ErrorHunter Ops <ops@errorhunter.dev>"
LABEL description="错题猎手后端服务"

WORKDIR /app

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    busybox-extras \
    && addgroup -g 1001 -S errorhunter \
    && adduser -u 1001 -S errorhunter -G errorhunter

# 从 builder 复制二进制和配置
COPY --from=builder /build/server /app/server
COPY --from=builder /build/configs /app/configs

# 设置权限
RUN chown -R errorhunter:errorhunter /app

USER errorhunter

EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["./server"]
