/// 错题猎手 - 年级标签组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import 'error_category_chip.dart';

/// 年级标签
class EHGradeChip extends StatelessWidget {
  const EHGradeChip({
    super.key,
    required this.grade,
    this.size = EHChipSize.md,
    this.active = false,
    this.onTap,
  });

  /// 年级代码：31-34（小学三到六年级）, 71-73（初中一到三年级）
  final String grade;

  /// 标签尺寸
  final EHChipSize size;

  /// 是否选中态
  final bool active;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = _gradeLabel(grade);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.brandPrimary : AppColors.background,
          borderRadius: AppRadius.radiusSm,
          border: Border.all(
            color: active ? AppColors.brandPrimary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: _textStyle.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  double get _horizontalPadding {
    switch (size) {
      case EHChipSize.sm:
        return 6.0;
      case EHChipSize.md:
        return AppSpacing.sm;
      case EHChipSize.lg:
        return AppSpacing.md;
    }
  }

  double get _verticalPadding {
    switch (size) {
      case EHChipSize.sm:
        return 2.0;
      case EHChipSize.md:
        return AppSpacing.xs;
      case EHChipSize.lg:
        return 6.0;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case EHChipSize.sm:
        return AppTypography.primary.caption.copyWith(fontSize: 11);
      case EHChipSize.md:
        return AppTypography.primary.caption;
      case EHChipSize.lg:
        return AppTypography.primary.body;
    }
  }

  String _gradeLabel(String grade) {
    switch (grade) {
      case '31': return '三年级';
      case '32': return '四年级';
      case '33': return '五年级';
      case '34': return '六年级';
      case '71': return '初一';
      case '72': return '初二';
      case '73': return '初三';
      default: return grade;
    }
  }
}
