/// 错题猎手 - Snackbar 组件
/// 底部弹出，支持撤销操作
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// Snackbar
class EHSnackbar extends StatelessWidget {
  const EHSnackbar({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.duration = const Duration(seconds: 4),
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final Duration duration;

  /// 便捷显示方法
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: EHSnackbar(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          icon: icon,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(
          AppSpacing.base,
          0,
          AppSpacing.base,
          MediaQuery.of(context).padding.bottom + AppSpacing.sm,
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.white),
            SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTypography.primary.caption.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () {
                onAction?.call();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: Text(
                actionLabel!,
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.brandSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
