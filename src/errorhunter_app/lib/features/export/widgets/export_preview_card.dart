/// 错题猎手 - PDF导出预览卡片
/// 展示单道错题的缩略信息，用于PDF导出预览
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
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
    final tc = context.textColors;
    // 玻璃拟态：卡片不能用白底 AppColors.surface，改用半透明白 + 边框；
    // 知识点标签蓝色 brandPrimary 在深色渐变上对比度不足，改用暖琥珀。
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    final cardBg = isGlass ? Colors.white.withOpacity(0.12) : AppColors.surface;
    final cardBorder = isGlass
        ? Colors.white.withOpacity(0.25)
        : AppColors.border.withOpacity(0.5);
    // 图片区底色玻璃下用半透明黑（让图片更突出），游戏化保持近白。
    final imageAreaBg = isGlass ? Colors.black.withOpacity(0.2) : AppColors.background;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: cardBorder, width: 0.5),
        boxShadow: isGlass
            ? null
            : [
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
              child: _buildImageArea(tc, isGlass, accent, imageAreaBg),
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
                          color: accent.withOpacity(isGlass ? 0.2 : 0.08),
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          kp,
                          style: AppTypography.primary.caption.copyWith(
                            fontSize: 11,
                            color: accent,
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

  /// 构建图片显示区。
  ///
  /// 三种状态：
  /// 1. isOffline（本地文件路径，未上传）→ cloud_off 占位图；
  /// 2. imageUrl 为空（错题无图片）→ 中性「无图片」占位图，不计入待同步；
  /// 3. 网络 URL → 用 BoxFit.contain 完整显示，不拉伸/不裁剪。
  Widget _buildImageArea(
    AppTextThemeColors tc,
    bool isGlass,
    Color accent,
    Color imageAreaBg,
  ) {
    // 1. 待同步：图片仅在本地，未上传到对象存储
    if (isOffline) {
      return Container(
        color: imageAreaBg,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: tc.tertiary,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '图片待同步',
              style: AppTypography.primary.caption.copyWith(
                color: tc.tertiary,
              ),
            ),
          ],
        ),
      );
    }

    // 2. 无图片：错题本身没有图片（不应被误判为待同步）
    if (imageUrl.isEmpty) {
      return Container(
        color: imageAreaBg,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 48,
              color: tc.tertiary,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '暂无图片',
              style: AppTypography.primary.caption.copyWith(
                color: tc.tertiary,
              ),
            ),
          ],
        ),
      );
    }

    // 3. 网络图片：保持原图宽高比完整显示，不拉伸、不裁剪
    return Container(
      color: imageAreaBg,
      alignment: Alignment.center,
      child: Image.network(
        imageUrl,
        // contain：图片完整显示在容器内，保留原始宽高比，避免被拉伸/裁剪
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: accent,
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: imageAreaBg,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 48,
            color: tc.tertiary,
          ),
        ),
      ),
    );
  }
}
