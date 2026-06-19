/// 错题猎手 - 成就列表组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../models/weekly_report_model.dart';

/// 成就列表
class ReportAchievementList extends StatelessWidget {
  const ReportAchievementList({
    super.key,
    required this.achievements,
  });

  final List<AchievementItem> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Center(
          child: Text(
            '本周暂无成就',
            style: AppTypography.primary.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏆 ', style: TextStyle(fontSize: 18)),
            Text(
              '本周成就',
              style: AppTypography.primary.h3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        ...achievements.map((a) => Container(
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              padding: AppSpacing.cardInnerPadding,
              decoration: BoxDecoration(
                color: AppColors.brandSecondary.withOpacity(0.06),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Row(
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 28)),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: AppTypography.primary.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          a.description,
                          style: AppTypography.primary.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
