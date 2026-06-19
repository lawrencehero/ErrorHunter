/// 错题猎手 - 色彩系统
/// 来源：界面与交互设计文档 V1.0 §1.3.1
library;

import 'package:flutter/material.dart';

/// Design Token: 品牌色 & 语义色
class AppColors {
  AppColors._();

  // ─── Brand Colors ────────────────────────────────────────

  /// 活力蓝 - 主要按钮、Tab激活态、链接
  static const Color brandPrimary = Color(0xFF4F6EF7);

  /// 品牌蓝深色 - 按钮底影 (chunky shadow)
  static const Color brandPrimaryDark = Color(0xFF3A56D4);

  /// 品牌蓝浅色 - Hover态、浅填充
  static const Color brandPrimaryLight = Color(0xFF7B93FF);

  /// 品牌蓝极浅 - 选中背景、浅底色
  static const Color brandPrimaryPale = Color(0xFFEEF1FE);

  /// 温暖橙 - 次要强调、打卡天数、里程碑
  static const Color brandSecondary = Color(0xFFFF8C42);

  /// 温暖橙深色 - 橙色按钮底影
  static const Color brandSecondaryDark = Color(0xFFE6732E);

  /// 温暖橙浅色 - 橙色浅填充
  static const Color brandSecondaryLight = Color(0xFFFFB07A);

  // ─── Semantic Colors ─────────────────────────────────────

  /// 消灭绿 - 已消灭状态、正确、完成
  static const Color success = Color(0xFF34C759);

  /// 消灭绿深色 - 绿色按钮底影
  static const Color successDark = Color(0xFF28A745);

  /// 复习黄 - 复习中状态、部分记得
  static const Color warning = Color(0xFFFFB830);

  /// 复习黄深色 - 黄色按钮底影
  static const Color warningDark = Color(0xFFE5A32B);

  /// 未掌握红 - 未掌握状态、完全不会、错误
  static const Color danger = Color(0xFFD32F2F);

  /// 未掌握红深色 - 红色按钮底影
  static const Color dangerDark = Color(0xFFB71C1C);

  /// 永久消灭深绿
  static const Color permanentMaster = Color(0xFF1B8C3A);

  // ─── Error Category Colors ───────────────────────────────

  /// 知识性错误 - 紫
  static const Color errorKnowledge = Color(0xFF6C5CE7);

  /// 技能性错误 - 蓝
  static const Color errorSkill = Color(0xFF0984E3);

  /// 心理性错误 - 珊瑚
  static const Color errorPsychology = Color(0xFFE17055);

  /// 习惯性错误 - 金
  static const Color errorHabit = Color(0xFFFDCB6E);

  /// 不确定 - 灰（仅小学生）
  static const Color errorUnknown = Color(0xFFB2BEC3);

  // ─── Neutral Colors ──────────────────────────────────────

  /// 标题、正文
  static const Color textPrimary = Color(0xFF1A1A2E);

  /// 辅助说明、时间戳
  static const Color textSecondary = Color(0xFF6B7280);

  /// 占位符、禁用态
  static const Color textTertiary = Color(0xFF9CA3AF);

  /// 分割线、卡片边框
  static const Color border = Color(0xFFE5E7EB);

  /// 页面底色（微冷灰白，护眼）
  static const Color background = Color(0xFFF8F9FC);

  /// 卡片表面
  static const Color surface = Color(0xFFFFFFFF);

  /// 弹窗遮罩
  static const Color overlay = Color(0x80000000);

  // ─── Question Status Color Mapping ───────────────────────

  /// 根据错题状态获取对应颜色
  static Color statusColor(String status) {
    switch (status) {
      case 'NOT_STARTED':
        return danger;
      case 'REVIEWING':
        return warning;
      case 'MASTERED':
        return success;
      case 'PERMANENTLY_MASTERED':
        return permanentMaster;
      default:
        return textTertiary;
    }
  }

  /// 根据错因分类获取对应颜色
  static Color errorCategoryColor(String category) {
    switch (category) {
      case 'KNOWLEDGE':
        return errorKnowledge;
      case 'SKILL':
        return errorSkill;
      case 'PSYCHOLOGY':
        return errorPsychology;
      case 'HABIT':
        return errorHabit;
      case 'UNKNOWN':
        return errorUnknown;
      default:
        return textTertiary;
    }
  }
}
