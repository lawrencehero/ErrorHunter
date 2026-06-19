/// 错题猎手 - 复活检测卡片变体组件
/// 在卡片背面顶部显示复活检测提示
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 复活检测卡片标签
class ReviveCheckCard extends StatelessWidget {
  const ReviveCheckCard({
    super.key,
    required this.daysSinceMastered,
  });

  final int daysSinceMastered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📖', style: TextStyle(fontSize: 16)),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // 文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '复习巩固',
                  style: AppTypography.primary.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '消灭已 $daysSinceMastered 天，确认还记得吗？',
                  style: AppTypography.primary.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
