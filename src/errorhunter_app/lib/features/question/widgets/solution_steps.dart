/// 错题猎手 - 解题过程分步展示组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import '../models/question_model.dart';

/// 解题过程分步展示
class SolutionSteps extends StatelessWidget {
  const SolutionSteps({
    super.key,
    required this.steps,
  });

  final List<SolutionStep> steps;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    if (steps.isEmpty) {
      return Text(
        '暂无解题过程',
        style: AppTypography.primary.caption.copyWith(
          color: tc.tertiary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '解题过程',
          style: AppTypography.primary.h3.copyWith(
            color: tc.primary,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        ...steps.map((step) => _StepItem(step: step)),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.step});

  final SolutionStep step;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // 语义色玻璃下提亮
    final dangerColor = isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: step.isErrorStep
                  ? dangerColor.withOpacity(isGlass ? 0.15 : 0.1)
                  : accent.withOpacity(isGlass ? 0.2 : 0.1),
              borderRadius: AppRadius.radiusFull,
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.stepNumber}',
              style: AppTypography.primary.caption.copyWith(
                color: step.isErrorStep ? dangerColor : accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // Step content
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: step.isErrorStep
                    ? dangerColor.withOpacity(isGlass ? 0.08 : 0.03)
                    : Colors.transparent,
                borderRadius: AppRadius.radiusMd,
                border: step.isErrorStep
                    ? Border.all(color: dangerColor.withOpacity(isGlass ? 0.3 : 0.2))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.content,
                      style: AppTypography.primary.body.copyWith(
                        color: step.isErrorStep
                            ? dangerColor
                            : tc.primary,
                        fontWeight: step.isErrorStep ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (step.isErrorStep)
                    Icon(Icons.error_outline, size: 16, color: dangerColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
