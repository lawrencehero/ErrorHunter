/// 错题猎手 - 统计卡片组件 V2.0
/// 超大数字 (32px/800) + elevation-2 + 左侧彩色竖线
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 趋势方向
enum EHTrendDirection { up, down, neutral }

/// 统计卡片 V2.0
class EHStatCard extends StatelessWidget {
  const EHStatCard({
    super.key,
    required this.value,
    required this.label,
    this.trend,
    this.trendValue,
    this.valueColor,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  /// 统计数值（如 "128"、"95%"）
  final String value;

  /// 标签文字（如 "累计错题"、"消灭率"）
  final String label;

  /// 趋势方向
  final EHTrendDirection? trend;

  /// 趋势数值（如 "+12"、"-3%"）
  final String? trendValue;

  /// 数值颜色
  final Color? valueColor;

  /// 可选图标
  final IconData? icon;

  /// 左侧竖线颜色（默认 brandPrimary）
  final Color? accentColor;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          boxShadow: AppShadows.elevation2,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左侧彩色竖线
              if (accentColor != null)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              // 内容区
              Expanded(
                child: Padding(
                  padding: AppSpacing.cardInnerPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 顶部：图标 + 标签
                      Row(
                        children: [
                          if (icon != null) ...[
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: (accentColor ?? AppColors.brandPrimary)
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: 14,
                                color: accentColor ?? AppColors.brandPrimary,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                          ],
                          Expanded(
                            child: Text(
                              label,
                              style: AppTypography.primary.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // 中间：超大数值
                      Text(
                        value,
                        style: AppTypography.primary.number.copyWith(
                          color: valueColor ?? AppColors.textPrimary,
                        ),
                      ),
                      // 底部：趋势
                      if (trend != null && trendValue != null) ...[
                        SizedBox(height: AppSpacing.xs),
                        _buildTrend(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrend() {
    Color trendColor;
    IconData trendIcon;

    switch (trend!) {
      case EHTrendDirection.up:
        trendColor = AppColors.success;
        trendIcon = Icons.trending_up_rounded;
      case EHTrendDirection.down:
        trendColor = AppColors.danger;
        trendIcon = Icons.trending_down_rounded;
      case EHTrendDirection.neutral:
        trendColor = AppColors.textTertiary;
        trendIcon = Icons.trending_flat_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: AppRadius.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 12, color: trendColor),
          SizedBox(width: 2),
          Text(
            trendValue!,
            style: AppTypography.primary.caption.copyWith(
              color: trendColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
