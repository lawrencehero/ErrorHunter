/// 错题猎手 - 骨架屏卡片
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import 'skeleton_box.dart';
import 'shimmer_effect.dart';

/// 骨架屏卡片
class EHSkeletonCard extends StatelessWidget {
  const EHSkeletonCard({
    super.key,
    this.useShimmer = true,
  });

  final bool useShimmer;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 缩略图占位
          EHSkeletonBox(
            width: 64,
            height: 64,
            borderRadius: AppRadius.radiusMd,
            useShimmer: false,
          ),
          SizedBox(width: AppSpacing.sm),
          // 文本行占位
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EHSkeletonBox(width: 80, height: 12, useShimmer: false),
                SizedBox(height: AppSpacing.sm),
                const EHSkeletonBox(width: double.infinity, height: 16, useShimmer: false),
                SizedBox(height: AppSpacing.xs),
                EHSkeletonBox(width: 200, height: 16, useShimmer: false),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    EHSkeletonBox(width: 70, height: 22, useShimmer: false),
                    SizedBox(width: AppSpacing.sm),
                    EHSkeletonBox(width: 50, height: 22, useShimmer: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (useShimmer) {
      card = EHShimmerEffect(child: card);
    }

    return card;
  }
}
