/// 错题猎手 - 四宫格统计组件
/// 展示周报四项核心指标 + vs上周趋势
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/cards/stat_card.dart';

/// 四宫格统计
///
/// 设计说明：早期使用 `GridView.count` + `childAspectRatio: 1.6` 固定单元格高度，
/// 但卡片实际内容（图标行 + 超大数值 + 趋势胶囊）在小学/初中两种字号下所需的
/// 自然高度超过 1.6 比例给出的高度，叠加 `EHStatCard` 的 `Clip.antiAlias` 会让
/// 底部趋势胶囊（如「持平 vs 上周」）只露出上半截被裁剪。
///
/// 现改为两行 `Row`（每行两张卡片，`Expanded` 等分宽度），行外包 `IntrinsicHeight`
/// 让同行卡片等高，高度交给 `EHStatCard` 内部的 `IntrinsicHeight` +
/// `mainAxisSize.min` 按内容自适应。这样无论字号、趋势文案长短，趋势行都能完整
/// 显示，不被裁剪。
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
    final isGlass = context.themeExt.isDarkBackground;
    final cards = <Widget>[
      EHStatCard(
        label: '新增错题',
        value: '$newCount',
        trend: _trend(newVsLastWeek),
        trendValue: _formatTrend(newVsLastWeek),
        valueColor: isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary,
        accentColor: isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary,
        icon: Icons.add_circle_outline_rounded,
      ),
      EHStatCard(
        label: '消灭错题',
        value: '$eliminatedCount',
        trend: _trend(eliminatedVsLastWeek),
        trendValue: _formatTrend(eliminatedVsLastWeek),
        valueColor: isGlass ? const Color(0xFF81C784) : AppColors.success,
        accentColor: isGlass ? const Color(0xFF81C784) : AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      ),
      EHStatCard(
        label: '复习次数',
        value: '$reviewCount',
        trend: _trend(reviewVsLastWeek),
        trendValue: _formatTrend(reviewVsLastWeek),
        valueColor: isGlass ? const Color(0xFFFFAB91) : AppColors.brandSecondary,
        accentColor: isGlass ? const Color(0xFFFFAB91) : AppColors.brandSecondary,
        icon: Icons.refresh_rounded,
      ),
      EHStatCard(
        label: '正确率',
        value: '${accuracyRate.toStringAsFixed(0)}%',
        trend: _trendDouble(accuracyVsLastWeek),
        trendValue: _formatTrendDouble(accuracyVsLastWeek, isPercent: true),
        valueColor: isGlass ? const Color(0xFFFFCC80) : AppColors.warning,
        accentColor: isGlass ? const Color(0xFFFFCC80) : AppColors.warning,
        icon: Icons.trending_up_rounded,
      ),
    ];

    return Column(
      children: [
        _buildRow(cards.sublist(0, 2)),
        const SizedBox(height: AppSpacing.sm),
        _buildRow(cards.sublist(2, 4)),
      ],
    );
  }

  /// 构建一行（两张卡片）：宽度等分，高度按内容自适应并对齐。
  Widget _buildRow(List<Widget> cards) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: cards[1]),
        ],
      ),
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
