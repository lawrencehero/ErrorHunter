#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 v1.0.26 产品更新海报（自包含 HTML），再用 Chrome headless 截图为 PNG。
海报含精简发布日志 + 下载二维码。"""
import base64, subprocess, sys, os
from pathlib import Path
import qrcode
from io import BytesIO
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR = Path(__file__).resolve().parent
HTML_PATH = OUT_DIR / "poster-更新日志-v1.0.26.html"
PNG_PATH = OUT_DIR / "poster-更新日志-v1.0.26.png"
CHROME = os.environ.get("POSTER_CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")
# 下载页公网 URL；开源默认占位，实际发布前用环境变量 POSTER_DOWNLOAD_URL 覆盖
DOWNLOAD_URL = os.environ.get("POSTER_DOWNLOAD_URL", "http://<your-download-host>:8081/")
VERSION = "1.0.26"

# ── 生成下载二维码（高容错，便于扫描）──
qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=10, border=1)
qr.add_data(DOWNLOAD_URL)
qr.make(fit=True)
_qr_buf = BytesIO()
qr.make_image(fill_color="#1A1A2E", back_color="white").save(_qr_buf, format="PNG")
QR_URI = "data:image/png;base64," + base64.b64encode(_qr_buf.getvalue()).decode()

# ── App 图标（裁透明边）──
_icon_path = ROOT / "src" / "errorhunter_app" / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png"
_icon = Image.open(_icon_path).convert("RGBA")
_bbox = _icon.getbbox()
if _bbox:
    _icon = _icon.crop(_bbox)
_ib = BytesIO(); _icon.save(_ib, format="PNG")
ICON_URI = "data:image/png;base64," + base64.b64encode(_ib.getvalue()).decode()

HTML = """<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1080px;height:1620px;font-family:"Microsoft YaHei","PingFang SC","Noto Sans SC",sans-serif}
body{
  background:linear-gradient(160deg,#4F6EF7 0%,#6C5CE7 55%,#7B93FF 100%);
  color:#fff;padding:56px 52px;display:flex;flex-direction:column;
}
.header{display:flex;align-items:center;gap:20px;margin-bottom:8px}
.logo{width:88px;height:88px;border-radius:22px;box-shadow:0 8px 24px rgba(0,0,0,.25);background:#fff;padding:8px}
.title-box .app{font-size:34px;font-weight:900;letter-spacing:2px}
.title-box .ver{font-size:20px;font-weight:500;opacity:.92;margin-top:2px}
.date{margin-left:auto;font-size:20px;opacity:.9;background:rgba(255,255,255,.18);padding:8px 18px;border-radius:20px}
.banner{font-size:30px;font-weight:800;margin:18px 0 26px;letter-spacing:1px}
.banner .hi{color:#FFD66B}
.section{background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.22);border-radius:24px;padding:26px 30px;margin-bottom:18px;backdrop-filter:blur(4px)}
.sec-head{font-size:24px;font-weight:800;margin-bottom:14px;display:flex;align-items:center;gap:10px}
.sec-head .tag{font-size:13px;font-weight:600;background:rgba(255,255,255,.22);padding:4px 12px;border-radius:12px}
ul{list-style:none}
li{font-size:19px;line-height:1.62;padding:5px 0 5px 26px;position:relative;opacity:.97}
li:before{content:"";position:absolute;left:4px;top:14px;width:9px;height:9px;border-radius:50%;background:#FFD66B}
li b{color:#FFD66B;font-weight:700}
.s-new li:before{background:#9EF7B3}
.s-fix li:before{background:#FFB07A}
.s-opt li:before{background:#FFD66B}
.spacer{flex:1}
.download{display:flex;align-items:center;gap:26px;background:rgba(255,255,255,.96);border-radius:26px;padding:24px 30px;color:#1A1A2E;box-shadow:0 12px 32px rgba(0,0,0,.28)}
.qr-box{width:188px;height:188px;flex:none;background:#fff;padding:8px;border-radius:18px}
.qr-box img{width:100%;height:100%}
.dl-text{flex:1}
.dl-title{font-size:26px;font-weight:800;color:#1A1A2E}
.dl-sub{font-size:16px;color:#6B7280;margin-top:6px;line-height:1.5}
.dl-url{font-size:16px;color:#4F6EF7;font-weight:700;margin-top:8px}
.dl-meta{margin-top:10px;display:flex;gap:8px;flex-wrap:wrap}
.dl-tag{font-size:13px;background:#EEF1FE;color:#3A56D4;padding:5px 12px;border-radius:10px;font-weight:600}
.footer{margin-top:16px;text-align:center;font-size:14px;opacity:.82;letter-spacing:1px}
</style></head><body>
  <div class="header">
    <img class="logo" src="__ICON__">
    <div class="title-box">
      <div class="app">错题猎手</div>
      <div class="ver">ErrorHunter v__VERSION__</div>
    </div>
    <div class="date">2026 · 07 · 07</div>
  </div>
  <div class="banner">🚀 <span class="hi">v1.0.26</span> 更新来啦 · 复习体验全面升级</div>

  <div class="section s-new">
    <div class="sec-head">✨ 新功能 <span class="tag">NEW</span></div>
    <ul>
      <li>错题详情页可<b>「开始复习此题」</b>，单独复习一道题</li>
      <li>首页<b>「查看复习」</b>看今日成果：掌握/用时/消灭数</li>
      <li>错题本支持按<b>自定义标签</b>筛选</li>
      <li>复习进度显示<b>「下次复习」</b>日期，复习后自动更新</li>
      <li>复习历史折叠时可见<b>「共 N 轮」</b></li>
    </ul>
  </div>

  <div class="section s-opt">
    <div class="sec-head">🎨 体验优化</div>
    <ul>
      <li><b>「已消灭」图标</b>全新立体质感，按钮改庆祝绿</li>
      <li>复习历史展开更清爽，不再重复标题</li>
    </ul>
  </div>

  <div class="section s-fix">
    <div class="sec-head">🐛 问题修复</div>
    <ul>
      <li>复习历史轮次重复<b>「第1轮」</b>→ 按顺序正确显示</li>
      <li>复习时间<b>慢 8 小时</b>→ 显示本地时间</li>
      <li>短复习用时<b>「0 分钟」</b>→ 显示具体秒数</li>
    </ul>
  </div>

  <div class="spacer"></div>

  <div class="download">
    <div class="qr-box"><img src="__QR__"></div>
    <div class="dl-text">
      <div class="dl-title">📲 扫码下载最新版</div>
      <div class="dl-sub">手机微信/浏览器扫描二维码<br>即可下载安装错题猎手安卓版</div>
      <div class="dl-url">__DL_URL__/</div>
      <div class="dl-meta">
        <span class="dl-tag">🤖 Android</span>
        <span class="dl-tag">🏷 v1.0.26</span>
        <span class="dl-tag">📦 57.6 MB</span>
      </div>
    </div>
  </div>
  <div class="footer">错题猎手 ErrorHunter · 采集 → 归因 → 复习 → 消灭</div>
</body></html>"""

HTML = (HTML.replace("__ICON__", ICON_URI)
            .replace("__QR__", QR_URI)
            .replace("__VERSION__", VERSION)
            .replace("__DL_URL__", DOWNLOAD_URL))
HTML_PATH.write_text(HTML, encoding="utf-8")
print(f"HTML: {HTML_PATH}  ({len(HTML)} bytes)")

# Chrome headless 截图
cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
       "--hide-scrollbars", "--force-device-scale-factor=2",
       f"--screenshot={PNG_PATH}", "--window-size=1080,1620",
       "file:///" + str(HTML_PATH).replace("\\", "/")]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
print("chrome rc=", r.returncode)
if PNG_PATH.exists():
    print(f"PNG: {PNG_PATH}  ({PNG_PATH.stat().st_size} bytes)")
else:
    print("STDERR:", r.stderr[-800:])
    sys.exit(1)
