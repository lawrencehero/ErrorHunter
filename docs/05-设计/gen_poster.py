#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成自包含 HTML 介绍海报：内嵌 App 图标 + 下载二维码 + 子集化字体（全部 base64）。"""
import base64
import os
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
QR = base64.b64encode((ROOT / "deploy" / "apk-download-qr.png").read_bytes()).decode()
# 下载页公网 URL；开源默认占位，实际发布前用环境变量 POSTER_DOWNLOAD_URL 覆盖
DOWNLOAD_URL = os.environ.get("POSTER_DOWNLOAD_URL", "http://<your-download-host>:8081/").rstrip("/")

# 读 App 图标并裁掉透明边距，避免图形只占画布中心一小块、在 logo 框里"缩一圈"
from PIL import Image as _PILImage
from io import BytesIO as _BytesIO
_icon_path = ROOT / "src" / "errorhunter_app" / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png"
_icon_im = _PILImage.open(_icon_path).convert("RGBA")
_icon_bbox = _icon_im.getbbox()  # 非透明区域边界
if _icon_bbox:
    _icon_im = _icon_im.crop(_icon_bbox)
_buf = _BytesIO()
_icon_im.save(_buf, format="PNG")
ICON = base64.b64encode(_buf.getvalue()).decode()
QR_URI = f"data:image/png;base64,{QR}"
ICON_URI = f"data:image/png;base64,{ICON}"

# 动态读取版本号与 APK 体积，避免海报硬编码过时
def _read_version() -> str:
    for line in (ROOT / "src" / "errorhunter_app" / "pubspec.yaml").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("version:"):
            # version: 1.0.24+25 → 1.0.24
            return line.split(":", 1)[1].strip().split("+")[0]
    return "0.0.0"

APK_PATH = ROOT / "deploy" / "apk" / "app-release.apk"
if not APK_PATH.exists():
    # 本机没有 APK 副本时回退到构建产物
    APK_PATH = ROOT / "src" / "errorhunter_app" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
VERSION = _read_version()
SIZE_MB = f"{APK_PATH.stat().st_size / 1048576:.1f}" if APK_PATH.exists() else "—"

# ── 子集化 Noto Sans SC 并内嵌为 base64，确保 headless 渲染/任意机器打开都字体一致 ──
FONT_CACHE = Path(__file__).resolve().parent / "_font_cache"
FONT_WEIGHTS = [300, 400, 500, 700, 900]

def _download(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 Chrome/120"})
    return urllib.request.urlopen(req, timeout=30).read()

def _subset_font_face(weight: int, chars: str) -> str:
    """返回单个字重的 @font-face 块，src 内嵌子集化 woff2 base64。"""
    cache_dir = FONT_CACHE
    cache_dir.mkdir(exist_ok=True)
    # 用字符集指纹做缓存键，避免重复下载/子集化
    key = hashlib.md5(chars.encode()).hexdigest()[:10]
    cache_file = cache_dir / f"noto-sc-{weight}-{key}.woff2.b64"
    if cache_file.exists():
        b64 = cache_file.read_text(encoding="utf-8")
    else:
        # 取 Google Fonts CSS（带缓存；googleapis 限流时回退本地 _gfont.css）
        css_file = cache_dir / "noto-sc.css"
        if not css_file.exists():
            legacy = Path(__file__).resolve().parent / "_gfont.css"
            try:
                css = _download(
                    "https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght="
                    + ";".join(str(w) for w in FONT_WEIGHTS) + "&display=swap"
                ).decode("utf-8")
                css_file.write_text(css, encoding="utf-8")
            except Exception:
                css = legacy.read_text(encoding="utf-8") if legacy.exists() else ""
        else:
            css = css_file.read_text(encoding="utf-8")
        m = re.search(r"font-weight:\s*" + str(weight) + r";.*?url\((https://[^)]+\.ttf)\)", css, re.S)
        if not m:
            raise RuntimeError(f"未找到 weight {weight} 的 ttf 链接")
        # ttf 在 fonts.gstatic.com（与 css 不同主机，通常不限流）
        ttf = _download(m.group(1))
        # 子集化：只保留海报用到的字 + 基本ASCII，转 woff2
        from fontTools import subset
        options = subset.Options()
        options.flavor = "woff2"
        options.layout_features = ["*"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=chars)
        from io import BytesIO
        font = subset.load_font(BytesIO(ttf), options)
        subsetter.subset(font)
        buf = BytesIO()
        font.save(buf, reorderTables=True)
        b64 = base64.b64encode(buf.getvalue()).decode()
        cache_file.write_text(b64, encoding="utf-8")
        # 顺带清理同字重的旧缓存
        for f in cache_dir.glob(f"noto-sc-{weight}-*.woff2.b64"):
            if f != cache_file:
                f.unlink(missing_ok=True)
    return (
        f"@font-face{{font-family:'Noto Sans SC';font-style:normal;font-weight:{weight};"
        f"font-display:block;src:url(data:font/woff2;base64,{b64}) format('woff2')}}"
    )

def build_font_face(html: str) -> str:
    """从 HTML 可见文本收集字符，生成全部字重的 @font-face。"""
    # 去掉 <style>/<script> 内容与标签，只留可见文本
    text = re.sub(r"<(style|script)[^>]*>.*?</\1>", " ", html, flags=re.S)
    text = re.sub(r"<[^>]+>", " ", text)
    chars = set(text)
    chars.update(" \t\n0123456789%·+-×/:.。,，、；：！？「」『』（）()[]【】…—·")
    char_str = "".join(sorted(chars))
    return "\n  ".join(_subset_font_face(w, char_str) for w in FONT_WEIGHTS)

import hashlib  # noqa: E402（放此处便于阅读，子集化用）

HTML = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>错题猎手 - App 介绍海报</title>
<style>
  /* __FONT_FACE__ */
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    display:flex; justify-content:center; align-items:flex-start;
    min-height:100vh; background:#08080f; padding:40px 0;
    font-family:'Noto Sans SC',-apple-system,sans-serif;
  }
  .poster {
    width:1080px; position:relative; overflow:hidden;
    background:linear-gradient(165deg,#0f0c29 0%,#1a1a3e 35%,#24243e 65%,#1a1a2e 100%);
    padding-bottom:64px;
  }
  .orb { position:absolute; border-radius:50%; filter:blur(90px); opacity:.35; z-index:0; }
  .orb-1 { width:480px; height:480px; background:#667EEA; top:-120px; right:-80px; }
  .orb-2 { width:380px; height:380px; background:#F093FB; bottom:680px; left:-120px; }
  .orb-3 { width:300px; height:300px; background:#FF8C42; top:640px; right:-60px; opacity:.2; }

  /* ── Hero ── */
  .hero { position:relative; z-index:2; text-align:center; padding:64px 56px 8px; }
  .hero-icon {
    width:200px; height:200px; border-radius:48px; margin:0 auto 28px;
    box-shadow:0 16px 64px rgba(79,110,247,.55);
    object-fit:cover;
  }
  .hero-name { font-size:64px; font-weight:900; color:#fff; letter-spacing:8px; text-shadow:0 4px 24px rgba(79,110,247,.3); }
  .hero-slogan { font-size:26px; color:rgba(255,255,255,.65); margin-top:10px; font-weight:300; letter-spacing:4px; }
  .hero-pills { margin-top:22px; display:flex; gap:12px; justify-content:center; flex-wrap:wrap; }
  .pill {
    font-size:16px; font-weight:600; padding:8px 20px; border-radius:20px;
    background:rgba(255,255,255,.08); border:1px solid rgba(255,255,255,.14); color:rgba(255,255,255,.8);
  }
  .pill.accent { background:linear-gradient(135deg,#4F6EF7,#667EEA); border:none; color:#fff; }

  .sec-label { position:relative; z-index:2; text-align:center; font-size:18px; color:rgba(255,255,255,.4); letter-spacing:8px; font-weight:400; margin:40px 0 24px; }

  /* ── 流程闭环 ── */
  .flow { position:relative; z-index:2; margin:0 56px; display:flex; align-items:center; justify-content:space-between;
    background:rgba(255,255,255,.05); border:1px solid rgba(255,255,255,.08); border-radius:18px; padding:18px 24px; }
  .flow-step { text-align:center; flex:1; }
  .flow-step .emo { font-size:30px; }
  .flow-step .name { font-size:15px; font-weight:700; color:rgba(255,255,255,.9); margin-top:4px; }
  .flow-step .desc { font-size:11px; color:rgba(255,255,255,.4); margin-top:2px; }
  .flow-arrow { color:rgba(255,255,255,.25); font-size:20px; }

  /* ── 手机效果图 ── */
  .phones { position:relative; z-index:2; display:flex; gap:24px; justify-content:center; padding:0 40px; }
  .phone-wrap { text-align:center; }
  .phone { width:400px; height:800px; border-radius:40px; overflow:hidden; position:relative;
    box-shadow:0 24px 64px rgba(0,0,0,.5), inset 0 0 0 2px rgba(255,255,255,.08); }
  .phone-title { margin-top:14px; font-size:20px; font-weight:700; color:rgba(255,255,255,.85); letter-spacing:2px; }
  .phone-sub { margin-top:4px; font-size:13px; color:rgba(255,255,255,.35); letter-spacing:1px; }
  .scr { width:100%; height:100%; position:relative; }
  .safe-top { height:40px; }
  .greet { padding:0 20px; display:flex; align-items:center; justify-content:space-between; }
  .greet-text { font-size:21px; font-weight:800; }
  .streak-pill { display:inline-flex; align-items:center; gap:3px; padding:3px 12px; border-radius:16px; font-size:13px; font-weight:800; }
  .content { padding:14px 18px 80px; display:flex; flex-direction:column; gap:10px; position:relative; z-index:1; }

  /* 游戏化 */
  .scr-g { background:#F8F9FC; }
  .scr-g .safe-top { background:#4F6EF7; }
  .scr-g .greet { background:#4F6EF7; padding-bottom:20px; border-radius:0 0 24px 24px; }
  .scr-g .greet-text { color:#fff; }
  .scr-g .streak-pill { background:rgba(255,255,255,.2); border:1px solid rgba(255,255,255,.3); color:#fff; }
  .g-card { background:#fff; border-radius:16px; padding:14px; box-shadow:0 2px 6px rgba(0,0,0,.04), 0 3px 0 #e8e8e8; }
  .g-streak { background:linear-gradient(135deg,#FF8C42,#FF6B6B); border-radius:16px; padding:12px 14px; box-shadow:0 3px 0 #d4654a; display:flex; align-items:center; gap:10px; }
  .g-streak .num { font-size:30px; font-weight:800; color:#fff; }
  .g-streak .lbl { font-size:11px; color:rgba(255,255,255,.85); font-weight:600; }
  .g-streak .trophy { margin-left:auto; font-size:22px; }
  .g-task-badge { display:inline-block; background:#E8EDFF; color:#4F6EF7; font-size:10px; font-weight:700; padding:2px 8px; border-radius:12px; }
  .g-task-num { font-size:42px; font-weight:800; color:#4F6EF7; letter-spacing:-2px; line-height:1; }
  .g-task-lbl { font-size:14px; font-weight:600; color:#1a1a2e; }
  .g-task-btn { background:linear-gradient(135deg,#4F6EF7,#667EEA); border-radius:12px; padding:10px; text-align:center; color:#fff; font-weight:800; font-size:13px; box-shadow:0 3px 0 #3a54c4; margin-top:6px; }
  .stats-row { display:flex; gap:6px; }
  .g-stat { flex:1; background:#fff; border-radius:12px; padding:10px 6px; text-align:center; box-shadow:0 2px 4px rgba(0,0,0,.03), 0 2px 0 #e8e8e8; }
  .g-stat .n { font-size:20px; font-weight:800; }
  .g-stat .l { font-size:9px; color:#6B7280; margin-top:1px; }
  .n-o { color:#FF8C42; } .n-g { color:#34C759; } .n-p { color:#9B59B6; }
  .section-hdr { display:flex; align-items:center; gap:6px; margin-bottom:8px; }
  .section-hdr .icon-circle { width:24px; height:24px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:12px; }
  .section-hdr .title { font-size:14px; font-weight:700; }
  .kp-item { display:flex; align-items:center; gap:8px; margin-bottom:6px; }
  .kp-rank { width:22px; height:22px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:800; color:#fff; flex-shrink:0; }
  .kp-name { font-size:12px; font-weight:600; flex:1; }
  .kp-bar-wrap { width:80px; height:6px; border-radius:3px; overflow:hidden; flex-shrink:0; }
  .kp-bar { height:100%; border-radius:3px; }
  .kp-count { font-size:11px; font-weight:700; flex-shrink:0; width:32px; text-align:right; }
  .bnav { position:absolute; bottom:0; left:0; right:0; height:64px; display:flex; align-items:center; justify-content:space-around; padding:0 8px; }
  .bnav-g { background:#fff; box-shadow:0 -3px 12px rgba(0,0,0,.05); }
  .bnav-item { display:flex; flex-direction:column; align-items:center; gap:1px; font-size:9px; color:#9CA3AF; }
  .bnav-item.active { color:#4F6EF7; }
  .bnav-icon { font-size:18px; }
  .bnav-fab { width:46px; height:46px; background:linear-gradient(135deg,#4F6EF7,#667EEA); border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:22px; color:#fff; margin-top:-16px; box-shadow:0 4px 14px rgba(79,110,247,.4), 0 0 0 3px #fff; }

  /* 玻璃拟态 */
  .scr-gl { background:linear-gradient(160deg,#667EEA 0%,#764BA2 50%,#F093FB 100%); }
  .scr-gl .greet-text { color:#fff; }
  .scr-gl .streak-pill { background:rgba(255,255,255,.15); border:1px solid rgba(255,255,255,.2); color:#fff; }
  .gl-orb { position:absolute; border-radius:50%; filter:blur(40px); }
  .gl-orb-1 { width:180px; height:180px; background:rgba(79,110,247,.45); top:-30px; right:-20px; }
  .gl-orb-2 { width:140px; height:140px; background:rgba(255,140,66,.35); bottom:120px; left:-30px; }
  .gl-card { background:rgba(255,255,255,.12); border:1px solid rgba(255,255,255,.18); border-radius:16px; padding:14px; backdrop-filter:blur(16px); }
  .gl-streak { display:flex; align-items:center; gap:10px; }
  .gl-streak .num { font-size:28px; font-weight:800; color:#FFB07A; }
  .gl-streak .lbl { font-size:11px; color:rgba(255,255,255,.7); font-weight:600; }
  .gl-task-badge { display:inline-block; background:rgba(255,255,255,.1); font-size:10px; font-weight:700; padding:2px 8px; border-radius:12px; color:rgba(255,255,255,.7); }
  .gl-task-num { font-size:42px; font-weight:800; color:#fff; letter-spacing:-2px; line-height:1; }
  .gl-task-lbl { font-size:14px; font-weight:600; color:rgba(255,255,255,.8); }
  .gl-task-btn { background:linear-gradient(135deg,#4F6EF7,#667EEA); border-radius:12px; padding:10px; text-align:center; color:#fff; font-weight:800; font-size:13px; margin-top:6px; }
  .gl-stat { flex:1; background:rgba(255,255,255,.1); border:1px solid rgba(255,255,255,.15); border-radius:12px; padding:10px 6px; text-align:center; }
  .gl-stat .n { font-size:20px; font-weight:800; }
  .gl-stat .l { font-size:9px; color:rgba(255,255,255,.6); margin-top:1px; }
  .n-amber { color:#FFB74D; } .n-mint { color:#81C784; } .n-lilac { color:#CE93D8; }
  .gl-section-hdr .icon-circle { background:rgba(255,255,255,.1); }
  .gl-section-hdr .title { color:#fff; }
  .gl-kp-name { color:rgba(255,255,255,.9); }
  .gl-kp-bar-wrap { background:rgba(255,255,255,.1); }
  .gl-kp-count { color:rgba(255,255,255,.7); }
  .gl-week .d-label { color:rgba(255,255,255,.5); }
  .gl-week .d-circle-done { background:linear-gradient(135deg,#34C759,#30D158); color:#fff; }
  .gl-week .d-circle-today { background:transparent; border:2px solid #fff; color:#fff; }
  .gl-week .d-circle-empty { background:rgba(255,255,255,.05); border:1px solid rgba(255,255,255,.1); color:rgba(255,255,255,.2); }
  .g-week .d-label { color:#6B7280; }
  .g-week .d-circle-done { background:linear-gradient(135deg,#34C759,#30D158); color:#fff; }
  .g-week .d-circle-today { background:transparent; border:2px solid #4F6EF7; color:#4F6EF7; }
  .g-week .d-circle-empty { background:#F3F4F6; border:1px solid #E8E8E8; color:#C9C9C9; }
  .bnav-gl { background:rgba(255,255,255,.08); border-top:1px solid rgba(255,255,255,.1); }
  .bnav-gl .bnav-item { color:rgba(255,255,255,.5); }
  .bnav-gl .bnav-item.active { color:#fff; }
  .week-row { display:flex; justify-content:space-between; }
  .week-day { text-align:center; }
  .week-day .d-label { font-size:10px; font-weight:600; margin-bottom:4px; }
  .week-day .d-circle { width:28px; height:28px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:800; margin:0 auto; }

  /* ── 特点 ── */
  .advantages { position:relative; z-index:2; padding:0 56px; margin-top:8px; }
  .adv-grid { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
  .adv-item { background:rgba(255,255,255,.06); border:1px solid rgba(255,255,255,.08); border-radius:16px; padding:18px 20px; display:flex; align-items:flex-start; gap:14px; }
  .adv-emoji { width:44px; height:44px; border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:22px; flex-shrink:0; }
  .adv-emoji.e1 { background:rgba(255,140,66,.15); } .adv-emoji.e2 { background:rgba(79,110,247,.15); }
  .adv-emoji.e3 { background:rgba(52,199,89,.15); } .adv-emoji.e4 { background:rgba(155,89,182,.15); }
  .adv-emoji.e5 { background:rgba(240,147,251,.15); } .adv-emoji.e6 { background:rgba(255,107,107,.15); }
  .adv-text .adv-h { font-size:17px; font-weight:700; color:rgba(255,255,255,.9); margin-bottom:3px; }
  .adv-text .adv-d { font-size:13px; color:rgba(255,255,255,.45); line-height:1.4; }

  /* ── 下载区 ── */
  .download { position:relative; z-index:2; margin:44px 56px 0; border-radius:24px; padding:36px 40px;
    background:linear-gradient(135deg, rgba(79,110,247,.18), rgba(240,147,251,.12));
    border:1px solid rgba(255,255,255,.14); display:flex; align-items:center; gap:36px; }
  .qr-box { background:#fff; padding:16px; border-radius:20px; flex-shrink:0; box-shadow:0 12px 36px rgba(0,0,0,.3); }
  .qr-box img { width:220px; height:220px; display:block; }
  .dl-text { flex:1; }
  .dl-title { font-size:34px; font-weight:900; color:#fff; letter-spacing:2px; }
  .dl-sub { font-size:16px; color:rgba(255,255,255,.6); margin-top:8px; line-height:1.6; }
  .dl-url { margin-top:14px; display:inline-block; font-size:15px; font-weight:600; color:#fff;
    background:rgba(0,0,0,.25); padding:8px 16px; border-radius:10px; font-family:monospace; }
  .dl-meta { margin-top:14px; display:flex; gap:10px; flex-wrap:wrap; }
  .dl-tag { font-size:13px; color:rgba(255,255,255,.75); background:rgba(255,255,255,.1); padding:5px 14px; border-radius:14px; }

  .footer { position:relative; z-index:2; text-align:center; padding:32px 0 0; }
  .footer-copy { font-size:14px; color:rgba(255,255,255,.2); letter-spacing:1px; }
</style>
</head>
<body>
<div class="poster">
  <div class="orb orb-1"></div>
  <div class="orb orb-2"></div>
  <div class="orb orb-3"></div>

  <!-- Hero -->
  <div class="hero">
    <img class="hero-icon" src="__ICON_DATA__" alt="错题猎手">
    <div class="hero-name">错题猎手</div>
    <div class="hero-slogan">消灭错题，每天进步一点点</div>
    <div class="hero-pills">
      <span class="pill accent">🎯 采集→归因→复习→消灭</span>
      <span class="pill">适合小学 3~6 年级 · 初中</span>
    </div>
  </div>

  <!-- 闭环流程 -->
  <div class="flow">
    <div class="flow-step"><div class="emo">📷</div><div class="name">采集</div><div class="desc">拍照录入</div></div>
    <div class="flow-arrow">›</div>
    <div class="flow-step"><div class="emo">🧠</div><div class="name">归因</div><div class="desc">错因分析</div></div>
    <div class="flow-arrow">›</div>
    <div class="flow-step"><div class="emo">🃏</div><div class="name">复习</div><div class="desc">翻卡复习</div></div>
    <div class="flow-arrow">›</div>
    <div class="flow-step"><div class="emo">🏆</div><div class="name">消灭</div><div class="desc">彻底掌握</div></div>
  </div>

  <div class="sec-label">· 实机效果图 ·</div>
  <div class="phones">
    <!-- 游戏化 -->
    <div class="phone-wrap">
      <div class="phone">
        <div class="scr scr-g">
          <div class="safe-top"></div>
          <div class="greet"><span class="greet-text">Hi，小明 👋</span><span class="streak-pill">🔥 12天</span></div>
          <div class="content">
            <div class="g-streak"><span style="font-size:22px">🔥</span><div><div class="lbl">连续打卡</div><div class="num">12<span style="font-size:14px;font-weight:700"> 天</span></div></div><span class="trophy">🏆</span></div>
            <div class="g-card">
              <div class="g-task-badge">📝 今日任务</div>
              <div style="display:flex;align-items:baseline;gap:4px;margin:4px 0"><span class="g-task-num">8</span><span class="g-task-lbl">道错题等你复习</span></div>
              <div class="g-task-btn">▶ 开始复习</div>
            </div>
            <div class="stats-row">
              <div class="g-stat"><div class="n n-o">156</div><div class="l">累计错题</div></div>
              <div class="g-stat"><div class="n n-g">98</div><div class="l">已消灭</div></div>
              <div class="g-stat"><div class="n n-p">63%</div><div class="l">消灭率</div></div>
            </div>
            <div class="g-card">
              <div class="section-hdr"><div class="icon-circle" style="background:#FFF3E0"><span style="color:#FF9800">⚠</span></div><span class="title" style="color:#1a1a2e">薄弱知识点</span></div>
              <div class="kp-item"><div class="kp-rank" style="background:#FF6B6B">1</div><span class="kp-name" style="color:#1a1a2e">分数加减法</span><div class="kp-bar-wrap" style="background:#FF6B6B15"><div class="kp-bar" style="width:100%;background:#FF6B6B"></div></div><span class="kp-count" style="color:#FF6B6B">12题</span></div>
              <div class="kp-item"><div class="kp-rank" style="background:#4F6EF7">2</div><span class="kp-name" style="color:#1a1a2e">几何面积</span><div class="kp-bar-wrap" style="background:#4F6EF715"><div class="kp-bar" style="width:67%;background:#4F6EF7"></div></div><span class="kp-count" style="color:#4F6EF7">8题</span></div>
              <div class="kp-item"><div class="kp-rank" style="background:#9B59B6">3</div><span class="kp-name" style="color:#1a1a2e">审题不清</span><div class="kp-bar-wrap" style="background:#9B59B615"><div class="kp-bar" style="width:50%;background:#9B59B6"></div></div><span class="kp-count" style="color:#9B59B6">6题</span></div>
            </div>
            <div class="g-card">
              <div class="section-hdr"><div class="icon-circle" style="background:#E8F5E9"><span style="color:#34C759">📅</span></div><span class="title" style="color:#1a1a2e">本周打卡</span><span style="margin-left:auto;font-size:11px;font-weight:700;color:#34C759">5/7 天</span></div>
              <div class="week-row g-week">
                <div class="week-day"><div class="d-label">一</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">二</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">三</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">四</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">五</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">六</div><div class="d-circle d-circle-today">·</div></div>
                <div class="week-day"><div class="d-label">日</div><div class="d-circle d-circle-empty"></div></div>
              </div>
              <div style="margin-top:10px;font-size:11px;color:#6B7280;text-align:center">🔥 连续 12 天，再打卡 2 天解锁「半月勋章」</div>
            </div>
          </div>
          <div class="bnav bnav-g">
            <div class="bnav-item active"><span class="bnav-icon">🏠</span>首页</div>
            <div class="bnav-item"><span class="bnav-icon">📚</span>错题本</div>
            <div class="bnav-fab">＋</div>
            <div class="bnav-item"><span class="bnav-icon">📊</span>周报</div>
            <div class="bnav-item"><span class="bnav-icon">👤</span>我的</div>
          </div>
        </div>
      </div>
      <div class="phone-title">🎮 游戏化</div>
      <div class="phone-sub">Duolingo 风格 · 活力满满</div>
    </div>

    <!-- 玻璃拟态 -->
    <div class="phone-wrap">
      <div class="phone">
        <div class="scr scr-gl">
          <div class="gl-orb gl-orb-1"></div><div class="gl-orb gl-orb-2"></div>
          <div class="safe-top"></div>
          <div class="greet"><span class="greet-text">Hi，小明 👋</span><span class="streak-pill">🔥 12天</span></div>
          <div class="content">
            <div class="gl-card gl-streak"><span style="font-size:20px">🔥</span><div><div class="lbl">连续打卡</div><div class="num">12<span style="font-size:12px;font-weight:700"> 天</span></div></div></div>
            <div class="gl-card">
              <div class="gl-task-badge">📝 今日任务</div>
              <div style="display:flex;align-items:baseline;gap:4px;margin:4px 0"><span class="gl-task-num">8</span><span class="gl-task-lbl">道错题等你复习</span></div>
              <div class="gl-task-btn">▶ 开始复习</div>
            </div>
            <div class="stats-row">
              <div class="gl-stat"><div class="n n-amber">156</div><div class="l">累计错题</div></div>
              <div class="gl-stat"><div class="n n-mint">98</div><div class="l">已消灭</div></div>
              <div class="gl-stat"><div class="n n-lilac">63%</div><div class="l">消灭率</div></div>
            </div>
            <div class="gl-card">
              <div class="section-hdr gl-section-hdr"><div class="icon-circle"><span style="color:rgba(255,255,255,.7)">⚠</span></div><span class="title">薄弱知识点</span></div>
              <div class="kp-item"><div class="kp-rank" style="background:#FF6B6B">1</div><span class="kp-name gl-kp-name">分数加减法</span><div class="kp-bar-wrap gl-kp-bar-wrap"><div class="kp-bar" style="width:100%;background:#FF6B6B"></div></div><span class="kp-count gl-kp-count">12题</span></div>
              <div class="kp-item"><div class="kp-rank" style="background:#667EEA">2</div><span class="kp-name gl-kp-name">几何面积</span><div class="kp-bar-wrap gl-kp-bar-wrap"><div class="kp-bar" style="width:67%;background:#667EEA"></div></div><span class="kp-count gl-kp-count">8题</span></div>
              <div class="kp-item"><div class="kp-rank" style="background:#CE93D8">3</div><span class="kp-name gl-kp-name">审题不清</span><div class="kp-bar-wrap gl-kp-bar-wrap"><div class="kp-bar" style="width:50%;background:#CE93D8"></div></div><span class="kp-count gl-kp-count">6题</span></div>
            </div>
            <div class="gl-card">
              <div class="section-hdr gl-section-hdr"><div class="icon-circle"><span style="color:rgba(255,255,255,.7)">📅</span></div><span class="title">本周打卡</span><span style="margin-left:auto;font-size:11px;font-weight:700;color:#81C784">5/7 天</span></div>
              <div class="week-row gl-week">
                <div class="week-day"><div class="d-label">一</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">二</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">三</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">四</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">五</div><div class="d-circle d-circle-done">✓</div></div>
                <div class="week-day"><div class="d-label">六</div><div class="d-circle d-circle-today">·</div></div>
                <div class="week-day"><div class="d-label">日</div><div class="d-circle d-circle-empty"></div></div>
              </div>
              <div style="margin-top:10px;font-size:11px;color:rgba(255,255,255,.6);text-align:center">🔥 连续 12 天，再打卡 2 天解锁「半月勋章」</div>
            </div>
          </div>
          <div class="bnav bnav-gl">
            <div class="bnav-item active"><span class="bnav-icon">🏠</span>首页</div>
            <div class="bnav-item"><span class="bnav-icon">📚</span>错题本</div>
            <div class="bnav-fab">＋</div>
            <div class="bnav-item"><span class="bnav-icon">📊</span>周报</div>
            <div class="bnav-item"><span class="bnav-icon">👤</span>我的</div>
          </div>
        </div>
      </div>
      <div class="phone-title">✨ 玻璃拟态</div>
      <div class="phone-sub">毛玻璃卡片 · 通透轻盈</div>
    </div>
  </div>

  <div class="sec-label">· 产品特点 ·</div>
  <div class="advantages">
    <div class="adv-grid">
      <div class="adv-item"><div class="adv-emoji e1">📷</div><div class="adv-text"><div class="adv-h">拍照智能录入</div><div class="adv-d">拍一张照片，AI 自动识别题目文字，告别手抄</div></div></div>
      <div class="adv-item"><div class="adv-emoji e2">🧠</div><div class="adv-text"><div class="adv-h">错因深度归因</div><div class="adv-d">不只记录对错，更分析"为什么错"，精准定位薄弱点</div></div></div>
      <div class="adv-item"><div class="adv-emoji e3">🃏</div><div class="adv-text"><div class="adv-h">翻卡趣味复习</div><div class="adv-d">游戏化翻卡复习，自评+消灭机制，让复习不再枯燥</div></div></div>
      <div class="adv-item"><div class="adv-emoji e4">📊</div><div class="adv-text"><div class="adv-h">学情周报追踪</div><div class="adv-d">每周自动生成学习报告，进步看得见，家长更放心</div></div></div>
      <div class="adv-item"><div class="adv-emoji e5">🎨</div><div class="adv-text"><div class="adv-h">双主题随心换</div><div class="adv-d">游戏化 / 玻璃拟态两套 UI，小学生初中生都爱用</div></div></div>
      <div class="adv-item"><div class="adv-emoji e6">🎯</div><div class="adv-text"><div class="adv-h">错题全生命周期</div><div class="adv-d">采集→归因→复习→消灭，形成完整学习闭环</div></div></div>
    </div>
  </div>

  <!-- 下载区 -->
  <div class="download">
    <div class="qr-box"><img src="__QR_DATA__" alt="下载二维码"></div>
    <div class="dl-text">
      <div class="dl-title">📲 扫码下载</div>
      <div class="dl-sub">手机微信/浏览器扫描左侧二维码<br>即可下载安装错题猎手安卓版</div>
      <div class="dl-url">__DOWNLOAD_URL__/</div>
      <div class="dl-meta">
        <span class="dl-tag">🤖 Android APK</span>
        <span class="dl-tag">🏷 v__VERSION__</span>
        <span class="dl-tag">📦 __SIZE_MB__ MB</span>
      </div>
    </div>
  </div>

  <div class="footer">
    <div class="footer-copy">错题猎手 ErrorHunter © 2026 · 采集 → 归因 → 复习 → 消灭</div>
  </div>
</div>
</body>
</html>
"""

HTML = HTML.replace("__QR_DATA__", QR_URI).replace("__ICON_DATA__", ICON_URI)
HTML = HTML.replace("__DOWNLOAD_URL__", DOWNLOAD_URL)
HTML = HTML.replace("__VERSION__", VERSION).replace("__SIZE_MB__", SIZE_MB)
HTML = HTML.replace("/* __FONT_FACE__ */", build_font_face(HTML))
out = Path(__file__).resolve().parent / "poster-介绍海报.html"
out.write_text(HTML, encoding="utf-8")
print(f"WRITTEN: {out}  ({len(HTML)} bytes)")
