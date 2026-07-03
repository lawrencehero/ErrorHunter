/// 错题猎手 - 确认弹窗组件
/// 标题 + 内容 + 双按钮（取消/确认）
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../buttons/buttons.dart';

/// 确认弹窗
class EHConfirmDialog extends StatelessWidget {
  const EHConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.icon,
  });

  final String title;
  final String? content;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final IconData? icon;

  /// 便捷显示方法
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => EHConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
        // 必须用 dialogContext（对话框所在根 Navigator）来 pop，不能用外层
        // context：当调用方位于 ShellRoute 嵌套 Navigator 内时（如个人页），
        // Navigator.of(context) 解析到嵌套 Navigator，pop 会把调用页本身弹掉
        // 而非对话框，导致页面空屏、showDialog 不返回。
        onConfirm: () => Navigator.of(dialogContext).pop(true),
        onCancel: () => Navigator.of(dialogContext).pop(false),
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
              Icon(icon, size: 48, color: isDestructive ? AppColors.danger : AppColors.brandPrimary),
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
            Row(
              children: [
                Expanded(
                  child: EHSecondaryButton(
                    text: cancelText,
                    onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    fullWidth: true,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: isDestructive
                      ? EHDangerButton(
                          text: confirmText,
                          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                          fullWidth: true,
                        )
                      : EHPrimaryButton(
                          text: confirmText,
                          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                          fullWidth: true,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
