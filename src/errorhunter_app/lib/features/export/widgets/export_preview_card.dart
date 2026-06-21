/// 错题猎手 - PDF导出预览卡片
/// 展示单道错题的缩略信息，用于PDF导出预览
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/chips/error_category_chip.dart';

/// 导出预览卡片
class ExportPreviewCard extends StatelessWidget {
  const ExportPreviewCard({
    super.key,
    required this.imageUrl,
    required this.errorCategory,
    required this.knowledgePoints,
    this.isOffline = false,
  });

  /// 题目图片URL
  final String imageUrl;

  /// 错因分类代码
  final String errorCategory;

  /// 知识点列表
  final List<String> knowledgePoints;

  /// 是否离线（显示占位图）
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目图片缩略区
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.radiusLg.copyWith(
                bottomLeft: Radius.zero,
                bottomRight: Radius.zero,
              ),
              child: isOffline
                  ? Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            '图片待同步',
                            style: AppTypography.primary.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: AppColors.brandPrimary,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
            ),
          ),
          // 底部标签区
          Padding(
            padding: AppSpacing.cardInnerPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EHErrorCategoryChip(
                  category: errorCategory,
                  size: EHChipSize.sm,
                ),
                if (knowledgePoints.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: knowledgePoints.take(3).map((kp) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withOpacity(0.08),
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          kp,
                          style: AppTypography.primary.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
