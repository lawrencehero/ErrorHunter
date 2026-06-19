/// 错题猎手 - 阴影系统
/// 来源：DESIGN.md V2.0 §4
/// 3 级阴影层级 + Duolingo chunky bottom shadow
library;

import 'package:flutter/material.dart';
import 'colors.dart';

/// Design Token: 阴影定义
class AppShadows {
  AppShadows._();

  // ─── 3-Level Elevation System ─────────────────────────────

  /// Elevation 1: 静态卡片、列表项 — 轻微浮起
  static const List<BoxShadow> elevation1 = [
    BoxShadow(
      color: Color(0x0F000000), // opacity ~0.06
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevation 2: 交互卡片、统计卡 — 明显浮起
  static const List<BoxShadow> elevation2 = [
    BoxShadow(
      color: Color(0x1A000000), // opacity ~0.10
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Elevation 3: 弹窗、浮动按钮、底部导航 — 高层级
  static const List<BoxShadow> elevation3 = [
    BoxShadow(
      color: Color(0x26000000), // opacity ~0.15
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // ─── Chunky Bottom Shadow (Duolingo Style) ────────────────

  /// 品牌蓝按钮底影
  static const BorderSide chunkyPrimary = BorderSide(
    color: Color(0xFF3A56D4),
    width: 3,
  );

  /// 橙色按钮底影
  static const BorderSide chunkySecondary = BorderSide(
    color: Color(0xFFE6732E),
    width: 3,
  );

  /// 成功按钮底影
  static const BorderSide chunkySuccess = BorderSide(
    color: Color(0xFF28A745),
    width: 3,
  );

  /// 危险按钮底影
  static const BorderSide chunkyDanger = BorderSide(
    color: Color(0xFFB71C1C),
    width: 3,
  );

  /// 通用卡片底影
  static const BorderSide chunkyCard = BorderSide(
    color: AppColors.border,
    width: 3,
  );

  // ─── Colored Shadows (品牌色光晕) ─────────────────────────

  /// 品牌蓝光晕 — 用于浮动按钮、CTA
  static const List<BoxShadow> brandGlow = [
    BoxShadow(
      color: Color(0x4D4F6EF7), // brandPrimary opacity ~0.3
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// 成功绿光晕 — 消灭按钮
  static const List<BoxShadow> successGlow = [
    BoxShadow(
      color: Color(0x4D34C759), // success opacity ~0.3
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// 温暖橙光晕 — 打卡按钮
  static const List<BoxShadow> warmGlow = [
    BoxShadow(
      color: Color(0x4DFF8C42), // brandSecondary opacity ~0.3
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // ─── Helpers ──────────────────────────────────────────────

  /// 根据 elevation 级别获取阴影
  static List<BoxShadow> forElevation(int level) {
    switch (level) {
      case 1:
        return elevation1;
      case 2:
        return elevation2;
      case 3:
        return elevation3;
      default:
        return elevation1;
    }
  }

  /// 获取交互卡片的 chunky bottom border (3px)
  static Border chunkyBorder({
    Color color = const Color(0xFFE5E7EB),
    double width = 3,
    BorderRadius? radius,
  }) {
    return Border(
      bottom: BorderSide(color: color, width: width),
    );
  }
}
