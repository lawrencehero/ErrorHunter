/// 错题猎手 - 图标按钮组件
/// 纯图标按钮，支持圆形/圆角方形
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';

/// 图标按钮尺寸
enum EHIconButtonSize {
  sm, // 32x32
  md, // 40x40（默认）
  lg, // 48x48
}

/// 图标按钮样式
enum EHIconButtonStyle {
  filled, // 填充色背景
  outlined, // 边框样式
  ghost, // 透明背景
}

/// 图标按钮
class EHIconButton extends StatefulWidget {
  const EHIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = EHIconButtonSize.md,
    this.style = EHIconButtonStyle.ghost,
    this.color,
    this.backgroundColor,
    this.isLoading = false,
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final EHIconButtonSize size;
  final EHIconButtonStyle style;
  final Color? color;
  final Color? backgroundColor;
  final bool isLoading;
  final bool enabled;
  final String? tooltip;

  @override
  State<EHIconButton> createState() => _EHIconButtonState();
}

class _EHIconButtonState extends State<EHIconButton> {
  bool _isPressed = false;

  double get _dimension {
    switch (widget.size) {
      case EHIconButtonSize.sm:
        return 32.0;
      case EHIconButtonSize.md:
        return 40.0;
      case EHIconButtonSize.lg:
        return 48.0;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case EHIconButtonSize.sm:
        return 16.0;
      case EHIconButtonSize.md:
        return 20.0;
      case EHIconButtonSize.lg:
        return 24.0;
    }
  }

  bool get _isEnabled => widget.enabled && !widget.isLoading && widget.onPressed != null;

  Color get _effectiveColor {
    final base = widget.color ?? AppColors.textPrimary;
    if (!_isEnabled) return base.withOpacity(0.4);
    if (_isPressed) return base.withOpacity(0.7);
    return base;
  }

  Color? get _effectiveBackgroundColor {
    switch (widget.style) {
      case EHIconButtonStyle.filled:
        final base = widget.backgroundColor ?? AppColors.brandPrimary;
        if (!_isEnabled) return base.withOpacity(0.4);
        if (_isPressed) return base.withOpacity(0.8);
        return base;
      case EHIconButtonStyle.outlined:
        if (_isPressed && _isEnabled) {
          return (widget.backgroundColor ?? AppColors.brandPrimary).withOpacity(0.05);
        }
        return Colors.transparent;
      case EHIconButtonStyle.ghost:
        if (_isPressed && _isEnabled) {
          return AppColors.textPrimary.withOpacity(0.05);
        }
        return Colors.transparent;
    }
  }

  Border? get _border {
    if (widget.style == EHIconButtonStyle.outlined) {
      final borderColor = _isEnabled
          ? (widget.color ?? AppColors.border)
          : AppColors.border.withOpacity(0.4);
      return Border.all(color: borderColor, width: 1.5);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: _isEnabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _dimension,
        height: _dimension,
        decoration: BoxDecoration(
          color: _effectiveBackgroundColor,
          borderRadius: AppRadius.radiusFull,
          border: _border,
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(_effectiveColor),
                ),
              )
            : Icon(widget.icon, size: _iconSize, color: _effectiveColor),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
