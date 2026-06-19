/// 错题猎手 - Toast 提示组件
/// 顶部弹出，自动消失，支持成功/错误/警告/信息四种类型
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// Toast 类型
enum EHToastType { success, error, warning, info }

/// Toast 提示
class EHToast extends StatelessWidget {
  const EHToast({
    super.key,
    required this.message,
    this.type = EHToastType.info,
    this.duration = const Duration(seconds: 3),
  });

  final String message;
  final EHToastType type;
  final Duration duration;

  /// 便捷显示方法
  static void show(
    BuildContext context, {
    required String message,
    EHToastType type = EHToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _EHToastOverlay(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    // 直接构建（用于预览或自定义集成）
    return _buildContent();
  }

  Widget _buildContent() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.base),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: AppRadius.radiusMd,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 20, color: _iconColor),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: AppTypography.primary.caption.copyWith(
                color: _textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _backgroundColor {
    switch (type) {
      case EHToastType.success:
        return AppColors.success.withOpacity(0.1);
      case EHToastType.error:
        return AppColors.danger.withOpacity(0.1);
      case EHToastType.warning:
        return AppColors.warning.withOpacity(0.1);
      case EHToastType.info:
        return AppColors.brandPrimary.withOpacity(0.1);
    }
  }

  IconData get _icon {
    switch (type) {
      case EHToastType.success:
        return Icons.check_circle_rounded;
      case EHToastType.error:
        return Icons.error_rounded;
      case EHToastType.warning:
        return Icons.warning_rounded;
      case EHToastType.info:
        return Icons.info_rounded;
    }
  }

  Color get _iconColor {
    switch (type) {
      case EHToastType.success:
        return AppColors.success;
      case EHToastType.error:
        return AppColors.danger;
      case EHToastType.warning:
        return AppColors.warning;
      case EHToastType.info:
        return AppColors.brandPrimary;
    }
  }

  Color get _textColor {
    switch (type) {
      case EHToastType.success:
        return AppColors.success;
      case EHToastType.error:
        return AppColors.danger;
      case EHToastType.warning:
        return AppColors.warning;
      case EHToastType.info:
        return AppColors.brandPrimary;
    }
  }
}

/// Toast 覆盖层（带动画）
class _EHToastOverlay extends StatefulWidget {
  const _EHToastOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final EHToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_EHToastOverlay> createState() => _EHToastOverlayState();
}

class _EHToastOverlayState extends State<_EHToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSpacing.sm,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: EHToast(
              message: widget.message,
              type: widget.type,
            ),
          ),
        ),
      ),
    );
  }
}
