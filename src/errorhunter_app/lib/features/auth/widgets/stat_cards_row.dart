/// 错题猎手 - 统计卡片行 V3.0 (游戏化)
/// Chunky 3D底影 + 居中大数字
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

class StatCardsRow extends StatelessWidget {
  const StatCardsRow({
    super.key,
    required this.totalQuestions,
    required this.eliminatedCount,
    required this.eliminationRate,
  });

  final int totalQuestions;
  final int eliminatedCount;
  final double eliminationRate;

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    // 玻璃下语义色提亮
    final totalColor = isGlass ? Colors.white : AppColors.textPrimary;
    final eliminatedColor = isGlass ? const Color(0xFF81C784) : AppColors.success;
    final rateColor = isGlass ? const Color(0xFFFFAB91) : AppColors.brandSecondary;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$totalQuestions',
            label: '累计错题',
            valueColor: totalColor,
            isGlass: isGlass,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            value: '$eliminatedCount',
            label: '已消灭',
            valueColor: eliminatedColor,
            isGlass: isGlass,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            value: '${(eliminationRate * 100).toStringAsFixed(0)}%',
            label: '消灭率',
            valueColor: rateColor,
            isGlass: isGlass,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.isGlass,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        // 玻璃下：半透明白底 + 白色描边，去掉 chunky 底影
        color: isGlass ? Colors.white.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25), width: 1) : null,
        boxShadow: isGlass
            ? null
            : [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                BoxShadow(
                  color: AppColors.border,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: tc.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
