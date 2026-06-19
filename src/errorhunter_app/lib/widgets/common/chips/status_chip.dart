/// 错题猎手 - 状态标签组件 V2.0
/// 圆润胶囊形 + 状态色浅底 + 更粗字重
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import 'error_category_chip.dart';

/// 状态标签 V2.0
class EHStatusChip extends StatelessWidget {
  const EHStatusChip({
    super.key,
    required this.status,
    this.size = EHChipSize.md,
    this.filled = false,
  });

  /// 状态代码：NOT_STARTED / REVIEWING / MASTERED / PERMANENTLY_MASTERED
  final String status;

  /// 标签尺寸
  final EHChipSize size;

  /// 是否使用填充样式
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final label = _statusLabel(status);
    final icon = _statusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.1),
        borderRadius: AppRadius.radiusFull,
        border: filled
            ? null
            : Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: filled ? Colors.white : color),
            SizedBox(width: 3),
          ],
          Text(
            label,
            style: _textStyle.copyWith(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double get _horizontalPadding {
    switch (size) {
      case EHChipSize.sm:
        return 8.0;
      case EHChipSize.md:
        return AppSpacing.md;
      case EHChipSize.lg:
        return AppSpacing.base;
    }
  }

  double get _verticalPadding {
    switch (size) {
      case EHChipSize.sm:
        return 3.0;
      case EHChipSize.md:
        return 5.0;
      case EHChipSize.lg:
        return 8.0;
    }
  }

  double get _iconSize {
    switch (size) {
      case EHChipSize.sm:
        return 12.0;
      case EHChipSize.md:
        return 14.0;
      case EHChipSize.lg:
        return 16.0;
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

  String _statusLabel(String status) {
    switch (status) {
      case 'NOT_STARTED':
        return '未掌握';
      case 'REVIEWING':
        return '复习中';
      case 'MASTERED':
        return '已消灭';
      case 'PERMANENTLY_MASTERED':
        return '永久消灭';
      default:
        return status;
    }
  }

  IconData? _statusIcon(String status) {
    switch (status) {
      case 'NOT_STARTED':
        return Icons.close_rounded;
      case 'REVIEWING':
        return Icons.refresh_rounded;
      case 'MASTERED':
        return Icons.check_rounded;
      case 'PERMANENTLY_MASTERED':
        return Icons.verified_rounded;
      default:
        return null;
    }
  }
}
