/// 错题猎手 - 基础卡片组件 V3.0 (多主题)
/// 游戏化：白色 + chunky底影 | 玻璃拟态：半透明 + 模糊
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/animations.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/theme_manager.dart';

/// 卡片阴影级别
enum EHCardElevation {
  low,
  medium,
  high,
}

/// 基础卡片 V3.0 - 主题感知
class EHBaseCard extends StatefulWidget {
  const EHBaseCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.borderRadius = AppRadius.radiusLg,
    this.backgroundColor,
    this.elevation = EHCardElevation.low,
    this.border,
    this.chunky = false,
    this.chunkyColor,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final BorderRadius borderRadius;

  /// 背景色 — null 时自动根据主题选择
  final Color? backgroundColor;

  final EHCardElevation elevation;
  final Border? border;
  final bool chunky;
  final Color? chunkyColor;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  State<EHBaseCard> createState() => _EHBaseCardState();
}

class _EHBaseCardState extends State<EHBaseCard> {
  bool _isPressed = false;

  Color _resolveBackground(BuildContext context) {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;
    if (isGlass) return Colors.white.withOpacity(ext.cardOpacity);
    return AppColors.surface;
  }

  List<BoxShadow> _resolveShadows(BuildContext context) {
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;

    final shadows = <BoxShadow>[];
    if (!widget.chunky && !isGlass) {
      switch (widget.elevation) {
        case EHCardElevation.low:
          shadows.addAll(AppShadows.elevation1);
        case EHCardElevation.medium:
          shadows.addAll(AppShadows.elevation2);
        case EHCardElevation.high:
          shadows.addAll(AppShadows.elevation3);
      }
    }
    if (widget.chunky && !_isPressed && !isGlass) {
      shadows.add(BoxShadow(
        color: widget.chunkyColor ?? AppColors.border,
        offset: const Offset(0, 3),
        blurRadius: 0,
      ));
    }
    return shadows;
  }

  Border? _resolveBorder(BuildContext context) {
    if (widget.border != null) return widget.border;
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;
    if (widget.chunky) return null;
    if (isGlass) {
      return Border.all(color: Colors.white.withOpacity(0.18), width: 1);
    }
    return Border.all(color: AppColors.border.withOpacity(0.5), width: 1.5);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _resolveBackground(context);
    final shadows = _resolveShadows(context);
    final border = _resolveBorder(context);
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;

    Widget card = GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.short,
        curve: AppAnimations.decelerate,
        margin: widget.margin,
        transform: widget.onTap != null && _isPressed
            ? (Matrix4.identity()..translate(0.0, AppAnimations.buttonPressOffset))
            : (widget.onTap != null
                ? (Matrix4.identity()..translate(0.0, AppAnimations.cardLiftOffset))
                : Matrix4.identity()),
        decoration: BoxDecoration(
          color: isGlass ? null : bgColor,
          borderRadius: widget.borderRadius,
          border: border,
          boxShadow: shadows,
        ),
        clipBehavior: widget.clipBehavior != Clip.none
            ? widget.clipBehavior
            : (widget.onTap != null ? Clip.antiAlias : Clip.none),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    // 玻璃拟态：用 BackdropFilter 实现毛玻璃效果
    if (isGlass) {
      card = ClipRRect(
        borderRadius: widget.borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: ext.cardBlur, sigmaY: ext.cardBlur),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: widget.borderRadius,
              border: border,
            ),
            child: card,
          ),
        ),
      );
    }

    return card;
  }
}
