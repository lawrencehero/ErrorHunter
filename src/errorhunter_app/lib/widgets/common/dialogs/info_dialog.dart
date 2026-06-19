/// 错题猎手 - 信息弹窗组件
/// 标题 + 内容 + 单按钮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../buttons/buttons.dart';

/// 信息弹窗
class EHInfoDialog extends StatelessWidget {
  const EHInfoDialog({
    super.key,
    required this.title,
    this.content,
    this.buttonText = '我知道了',
    this.onPressed,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? content;
  final String buttonText;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;

  /// 便捷显示方法
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? content,
    String buttonText = '我知道了',
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog(
      context: context,
      builder: (_) => EHInfoDialog(
        title: title,
        content: content,
        buttonText: buttonText,
        icon: icon,
        iconColor: iconColor,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXl,
        ),
        padding: AppSpacing.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: iconColor ?? AppColors.brandPrimary),
              SizedBox(height: AppSpacing.sm),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.primary.h2.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (content != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                content!,
                textAlign: TextAlign.center,
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            SizedBox(height: AppSpacing.lg),
            EHPrimaryButton(
              text: buttonText,
              onPressed: onPressed ?? () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
