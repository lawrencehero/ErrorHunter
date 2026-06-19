/// 错题猎手 - 圆角系统
/// 来源：界面与交互设计文档 V1.0 §1.3.4
/// 圆角整体偏大（12-16px），营造亲和、安全的视觉感受
library;

import 'package:flutter/material.dart';

/// Design Token: 圆角常量
class AppRadius {
  AppRadius._();

  /// 8px — 标签、小 Chip
  static const double sm = 8.0;

  /// 12px — 输入框、下拉菜单
  static const double md = 12.0;

  /// 16px — 卡片、面板
  static const double lg = 16.0;

  /// 20px — 大卡片、弹窗、底部 Sheet
  static const double xl = 20.0;

  /// 999px - 圆形按钮、头像、进度条
  static const double full = 999.0;

  // ─── Pre-built BorderRadius ──────────────────────────────

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusFull =
      BorderRadius.all(Radius.circular(full));
}
