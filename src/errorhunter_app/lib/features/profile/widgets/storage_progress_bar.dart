/// 错题猎手 - 存储进度条组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

/// 存储进度条
class StorageProgressBar extends StatelessWidget {
  const StorageProgressBar({
    super.key,
    required this.usedBytes,
    required this.totalBytes,
    this.label = '已用',
    this.warningHint = '存储空间即将用完，建议清理图片缓存',
  });

  final int usedBytes;
  final int totalBytes;

  /// 用量文案前缀，如"已用"或"云端用量"
  final String label;

  /// 达到 90% 时的警告提示文案
  final String warningHint;

  double get _percentage =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get _isWarning => _percentage >= 0.9;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    // 玻璃拟态：深色渐变背景上 brandPrimary 蓝 / danger 深红对比度不足，
    // 改用暖琥珀强调色 + 语义色提亮（与 storage_management_page.dart 一致）。
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // danger 玻璃下提亮为浅红保证可读性。
    final dangerColor =
        isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    final trackColor = _isWarning ? dangerColor : accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部文字
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label ${_formatBytes(usedBytes)} / ${_formatBytes(totalBytes)}',
              style: AppTypography.primary.body.copyWith(
                color: tc.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(_percentage * 100).toStringAsFixed(1)}%',
              style: AppTypography.primary.h3.copyWith(
                color: trackColor,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        // 进度条
        ClipRRect(
          borderRadius: AppRadius.radiusFull,
          child: LinearProgressIndicator(
            value: _percentage,
            minHeight: 12,
            backgroundColor: isGlass
                ? Colors.white.withOpacity(0.12)
                : AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(trackColor),
          ),
        ),
        // 警告提示
        if (_isWarning) ...[
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: dangerColor),
              SizedBox(width: AppSpacing.xs),
              Text(
                warningHint,
                style: AppTypography.primary.caption.copyWith(
                  color: dangerColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
