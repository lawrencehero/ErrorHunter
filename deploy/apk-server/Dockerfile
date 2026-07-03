# ============================================================
# 错题猎手 APK 下载服务器容器
# 复用 deploy/apk_server.py，在 python:3.11 环境运行（含 qrcode）
# APK 与 pubspec.yaml 通过 volume 挂载，构建时不需要打进镜像
# ============================================================
FROM python:3.11-slim

LABEL maintainer="ErrorHunter Ops <ops@errorhunter.dev>"
LABEL description="错题猎手 APK 下载服务器"

# 安装 qrcode + Pillow（生成 PNG 二维码）
RUN pip install --no-cache-dir qrcode pillow

WORKDIR /app

COPY apk_server.py /app/apk_server.py

# 默认端口 8081（避开后端 8080）；可由 APK_PORT 环境变量覆盖
ENV APK_PORT=8081
EXPOSE 8081

# 运行时通过环境变量注入：
#   APK_APK_PATH / APK_PUBSPEC_PATH / PUBLIC_URL / APK_QR_OUTPUT
CMD ["python3", "/app/apk_server.py"]
