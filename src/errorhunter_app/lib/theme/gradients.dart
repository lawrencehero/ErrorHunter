/// 错题猎手 - 渐变系统
/// 来源：DESIGN.md V2.0 §2.3
library;

import 'package:flutter/material.dart';
import 'colors.dart';

/// Design Token: 渐变定义
class AppGradients {
  AppGradients._();

  // ─── Brand Gradients ──────────────────────────────────────

  /// 品牌蓝渐变 (135°) - 主按钮、顶栏、CTA
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.brandPrimary, Color(0xFF7B93FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 温暖橙渐变 (135°) - 打卡条、成就卡片
  static const LinearGradient warm = LinearGradient(
    colors: [AppColors.brandSecondary, Color(0xFFFFB07A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 消灭绿渐变 (135°) - 消灭动画、进度条
  static const LinearGradient success = LinearGradient(
    colors: [AppColors.success, Color(0xFF66D97A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 日落渐变 (135°) - 复习倒计时、紧急提醒
  static const LinearGradient sunset = LinearGradient(
    colors: [AppColors.brandSecondary, Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 英雄渐变 (135°) - 个人中心顶栏、周报头部
  static const LinearGradient hero = LinearGradient(
    colors: [AppColors.brandPrimary, Color(0xFF6C5CE7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 卡片微渐变 (180°) - 卡片底色
  static const LinearGradient card = LinearGradient(
    colors: [AppColors.surface, AppColors.background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Status Gradients ─────────────────────────────────────

  /// 根据状态获取渐变
  static LinearGradient statusGradient(String status) {
    switch (status) {
      case 'NOT_STARTED':
        return LinearGradient(
          colors: [AppColors.danger, const Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'REVIEWING':
        return LinearGradient(
          colors: [AppColors.warning, const Color(0xFFFFCC80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'MASTERED':
        return success;
      case 'PERMANENTLY_MASTERED':
        return LinearGradient(
          colors: [AppColors.permanentMaster, const Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return card;
    }
  }

  // ─── Chunky Bottom Shadow Colors ──────────────────────────

  /// 品牌蓝底影色
  static const Color primaryDark = Color(0xFF3A56D4);

  /// 温暖橙底影色
  static const Color secondaryDark = Color(0xFFE6732E);

  /// 消灭绿底影色
  static const Color successDark = Color(0xFF28A745);

  /// 未掌握红底影色
  static const Color dangerDark = Color(0xFFB71C1C);

  /// 复习黄底影色
  static const Color warningDark = Color(0xFFE5A32B);
}
