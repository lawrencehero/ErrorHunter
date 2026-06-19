/// 错题猎手 - 错因分类标签组件
/// 带颜色圆点的分类标识
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 错因分类标签
class EHErrorCategoryChip extends StatelessWidget {
  const EHErrorCategoryChip({
    super.key,
    required this.category,
    this.showDot = true,
    this.size = EHChipSize.md,
  });

  /// 分类代码：KNOWLEDGE / SKILL / PSYCHOLOGY / HABIT / UNKNOWN
  final String category;

  /// 是否显示颜色圆点
  final bool showDot;

  /// 标签尺寸
  final EHChipSize size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.errorCategoryColor(category);
    final label = _categoryLabel(category);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: _textStyle.copyWith(color: color),
          ),
        ],
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

  double get _dotSize {
    switch (size) {
      case EHChipSize.sm:
        return 6.0;
      case EHChipSize.md:
        return 8.0;
      case EHChipSize.lg:
        return 10.0;
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

  String _categoryLabel(String category) {
    switch (category) {
      case 'KNOWLEDGE':
        return '知识性错误';
      case 'SKILL':
        return '技能性错误';
      case 'PSYCHOLOGY':
        return '心理性错误';
      case 'HABIT':
        return '习惯性错误';
      case 'UNKNOWN':
        return '不确定';
      default:
        return category;
    }
  }
}

/// 标签尺寸枚举
enum EHChipSize { sm, md, lg }
