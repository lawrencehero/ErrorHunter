/// 错题猎手 - 主按钮组件 V2.0
/// 渐变背景 + Duolingo chunky 底影 + 按压下沉动效
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/animations.dart';

/// 按钮尺寸枚举
enum EHButtonSize {
  sm, // 小按钮：高度36px
  md, // 中按钮：高度48px（默认）
  lg, // 大按钮：高度56px
}

/// 主按钮 - 渐变背景 + Chunky 底影
class EHPrimaryButton extends StatefulWidget {
  const EHPrimaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.trailingIcon,
    this.size = EHButtonSize.md,
    this.fullWidth = false,
    this.isLoading = false,
    this.enabled = true,
    this.gradient,
  });

  /// 点击回调
  final VoidCallback? onPressed;

  /// 按钮文字
  final String text;

  /// 前置图标
  final IconData? icon;

  /// 后置图标
  final IconData? trailingIcon;

  /// 按钮尺寸
  final EHButtonSize size;

  /// 是否撑满宽度
  final bool fullWidth;

  /// 是否显示加载状态
  final bool isLoading;

  /// 是否启用
  final bool enabled;

  /// 自定义渐变（默认 brandPrimary gradient）
  final LinearGradient? gradient;

  @override
  State<EHPrimaryButton> createState() => _EHPrimaryButtonState();
}

class _EHPrimaryButtonState extends State<EHPrimaryButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  double get _height {
    switch (widget.size) {
      case EHButtonSize.sm:
        return 36.0;
      case EHButtonSize.md:
        return 48.0;
      case EHButtonSize.lg:
        return 56.0;
    }
  }

  double get _horizontalPadding {
    switch (widget.size) {
      case EHButtonSize.sm:
        return AppSpacing.md;
      case EHButtonSize.md:
        return 28.0;
      case EHButtonSize.lg:
        return 32.0;
    }
  }

  TextStyle get _textStyle {
    final typo = AppTypography.primary;
    switch (widget.size) {
      case EHButtonSize.sm:
        return typo.caption.copyWith(fontWeight: FontWeight.w700);
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

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppGradients.primary;
    final chunkyColor = _isEnabled
        ? AppGradients.primaryDark
        : AppColors.textTertiary;

    return GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: _isEnabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: AppAnimations.micro,
        curve: AppAnimations.standard,
        height: _height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
        transform: _isPressed
            ? (Matrix4.identity()..translate(0.0, AppAnimations.buttonPressOffset))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: _isEnabled ? gradient : null,
          color: _isEnabled ? null : AppColors.brandPrimary.withOpacity(0.4),
          borderRadius: AppRadius.radiusLg,
          boxShadow: _isPressed
              ? null
              : [
                  BoxShadow(
                    color: chunkyColor,
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
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
                    style: _textStyle.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
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
