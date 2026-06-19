/// 错题猎手 - 解题过程分步展示组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
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
    if (steps.isEmpty) {
      return Text(
        '暂无解题过程',
        style: AppTypography.primary.caption.copyWith(
          color: AppColors.textTertiary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '解题过程',
          style: AppTypography.primary.h3.copyWith(
            color: AppColors.textPrimary,
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
                  ? AppColors.danger.withOpacity(0.1)
                  : AppColors.brandPrimary.withOpacity(0.1),
              borderRadius: AppRadius.radiusFull,
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.stepNumber}',
              style: AppTypography.primary.caption.copyWith(
                color: step.isErrorStep ? AppColors.danger : AppColors.brandPrimary,
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
                    ? AppColors.danger.withOpacity(0.03)
                    : Colors.transparent,
                borderRadius: AppRadius.radiusMd,
                border: step.isErrorStep
                    ? Border.all(color: AppColors.danger.withOpacity(0.2))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.content,
                      style: AppTypography.primary.body.copyWith(
                        color: step.isErrorStep
                            ? AppColors.danger
                            : AppColors.textPrimary,
                        fontWeight: step.isErrorStep ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (step.isErrorStep)
                    Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
