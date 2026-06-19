/// 错题猎手 - 复习进度条组件 V2.0
/// 渐变填充 + 更大高度 + overshoot 动画
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/animations.dart';

/// 复习进度条 V2.0
class ReviewProgressBar extends StatelessWidget {
  const ReviewProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.backgroundColor = AppColors.border,
    this.gradient,
  });

  /// 进度值 0.0 ~ 1.0
  final double progress;
  final double height;
  final Color backgroundColor;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.radiusFull,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // 背景
            Container(color: backgroundColor),
            // 前景渐变动画
            AnimatedFractionallySizedBox(
              duration: AppAnimations.progressFill,
              curve: AppAnimations.overshoot,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient ?? AppGradients.primary,
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
