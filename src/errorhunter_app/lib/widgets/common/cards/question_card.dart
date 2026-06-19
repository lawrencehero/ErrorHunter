/// 错题猎手 - 错题卡片组件 V2.0
/// 左侧状态色条 + elevation-1 + chunky 交互反馈
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/theme_manager.dart';
import '../chips/error_category_chip.dart';
import '../chips/status_chip.dart';

/// 错题卡片数据模型
class EHQuestionCardData {
  const EHQuestionCardData({
    required this.id,
    required this.subject,
    required this.title,
    this.thumbnailUrl,
    required this.errorCategory,
    required this.status,
    required this.createdAt,
    this.reviewCount = 0,
  });

  final String id;
  final String subject;
  final String title;
  final String? thumbnailUrl;
  final String errorCategory;
  final String status;
  final DateTime createdAt;
  final int reviewCount;
}

/// 错题卡片 V2.0
class EHQuestionCard extends StatefulWidget {
  const EHQuestionCard({
    super.key,
    required this.data,
    this.onTap,
    this.showThumbnail = true,
  });

  final EHQuestionCardData data;
  final VoidCallback? onTap;
  final bool showThumbnail;

  @override
  State<EHQuestionCard> createState() => _EHQuestionCardState();
}

class _EHQuestionCardState extends State<EHQuestionCard> {
  bool _isPressed = false;

  EHQuestionCardData get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.statusColor(data.status);
    final ext = context.themeExt;
    final tc = context.textColors;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isGlass ? Colors.white.withOpacity(0.12) : AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          boxShadow: isGlass ? null : [
            ...AppShadows.elevation1,
            BoxShadow(
              color: statusColor,
              offset: const Offset(-4, 0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
          border: isGlass
              ? Border.all(color: Colors.white.withOpacity(0.18), width: 1)
              : Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: _isPressed
              ? (Matrix4.identity()..translate(0.0, 2.0))
              : Matrix4.identity(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧缩略图
                    if (widget.showThumbnail) ...[
                      _buildThumbnail(),
                      SizedBox(width: AppSpacing.md),
                    ],
                    // 右侧内容区
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 顶部：学科 + 时间
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimaryPale,
                                  borderRadius: AppRadius.radiusFull,
                                ),
                                child: Text(
                                  data.subject,
                                  style: AppTypography.primary.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                _formatDate(data.createdAt),
                                style: AppTypography.primary.caption.copyWith(
                                  color: tc.tertiary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.xs),
                          // 标题
                          Text(
                            data.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.primary.h3.copyWith(
                              color: tc.primary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          // 底部：错因标签 + 状态标签
                          Row(
                            children: [
                              EHErrorCategoryChip(category: data.errorCategory),
                              SizedBox(width: AppSpacing.sm),
                              EHStatusChip(status: data.status),
                              const Spacer(),
                              if (data.reviewCount > 0)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: AppRadius.radiusFull,
                                  ),
                                  child: Text(
                                    '📖 ${data.reviewCount}次',
                                    style: AppTypography.primary.caption.copyWith(
                                      color: tc.secondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 右侧箭头
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: tc.tertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: data.thumbnailUrl != null
          ? Image.network(
              data.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    final tc = context.textColors;
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 24,
        color: tc.tertiary,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}/${date.day}';
  }
}
