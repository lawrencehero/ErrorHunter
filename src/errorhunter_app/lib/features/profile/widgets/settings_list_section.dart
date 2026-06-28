/// 错题猎手 - 设置项分组列表组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/divider.dart';

/// 设置项数据
class SettingItem {
  const SettingItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showDivider;
}

/// 设置项分组列表
class SettingsListSection extends StatelessWidget {
  const SettingsListSection({
    super.key,
    required this.items,
    this.title,
  });

  final List<SettingItem> items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    // 玻璃拟态：白色 surface 底在深色渐变上突兀且发亮，改半透明白；
    // danger 深红对比度不足，提亮为浅红。
    final dangerColor =
        isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    final dividerColor = isGlass
        ? Colors.white.withOpacity(0.15)
        : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.sm,
              AppSpacing.base,
              AppSpacing.xs,
            ),
            child: Text(
              title!,
              style: AppTypography.primary.caption.copyWith(
                color: tc.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: isGlass ? Colors.white.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: isGlass
                ? Border.all(color: Colors.white.withOpacity(0.25), width: 1)
                : null,
          ),
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.base),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      item.icon,
                      size: 22,
                      color: item.isDestructive
                          ? dangerColor
                          : tc.secondary,
                    ),
                    title: Text(
                      item.label,
                      style: AppTypography.primary.body.copyWith(
                        color: item.isDestructive
                            ? dangerColor
                            : tc.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: item.onTap != null
                        ? Icon(Icons.chevron_right_rounded,
                            size: 20, color: tc.tertiary)
                        : null,
                    onTap: item.onTap,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: AppSpacing.xs,
                    ),
                    minLeadingWidth: 32,
                  ),
                  if (!isLast && item.showDivider)
                    EHDivider(indent: 56, color: dividerColor),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
