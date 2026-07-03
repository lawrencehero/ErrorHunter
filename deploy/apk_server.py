#!/usr/bin/env python3
"""
错题猎手 APK 下载服务器 + 二维码生成器
启动后手机扫码即可下载安装

用法:
    python deploy/apk_server.py          # 默认端口 8080
    python deploy/apk_server.py 9000     # 自定义端口
"""

import http.server
import socketserver
import socket
import os
import sys
import io

# 修复 Windows 控制台 GBK 编码问题
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

import qrcode
from pathlib import Path

# === 配置 ===
PROJECT_ROOT = Path(__file__).parent.parent
APK_PATH = PROJECT_ROOT / "src" / "errorhunter_app" / "build" / "app" / "outputs" / "apk" / "release" / "app-release.apk"
PUBSPEC_PATH = PROJECT_ROOT / "src" / "errorhunter_app" / "pubspec.yaml"
DEFAULT_PORT = 8080
QR_OUTPUT = PROJECT_ROOT / "deploy" / "apk-download-qr.png"

# 公网部署覆盖项（环境变量）：
#   APK_APK_PATH   — APK 文件绝对路径
#   APK_PUBSPEC_PATH — pubspec.yaml 路径（用于读版本号；缺失则回退默认）
#   APK_PORT       — 监听端口（默认 8080；公网部署建议避开后端 8080，用 8081）
#   PUBLIC_URL     — 公网下载根 URL（如 http://47.108.190.116:8081）；设置后二维码与
#                    落地页用它，否则自动探测本机局域网 IP
#   APK_QR_OUTPUT  — 二维码图片输出路径
APK_PATH = Path(os.environ.get("APK_APK_PATH") or str(APK_PATH))
PUBSPEC_PATH = Path(os.environ.get("APK_PUBSPEC_PATH") or str(PUBSPEC_PATH))
DEFAULT_PORT = int(os.environ.get("APK_PORT") or DEFAULT_PORT)
PUBLIC_URL = os.environ.get("PUBLIC_URL", "").rstrip("/")
QR_OUTPUT = Path(os.environ.get("APK_QR_OUTPUT") or str(QR_OUTPUT))


def get_app_version():
    """从 pubspec.yaml 读取版本号（version: X.Y.Z+N → 返回 X.Y.Z）"""
    try:
        for line in PUBSPEC_PATH.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("version:"):
                v = line.split(":", 1)[1].strip().split("+")[0].strip()
                return v or "1.0.0"
    except Exception:
        pass
    return "1.0.0"


def get_local_ip():
    """获取本机局域网 IP"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


class APKHandler(http.server.SimpleHTTPRequestHandler):
    """自定义 Handler，提供 APK 下载和状态页"""

    def __init__(self, *args, apk_path=None, **kwargs):
        self.apk_path = apk_path
        super().__init__(*args, **kwargs)

    def do_GET(self):
        if self.path in ("/download", "/download/"):
            self._serve_apk()
        elif self.path in ("/", ""):
            self._serve_landing_page()
        else:
            self.send_error(404)

    def _serve_apk(self):
        if not self.apk_path or not os.path.exists(self.apk_path):
            self.send_error(404, "APK file not found")
            return

        file_size = os.path.getsize(self.apk_path)
        self.send_response(200)
        self.send_header("Content-Type", "application/vnd.android.package-archive")
        self.send_header("Content-Disposition", f'attachment; filename="ErrorHunter-v{get_app_version()}.apk"')
        self.send_header("Content-Length", str(file_size))
        self.end_headers()

        with open(self.apk_path, "rb") as f:
            while True:
                chunk = f.read(65536)
                if not chunk:
                    break
                self.wfile.write(chunk)

    def _serve_landing_page(self):
        html = """\
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>错题猎手 - APK 下载</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
        }
        .card {
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            border-radius: 24px;
            padding: 48px 36px;
            text-align: center;
            max-width: 400px;
            width: 90%;
        }
        .icon { font-size: 72px; margin-bottom: 16px; }
        h1 { font-size: 28px; margin-bottom: 8px; }
        .version { opacity: 0.8; margin-bottom: 32px; font-size: 14px; }
        .btn {
            display: inline-block;
            background: #fff;
            color: #764ba2;
            padding: 16px 48px;
            border-radius: 50px;
            text-decoration: none;
            font-weight: 700;
            font-size: 18px;
            transition: transform 0.2s;
        }
        .btn:hover { transform: scale(1.05); }
        .info { margin-top: 24px; font-size: 13px; opacity: 0.7; line-height: 1.8; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">🎯</div>
        <h1>错题猎手</h1>
        <p class="version">ErrorHunter v__VERSION__ · Android APK</p>
        <a class="btn" href="/download">⬇ 下载安装</a>
        <p class="info">采集 → 归因 → 复习 → 消灭<br>错题全生命周期管理</p>
    </div>
</body>
</html>"""
        html = html.replace("__VERSION__", get_app_version())
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

    def log_message(self, fmt, *args):
        msg = fmt % args if args else fmt
        sys.stdout.write(f"  >> {msg}\n")
        sys.stdout.flush()


def generate_qr(url: str, output_path: Path):
    """生成二维码图片"""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,
        border=4,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#4a0e8f", back_color="white")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(output_path))
    return output_path


def print_qr_terminal(url: str):
    """在终端中打印二维码"""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=1,
        border=1,
    )
    qr.add_data(url)
    qr.make(fit=True)
    qr.print_ascii(invert=True)


def main():
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass

    # 检查 APK 文件
    if not APK_PATH.exists():
        sys.stdout.write(f"[ERROR] APK 文件不存在: {APK_PATH}\n")
        sys.stdout.write("        请先运行: flutter build apk --release\n")
        sys.exit(1)

    apk_size_mb = APK_PATH.stat().st_size / (1024 * 1024)
    if PUBLIC_URL:
        download_url = PUBLIC_URL + "/"
    else:
        local_ip = get_local_ip()
        download_url = f"http://{local_ip}:{port}/"

    # 生成二维码图片
    qr_path = generate_qr(download_url, QR_OUTPUT)

    # 打印信息
    sys.stdout.write("\n")
    sys.stdout.write("=" * 56 + "\n")
    sys.stdout.write("  🎯  错题猎手 APK 下载服务器\n")
    sys.stdout.write("=" * 56 + "\n")
    sys.stdout.write(f"  📦 APK 文件: {APK_PATH.name} ({apk_size_mb:.1f} MB)\n")
    sys.stdout.write(f"  🌐 下载地址: {download_url}\n")
    sys.stdout.write(f"  ⬇  直接下载: {download_url}download\n")
    sys.stdout.write(f"  🖼  二维码图片: {qr_path}\n")
    sys.stdout.write("\n")
    sys.stdout.write("  📱 手机扫描下方二维码即可下载:\n")
    sys.stdout.write("\n")
    sys.stdout.flush()

    print_qr_terminal(download_url)

    sys.stdout.write("\n")
    if PUBLIC_URL:
        sys.stdout.write("  🌍 公网模式：手机任意网络扫码即可下载（需安全组放行该端口）\n")
    else:
        sys.stdout.write("  ⚠️  确保手机和电脑在同一 WiFi 网络\n")
    sys.stdout.write("  🛑 按 Ctrl+C 停止服务器\n")
    sys.stdout.write("=" * 56 + "\n\n")
    sys.stdout.flush()

    # 启动 HTTP 服务器
    # 用 ThreadingTCPServer：每个请求独立线程，避免单个慢/卡死连接阻塞整个下载服务
    # （单线程 TCPServer 下，一个不正常关闭的连接会让服务彻底无响应，容器仍 Up 但 HTTP 超时）
    handler = lambda *a, **kw: APKHandler(*a, apk_path=str(APK_PATH), **kw)

    class _ThreadedServer(socketserver.ThreadingTCPServer):
        daemon_threads = True  # 主进程退出时线程立即结束，不阻塞关闭
        allow_reuse_address = True

    try:
        with _ThreadedServer(("0.0.0.0", port), handler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        sys.stdout.write("\n\n  ✅ 服务器已停止\n\n")
        sys.exit(0)
    except OSError as e:
        if e.errno == 10048:
            sys.stdout.write(f"\n  [ERROR] 端口 {port} 已被占用，请尝试: python {sys.argv[0]} {port + 1}\n")
            sys.exit(1)
        raise


if __name__ == "__main__":
    main()
