/// 错题猎手 - 复习进度条组件
/// 渐变色微型进度条，显示第N轮/共M轮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';

/// 复习进度条
class ReviewProgressBar extends StatelessWidget {
  const ReviewProgressBar({
    super.key,
    required this.currentRound,
    required this.totalRounds,
    this.height = 4.0,
    this.showLabel = true,
  });

  final int currentRound;
  final int totalRounds;
  final double height;
  final bool showLabel;

  double get _progress =>
      totalRounds > 0 ? (currentRound / totalRounds).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '复习进度',
                style: AppTypography.primary.caption.copyWith(
                  color: tc.secondary,
                ),
              ),
              Text(
                '第${currentRound}轮 / 共${totalRounds}轮',
                style: AppTypography.primary.caption.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: height,
            backgroundColor: isGlass
                ? Colors.white.withOpacity(0.15)
                : AppColors.border.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
                _gradientColor(isGlass: isGlass)),
          ),
        ),
      ],
    );
  }

  Color _gradientColor({required bool isGlass}) {
    if (_progress >= 1.0) {
      return isGlass ? const Color(0xFF81C784) : AppColors.success;
    }
    if (_progress >= 0.6) {
      return isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    }
    if (_progress >= 0.3) {
      return isGlass ? const Color(0xFFFFB74D) : AppColors.warning;
    }
    return isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
  }
}
