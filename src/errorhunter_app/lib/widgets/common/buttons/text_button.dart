/// 错题猎手 - 文字按钮组件
/// 无边框无背景，仅文字+可选图标
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import 'primary_button.dart';

/// 文字按钮 - 轻量级操作
class EHTextButton extends StatefulWidget {
  const EHTextButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = EHButtonSize.md,
    this.color,
    this.isLoading = false,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final IconData? trailingIcon;
  final EHButtonSize size;
  final Color? color;
  final bool isLoading;
  final bool enabled;

  @override
  State<EHTextButton> createState() => _EHTextButtonState();
}

class _EHTextButtonState extends State<EHTextButton> {
  bool _isPressed = false;

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

  Color get _contentColor {
    final baseColor = widget.color ?? AppColors.brandPrimary;
    if (!_isEnabled) return baseColor.withOpacity(0.4);
    if (_isPressed) return baseColor.withOpacity(0.7);
    return baseColor;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: _isEnabled ? widget.onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: widget.isLoading
            ? SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(_contentColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: _iconSize, color: _contentColor),
                    SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    widget.text,
                    style: _textStyle.copyWith(color: _contentColor),
                  ),
                  if (widget.trailingIcon != null) ...[
                    SizedBox(width: AppSpacing.xs),
                    Icon(widget.trailingIcon, size: _iconSize, color: _contentColor),
                  ],
                ],
              ),
      ),
    );
  }
}
