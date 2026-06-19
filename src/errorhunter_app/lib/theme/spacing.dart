/// 错题猎手 - 间距系统
/// 来源：界面与交互设计文档 V1.0 §1.3.3
/// 采用 4px 基准网格，所有间距为4的倍数
library;

import 'package:flutter/material.dart';

/// Design Token: 间距常量
class AppSpacing {
  AppSpacing._();

  /// 4px - 图标与文字间距、紧凑元素间
  static const double xs = 4.0;

  /// 8px - 同组元素间距、标签内边距
  static const double sm = 8.0;

  /// 12px - 卡片内元素间距
  static const double md = 12.0;

  /// 16px - 页面水平安全边距、卡片间距
  static const double base = 16.0;

  /// 20px - 模块间距
  static const double lg = 20.0;

  /// 24px - 区块间距
  static const double xl = 24.0;

  /// 32px - 页面顶部/底部留白
  static const double xxl = 32.0;

  /// 48px - 大区块分隔
  static const double xxxl = 48.0;

  /// 页面水平安全边距（左右各16px，所有屏幕尺寸统一）
  static const double pagePaddingHorizontal = base;

  /// 常用 EdgeInsets
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: base);
  static const EdgeInsets cardPadding = EdgeInsets.all(base);
  static const EdgeInsets cardInnerPadding = EdgeInsets.all(md);

  // ─── Component-specific Gaps ──────────────────────────────

  /// 12px — 按钮组内间距
  static const double buttonGap = 12.0;

  /// 16px — 卡片内区块间距
  static const double cardSectionGap = 16.0;

  /// 8px — 列表项间距
  static const double listItemGap = 8.0;
}
