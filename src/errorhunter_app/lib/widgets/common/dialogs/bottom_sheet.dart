/// 错题猎手 - 底部抽屉组件
/// 可拖拽关闭的 Bottom Sheet
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';

/// 底部抽屉
class EHBottomSheet extends StatelessWidget {
  const EHBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.padding = AppSpacing.cardPadding,
    this.isScrollControlled = false,
    this.maxHeight,
  });

  final Widget child;
  final String? title;
  final bool showDragHandle;
  final EdgeInsets padding;
  final bool isScrollControlled;
  final double? maxHeight;

  /// 便捷显示方法
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showDragHandle = true,
    bool isScrollControlled = false,
    double? maxHeight,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (_) => EHBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        isScrollControlled: isScrollControlled,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    final tc = context.textColors;
    return Container(
      constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight!) : null,
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withOpacity(0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: isGlass
            ? Border.all(color: Colors.white.withOpacity(0.25))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
          if (showDragHandle) ...[
            SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isGlass
                    ? Colors.white.withOpacity(0.4)
                    : AppColors.border,
                borderRadius: AppRadius.radiusFull,
              ),
            ),
          ],
          // 标题栏
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                AppSpacing.md,
                padding.right,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTypography.primary.h3.copyWith(
                        color: tc.primary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close_rounded,
                      size: 24,
                      color: tc.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 内容区
          Flexible(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
          // 底部安全区
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
