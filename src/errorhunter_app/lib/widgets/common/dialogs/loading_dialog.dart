/// 错题猎手 - 加载弹窗组件
/// 全屏遮罩 + 居中加载指示器
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 加载弹窗
class EHLoadingDialog extends StatelessWidget {
  const EHLoadingDialog({
    super.key,
    this.message,
    this.barrierDismissible = false,
  });

  final String? message;
  final bool barrierDismissible;

  /// 便捷显示方法
  static Future<T?> show<T>(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.overlay,
      builder: (_) => EHLoadingDialog(
        message: message,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  /// 关闭加载弹窗
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: barrierDismissible,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.radiusLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                ),
              ),
              if (message != null) ...[
                SizedBox(height: AppSpacing.md),
                Text(
                  message!,
                  style: AppTypography.primary.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
