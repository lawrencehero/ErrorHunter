/// 错题猎手 - 筛选标签组件
/// 支持单选/多选模式
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import 'error_category_chip.dart';

/// 筛选标签
class EHFilterChip extends StatelessWidget {
  const EHFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.size = EHChipSize.md,
    this.icon,
    this.allowUnselect = true,
  });

  /// 标签文字
  final String label;

  /// 是否选中
  final bool selected;

  /// 状态变更回调
  final ValueChanged<bool> onChanged;

  /// 标签尺寸
  final EHChipSize size;

  /// 可选前置图标
  final IconData? icon;

  /// 是否允许取消选中
  final bool allowUnselect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (selected && !allowUnselect) return;
        onChanged(!selected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary.withOpacity(0.1) : Colors.white,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: _iconSize,
                color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: _textStyle.copyWith(
                color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (selected) ...[
              SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.check_rounded,
                size: _iconSize,
                color: AppColors.brandPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  double get _horizontalPadding {
    switch (size) {
      case EHChipSize.sm:
        return AppSpacing.sm;
      case EHChipSize.md:
        return AppSpacing.md;
      case EHChipSize.lg:
        return AppSpacing.base;
    }
  }

  double get _verticalPadding {
    switch (size) {
      case EHChipSize.sm:
        return AppSpacing.xs;
      case EHChipSize.md:
        return AppSpacing.sm;
      case EHChipSize.lg:
        return AppSpacing.md;
    }
  }

  double get _iconSize {
    switch (size) {
      case EHChipSize.sm:
        return 14.0;
      case EHChipSize.md:
        return 16.0;
      case EHChipSize.lg:
        return 18.0;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case EHChipSize.sm:
        return AppTypography.primary.caption.copyWith(fontSize: 12);
      case EHChipSize.md:
        return AppTypography.primary.caption;
      case EHChipSize.lg:
        return AppTypography.primary.body;
    }
  }
}
