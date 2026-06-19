/// 错题猎手 - 步骤指示器组件 V2.0
/// 渐变进度条 + 数字步骤标记 + 完成打勾
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/animations.dart';

/// 步骤指示器 V2.0
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  /// 当前步骤（从1开始）
  final int currentStep;

  /// 总步骤数
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 步骤数字
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps * 2 - 1, (i) {
            if (i.isOdd) {
              // 连接线
              final stepBefore = (i ~/ 2) + 1;
              final isCompleted = stepBefore < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isCompleted ? AppGradients.primary : null,
                    color: isCompleted ? null : AppColors.border,
                    borderRadius: AppRadius.radiusFull,
                  ),
                ),
              );
            }
            // 步骤圆
            final step = (i ~/ 2) + 1;
            final isCompleted = step < currentStep;
            final isCurrent = step == currentStep;

            return Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (isCompleted || isCurrent) ? AppGradients.primary : null,
                color: (isCompleted || isCurrent) ? null : AppColors.background,
                border: (isCompleted || isCurrent)
                    ? null
                    : Border.all(color: AppColors.border, width: 2),
                boxShadow: isCurrent
                    ? AppShadows.brandGlow
                    : null,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: AppTypography.primary.caption.copyWith(
                        color: isCurrent
                            ? Colors.white
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            );
          }),
        ),
      ],
    );
  }
}
