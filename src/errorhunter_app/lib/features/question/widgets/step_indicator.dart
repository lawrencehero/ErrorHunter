/// 错题猎手 - 步骤指示器组件 V2.0
/// 渐变进度条 + 数字步骤标记 + 完成打勾
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
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
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
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
                    // 玻璃下禁止品牌蓝渐变叠玻璃背景；用 accent 实色
                    gradient: (!isGlass && isCompleted) ? AppGradients.primary : null,
                    color: isCompleted
                        ? (isGlass ? accent : null)
                        : (isGlass ? Colors.white.withOpacity(0.25) : AppColors.border),
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
                // 玻璃下不用蓝色渐变；用 accent 实色填充
                gradient: (!isGlass && (isCompleted || isCurrent)) ? AppGradients.primary : null,
                color: (isCompleted || isCurrent)
                    ? (isGlass ? accent : null)
                    : (isGlass ? Colors.white.withOpacity(0.12) : AppColors.background),
                border: (isCompleted || isCurrent)
                    ? null
                    : Border.all(
                        color: isGlass
                            ? Colors.white.withOpacity(0.25)
                            : AppColors.border,
                        width: 2,
                      ),
                boxShadow: (!isGlass && isCurrent) ? AppShadows.brandGlow : null,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: AppTypography.primary.caption.copyWith(
                        color: isCurrent
                            ? Colors.white
                            : tc.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            );
          }),
        ),
      ],
    ),
    );
  }
}
