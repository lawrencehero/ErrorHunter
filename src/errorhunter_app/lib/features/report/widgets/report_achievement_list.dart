/// 错题猎手 - 成就列表组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
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
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;

    if (achievements.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Center(
          child: Text(
            '本周暂无成就',
            style: AppTypography.primary.caption.copyWith(
              color: tc.tertiary,
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
                color: tc.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        ...achievements.map((a) => Container(
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              padding: AppSpacing.cardInnerPadding,
              decoration: BoxDecoration(
                color: (isGlass ? Colors.white : AppColors.brandSecondary)
                    .withOpacity(isGlass ? 0.12 : 0.06),
                borderRadius: AppRadius.radiusMd,
                border: isGlass
                    ? Border.all(color: Colors.white.withOpacity(0.25))
                    : null,
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
                            color: tc.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          a.description,
                          style: AppTypography.primary.caption.copyWith(
                            color: tc.secondary,
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
