/// 错题猎手 - 简化消灭 Toast 组件
/// 同轮第2+次消灭时使用，半透明黑色背景，0.5秒显示
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 简化消灭Toast
class SimplifiedEliminateToast extends StatefulWidget {
  const SimplifiedEliminateToast({
    super.key,
    required this.totalEliminated,
    this.onDismiss,
  });

  final int totalEliminated;
  final VoidCallback? onDismiss;

  @override
  State<SimplifiedEliminateToast> createState() =>
      _SimplifiedEliminateToastState();
}

class _SimplifiedEliminateToastState extends State<SimplifiedEliminateToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();

    // 0.5秒后自动消失
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss?.call());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: AppRadius.radiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 18)),
            SizedBox(width: AppSpacing.sm),
            Text(
              '又消灭一道！',
              style: AppTypography.primary.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              '已消灭 ${widget.totalEliminated} 道 🎯',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
