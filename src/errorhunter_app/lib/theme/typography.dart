/// 错题猎手 - 字体系统
/// 来源：界面与交互设计文档 V1.0 §1.3.2
library;

import 'package:flutter/material.dart';

/// Design Token: 字体规范
/// MVP阶段使用统一字体栈，通过 [AppTypography.forGrade] 按年级区分字号
class AppTypography {
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle button;
  final TextStyle number;

  const AppTypography._({
    required this.h1,
    required this.h2,
    required this.h3,
    required this.body,
    required this.caption,
    required this.button,
    required this.number,
  });

  /// 小学生模式（grade 31-34）：大字号、高可读性
  static const AppTypography primary = AppTypography._(
    h1: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.3,
    ),
    h2: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    h3: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    body: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    caption: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    button: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: 0.3,
    ),
    number: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      height: 1.1,
    ),
  );

  /// 初中生模式（grade 71-73）：标准字号、信息密度更高
  static const AppTypography secondary = AppTypography._(
    h1: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.3,
    ),
    h2: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    h3: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    body: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    caption: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    button: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: 0.3,
    ),
    number: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.1,
    ),
  );

  /// 根据年级返回对应字体配置
  /// grade: 31-34 = 小学, 71-73 = 初中
  static AppTypography forGrade(String grade) {
    final code = int.tryParse(grade) ?? 31;
    return code >= 71 ? secondary : primary;
  }

  /// 应用颜色到所有文本样式
  AppTypography applyColor(Color color) {
    return AppTypography._(
      h1: h1.copyWith(color: color),
      h2: h2.copyWith(color: color),
      h3: h3.copyWith(color: color),
      body: body.copyWith(color: color),
      caption: caption.copyWith(color: color),
      button: button.copyWith(color: color),
      number: number.copyWith(color: color),
    );
  }

  /// 转换为 Flutter TextTheme
  TextTheme toTextTheme() {
    return TextTheme(
      displayLarge: h1,
      displayMedium: h2,
      displaySmall: h3,
      bodyLarge: body,
      bodyMedium: caption,
      labelLarge: button,
      headlineLarge: number,
    );
  }
}
