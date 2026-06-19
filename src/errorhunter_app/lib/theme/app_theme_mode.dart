/// 错题猎手 - 主题模式定义
/// 支持游戏化(Gamified) 和 玻璃拟态(Glassmorphism) 两套主题
library;

import 'package:flutter/material.dart';

/// 主题模式枚举
enum AppThemeMode {
  /// 方案C - 游戏化 Gamified (Duolingo风格)
  gamified,

  /// 方案A - 玻璃拟态 Glassmorphism
  glassmorphism;

  /// 显示名称
  String get displayName {
    switch (this) {
      case AppThemeMode.gamified:
        return '游戏化';
      case AppThemeMode.glassmorphism:
        return '玻璃拟态';
    }
  }

  /// 主题描述
  String get description {
    switch (this) {
      case AppThemeMode.gamified:
        return 'Duolingo风格 · 3D按钮 · 大字号数据 · 鲜艳配色';
      case AppThemeMode.glassmorphism:
        return '毛玻璃卡片 · 渐变背景 · 通透轻盈 · 现代感';
    }
  }

  /// 主题图标
  IconData get icon {
    switch (this) {
      case AppThemeMode.gamified:
        return Icons.games_outlined;
      case AppThemeMode.glassmorphism:
        return Icons.blur_on_outlined;
    }
  }

  /// 主题预览色（用于选择器展示）
  List<Color> get previewColors {
    switch (this) {
      case AppThemeMode.gamified:
        return [
          const Color(0xFF4F6EF7),
          const Color(0xFFFF8C42),
          const Color(0xFF34C759),
        ];
      case AppThemeMode.glassmorphism:
        return [
          const Color(0xFF667EEA),
          const Color(0xFF764BA2),
          const Color(0xFFF093FB),
        ];
    }
  }
}

/// 主题扩展数据 — 每个主题独有的视觉参数
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.isDarkBackground,
    required this.backgroundGradient,
    required this.cardOpacity,
    required this.cardBlur,
    required this.cardBorder,
    required this.showChunkyShadow,
    required this.chunkyShadowOffset,
    required this.headerStyle,
    required this.onSurfaceText,
    required this.onSurfaceSubtext,
    required this.showDotPattern,
  });

  /// 背景是否为深色/渐变 (影响文字颜色)
  final bool isDarkBackground;

  /// 背景渐变 (仅 glassmorphism 使用)
  final LinearGradient? backgroundGradient;

  /// 卡片透明度 (1.0 = 不透明, <1.0 = 半透明)
  final double cardOpacity;

  /// 卡片模糊度 (0 = 无模糊)
  final double cardBlur;

  /// 卡片边框
  final Border? cardBorder;

  /// 是否显示 chunky 底影
  final bool showChunkyShadow;

  /// chunky 底影偏移
  final Offset chunkyShadowOffset;

  /// 顶栏样式
  final HeaderStyle headerStyle;

  /// 卡片表面上的文字颜色
  final Color onSurfaceText;

  /// 卡片表面上的次要文字颜色
  final Color onSurfaceSubtext;

  /// 是否显示波点图案
  final bool showDotPattern;

  /// ─── 游戏化主题扩展 ─────────────────────────────────────

  static const gamified = AppThemeExtension(
    isDarkBackground: false,
    backgroundGradient: null,
    cardOpacity: 1.0,
    cardBlur: 0,
    cardBorder: null,
    showChunkyShadow: true,
    chunkyShadowOffset: Offset(0, 4),
    headerStyle: HeaderStyle.solidBlue,
    onSurfaceText: Color(0xFF1A1A2E),
    onSurfaceSubtext: Color(0xFF6B7280),
    showDotPattern: true,
  );

  /// ─── 玻璃拟态主题扩展 ───────────────────────────────────

  static const glassmorphism = AppThemeExtension(
    isDarkBackground: true,
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardOpacity: 0.12,
    cardBlur: 20,
    cardBorder: null,
    showChunkyShadow: false,
    chunkyShadowOffset: Offset.zero,
    headerStyle: HeaderStyle.transparent,
    onSurfaceText: Colors.white,
    onSurfaceSubtext: Color(0xB3FFFFFF), // white 70%
    showDotPattern: false,
  );

  @override
  AppThemeExtension copyWith({
    bool? isDarkBackground,
    LinearGradient? backgroundGradient,
    double? cardOpacity,
    double? cardBlur,
    Border? cardBorder,
    bool? showChunkyShadow,
    Offset? chunkyShadowOffset,
    HeaderStyle? headerStyle,
    Color? onSurfaceText,
    Color? onSurfaceSubtext,
    bool? showDotPattern,
  }) {
    return AppThemeExtension(
      isDarkBackground: isDarkBackground ?? this.isDarkBackground,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      cardBlur: cardBlur ?? this.cardBlur,
      cardBorder: cardBorder ?? this.cardBorder,
      showChunkyShadow: showChunkyShadow ?? this.showChunkyShadow,
      chunkyShadowOffset: chunkyShadowOffset ?? this.chunkyShadowOffset,
      headerStyle: headerStyle ?? this.headerStyle,
      onSurfaceText: onSurfaceText ?? this.onSurfaceText,
      onSurfaceSubtext: onSurfaceSubtext ?? this.onSurfaceSubtext,
      showDotPattern: showDotPattern ?? this.showDotPattern,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      isDarkBackground: t < 0.5 ? isDarkBackground : other.isDarkBackground,
      backgroundGradient: LinearGradient.lerp(backgroundGradient, other.backgroundGradient, t),
      cardOpacity: cardOpacity + (other.cardOpacity - cardOpacity) * t,
      cardBlur: cardBlur + (other.cardBlur - cardBlur) * t,
      cardBorder: t < 0.5 ? cardBorder : other.cardBorder,
      showChunkyShadow: t < 0.5 ? showChunkyShadow : other.showChunkyShadow,
      chunkyShadowOffset: Offset.lerp(chunkyShadowOffset, other.chunkyShadowOffset, t)!,
      headerStyle: t < 0.5 ? headerStyle : other.headerStyle,
      onSurfaceText: Color.lerp(onSurfaceText, other.onSurfaceText, t)!,
      onSurfaceSubtext: Color.lerp(onSurfaceSubtext, other.onSurfaceSubtext, t)!,
      showDotPattern: t < 0.5 ? showDotPattern : other.showDotPattern,
    );
  }
}

/// 顶栏样式
enum HeaderStyle {
  /// 实心蓝色 (游戏化)
  solidBlue,

  /// 透明 (玻璃拟态，融入背景渐变)
  transparent,
}
