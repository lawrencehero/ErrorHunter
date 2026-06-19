/// 错题猎手 - 四宫格统计组件
/// 展示周报四项核心指标 + vs上周趋势
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../widgets/common/cards/stat_card.dart';

/// 四宫格统计
class ReportStatGrid extends StatelessWidget {
  const ReportStatGrid({
    super.key,
    required this.newCount,
    required this.newVsLastWeek,
    required this.eliminatedCount,
    required this.eliminatedVsLastWeek,
    required this.reviewCount,
    required this.reviewVsLastWeek,
    required this.accuracyRate,
    required this.accuracyVsLastWeek,
  });

  final int newCount;
  final int newVsLastWeek;
  final int eliminatedCount;
  final int eliminatedVsLastWeek;
  final int reviewCount;
  final int reviewVsLastWeek;
  final double accuracyRate;
  final double accuracyVsLastWeek;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        EHStatCard(
          label: '新增错题',
          value: '$newCount',
          trend: _trend(newVsLastWeek),
          trendValue: _formatTrend(newVsLastWeek),
          valueColor: AppColors.brandPrimary,
          icon: Icons.add_circle_outline_rounded,
        ),
        EHStatCard(
          label: '消灭错题',
          value: '$eliminatedCount',
          trend: _trend(eliminatedVsLastWeek),
          trendValue: _formatTrend(eliminatedVsLastWeek),
          valueColor: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
        ),
        EHStatCard(
          label: '复习次数',
          value: '$reviewCount',
          trend: _trend(reviewVsLastWeek),
          trendValue: _formatTrend(reviewVsLastWeek),
          valueColor: AppColors.brandSecondary,
          icon: Icons.refresh_rounded,
        ),
        EHStatCard(
          label: '正确率',
          value: '${accuracyRate.toStringAsFixed(0)}%',
          trend: _trendDouble(accuracyVsLastWeek),
          trendValue: _formatTrendDouble(accuracyVsLastWeek, isPercent: true),
          valueColor: AppColors.warning,
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }

  EHTrendDirection? _trend(int value) {
    if (value > 0) return EHTrendDirection.up;
    if (value < 0) return EHTrendDirection.down;
    return EHTrendDirection.neutral;
  }

  EHTrendDirection? _trendDouble(double value) {
    if (value > 0) return EHTrendDirection.up;
    if (value < 0) return EHTrendDirection.down;
    return EHTrendDirection.neutral;
  }

  String _formatTrend(int value) {
    if (value > 0) return '+$value vs上周';
    if (value < 0) return '$value vs上周';
    return '持平 vs上周';
  }

  String _formatTrendDouble(double value, {bool isPercent = false}) {
    final suffix = isPercent ? '%' : '';
    if (value > 0) return '+${value.toStringAsFixed(0)}$suffix vs上周';
    if (value < 0) return '${value.toStringAsFixed(0)}$suffix vs上周';
    return '持平 vs上周';
  }
}
