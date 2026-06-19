/// 错题猎手 - 存储进度条组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 存储进度条
class StorageProgressBar extends StatelessWidget {
  const StorageProgressBar({
    super.key,
    required this.usedBytes,
    required this.totalBytes,
  });

  final int usedBytes;
  final int totalBytes;

  double get _percentage =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get _isWarning => _percentage >= 0.9;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部文字
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已用 ${_formatBytes(usedBytes)} / ${_formatBytes(totalBytes)}',
              style: AppTypography.primary.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(_percentage * 100).toStringAsFixed(1)}%',
              style: AppTypography.primary.h3.copyWith(
                color: _isWarning ? AppColors.danger : AppColors.brandPrimary,
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
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isWarning ? AppColors.danger : AppColors.brandPrimary,
            ),
          ),
        ),
        // 警告提示
        if (_isWarning) ...[
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.danger),
              SizedBox(width: AppSpacing.xs),
              Text(
                '存储空间即将用完，建议清理图片缓存',
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.danger,
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
