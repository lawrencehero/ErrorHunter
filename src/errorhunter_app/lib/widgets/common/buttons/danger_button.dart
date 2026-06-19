/// 错题猎手 - 危险按钮组件
/// 红色填充，用于删除、退出等危险操作
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import 'primary_button.dart';

/// 危险按钮 - 红色警告样式
class EHDangerButton extends StatefulWidget {
  const EHDangerButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = EHButtonSize.md,
    this.fullWidth = false,
    this.isLoading = false,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final IconData? trailingIcon;
  final EHButtonSize size;
  final bool fullWidth;
  final bool isLoading;
  final bool enabled;

  @override
  State<EHDangerButton> createState() => _EHDangerButtonState();
}

class _EHDangerButtonState extends State<EHDangerButton> {
  bool _isPressed = false;

  double get _height {
    switch (widget.size) {
      case EHButtonSize.sm:
        return 32.0;
      case EHButtonSize.md:
        return 44.0;
      case EHButtonSize.lg:
        return 52.0;
    }
  }

  double get _horizontalPadding {
    switch (widget.size) {
      case EHButtonSize.sm:
        return AppSpacing.sm;
      case EHButtonSize.md:
        return AppSpacing.base;
      case EHButtonSize.lg:
        return AppSpacing.lg;
    }
  }

  TextStyle get _textStyle {
    final typo = AppTypography.primary;
    switch (widget.size) {
      case EHButtonSize.sm:
        return typo.caption.copyWith(fontWeight: FontWeight.w500);
      case EHButtonSize.md:
        return typo.button;
      case EHButtonSize.lg:
        return typo.button.copyWith(fontSize: 18);
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case EHButtonSize.sm:
        return 16.0;
      case EHButtonSize.md:
        return 20.0;
      case EHButtonSize.lg:
        return 24.0;
    }
  }

  bool get _isEnabled => widget.enabled && !widget.isLoading && widget.onPressed != null;

  Color get _backgroundColor {
    if (!_isEnabled) return AppColors.danger.withOpacity(0.4);
    if (_isPressed) return AppColors.danger.withOpacity(0.8);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: _isEnabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: _height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: AppRadius.radiusMd,
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: _iconSize, color: Colors.white),
                    SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    widget.text,
                    style: _textStyle.copyWith(color: Colors.white),
                  ),
                  if (widget.trailingIcon != null) ...[
                    SizedBox(width: AppSpacing.xs),
                    Icon(widget.trailingIcon, size: _iconSize, color: Colors.white),
                  ],
                ],
              ),
      ),
    );
  }
}
