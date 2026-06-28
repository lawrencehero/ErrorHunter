/// 错题猎手 - 主题选择器
/// 允许用户在游戏化和玻璃拟态之间切换主题
library;

import 'package:flutter/material.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 主题选择器页面
class ThemeSelectorPage extends StatelessWidget {
  const ThemeSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final currentMode = ThemeManager.instance.currentMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '选择主题',
          style: AppTypography.primary.h3.copyWith(
            color: tc.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              '选择你喜欢的界面风格',
              style: AppTypography.primary.h3.copyWith(
                color: tc.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '随时可以在个人中心切换',
              style: AppTypography.primary.caption.copyWith(
                color: tc.secondary,
              ),
            ),
            const SizedBox(height: 24),
            ...AppThemeMode.values.map(
                (mode) => _buildThemeCard(context, mode, currentMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, AppThemeMode mode, AppThemeMode current) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final isSelected = mode == current;
    // 玻璃下蓝色 brandPrimary 作选中态/文字对比度不足，改用暖琥珀；
    // 卡片底色不能用白底，改用半透明白 + 边框区分选中态。
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    final cardBg = isGlass
        ? (isSelected ? Colors.white.withOpacity(0.20) : Colors.white.withOpacity(0.12))
        : (isSelected ? AppColors.brandPrimaryPale : Colors.white);
    final cardBorder = isSelected
        ? accent
        : (isGlass ? Colors.white.withOpacity(0.25) : AppColors.border);
    final unselectedRing = isGlass ? Colors.white.withOpacity(0.4) : AppColors.border;

    return GestureDetector(
      onTap: () {
        ThemeManager.instance.setMode(mode);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isGlass
              ? null
              : [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.brandPrimary.withOpacity(0.15)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 主题图标
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: mode.previewColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(mode.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                // 主题信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              mode.displayName,
                              style: AppTypography.primary.h3.copyWith(
                                color: tc.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('当前',
                                style: TextStyle(color: isGlass ? Colors.black87 : Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mode.description,
                        style: AppTypography.primary.caption.copyWith(
                          color: tc.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 选中指示器
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accent : unselectedRing,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 14, color: isGlass ? Colors.black87 : Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 预览色条
            Row(
              children: mode.previewColors.map((color) {
                return Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
