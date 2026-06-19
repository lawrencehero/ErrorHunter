/// 错题猎手 - 通用空状态组件
/// 图标 + 标题 + 描述 + 操作按钮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../buttons/buttons.dart';

/// 通用空状态
class EHEmptyState extends StatelessWidget {
  const EHEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionText,
    this.onAction,
    this.iconColor,
    this.iconSize = 80.0,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? AppColors.textTertiary.withOpacity(0.5),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.primary.h3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (description != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              SizedBox(height: AppSpacing.xl),
              EHPrimaryButton(
                text: actionText!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
