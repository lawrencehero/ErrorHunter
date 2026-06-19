/// 错题猎手 - App Theme 配置 V3.0
/// 支持多主题切换（游戏化 + 玻璃拟态）
library;

import 'package:flutter/material.dart';
import 'colors.dart';
import 'gradients.dart';
import 'shadows.dart';
import 'typography.dart';
import 'spacing.dart';
import 'radius.dart';
import 'app_theme_mode.dart';

/// 全局主题配置
class AppTheme {
  AppTheme._();

  /// 默认使用小学生模式（游戏化主题）
  static ThemeData get light => _buildTheme(AppTypography.primary);

  /// 初中生模式
  static ThemeData get lightSecondary => _buildTheme(AppTypography.secondary);

  /// 根据年级获取对应主题
  static ThemeData forGrade(String grade) {
    final typo = AppTypography.forGrade(grade);
    return _buildTheme(typo);
  }

  static ThemeData _buildTheme(AppTypography typo) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.light,
      primary: AppColors.brandPrimary,
      secondary: AppColors.brandSecondary,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      extensions: [AppThemeExtension.gamified],
      textTheme: typo.toTextTheme().apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),

      // Elevated Button — 渐变背景 + chunky 底影
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          textStyle: typo.button,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: AppShadows.chunkyPrimary,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      // Outlined Button — 白底 + 品牌色边框 + chunky 底影
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandPrimary,
          backgroundColor: AppColors.surface,
          textStyle: typo.button,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 14,
          ),
          side: const BorderSide(
            color: AppColors.brandPrimary,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandPrimary,
          textStyle: typo.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      // Input Decoration — 更粗的边框和焦点环
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.brandPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle: typo.body.copyWith(color: AppColors.textTertiary),
        labelStyle: typo.caption.copyWith(color: AppColors.textSecondary),
      ),

      // Card — elevation-1 默认 + 更圆润
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        shadowColor: Colors.black26,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
      ),

      // Bottom Navigation Bar — elevation-3 阴影
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandPrimaryPale,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return typo.caption.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w600,
            );
          }
          return typo.caption.copyWith(color: AppColors.textTertiary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.brandPrimary,
              size: 24,
            );
          }
          return const IconThemeData(
            color: AppColors.textTertiary,
            size: 24,
          );
        }),
        height: 64,
        elevation: 8,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1.5,
        space: 1,
      ),

      // Chip — 更圆润 + 状态色浅底
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.brandPrimaryPale,
        selectedColor: AppColors.brandPrimaryPale,
        labelStyle: typo.caption.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusFull,
        ),
        side: BorderSide(
          color: AppColors.brandPrimary.withOpacity(0.3),
          width: 1.5,
        ),
      ),

      // Dialog — 更大圆角
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusXl,
        ),
        titleTextStyle: typo.h2.copyWith(color: AppColors.textPrimary),
        contentTextStyle: typo.body.copyWith(color: AppColors.textSecondary),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: typo.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusMd,
        ),
      ),
    );
  }
}
