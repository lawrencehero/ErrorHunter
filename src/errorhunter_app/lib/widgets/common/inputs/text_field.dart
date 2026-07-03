/// 错题猎手 - 文本输入框组件
/// 支持 label、hint、error、prefix/suffix icon
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

/// 文本输入框
class EHTextField extends StatefulWidget {
  const EHTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.fillColor,
    this.textColor,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final Color? fillColor;
  final Color? textColor;

  @override
  State<EHTextField> createState() => _EHTextFieldState();
}

class _EHTextFieldState extends State<EHTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    final tc = context.textColors;
    // 玻璃下强调色提亮为暖琥珀，游戏化保持品牌蓝
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // 玻璃下语义色提亮：danger
    final dangerColor = isGlass ? const Color(0xFFFF8A80) : AppColors.danger;

    Color borderColor() {
      if (!widget.enabled) {
        return isGlass
            ? Colors.white.withOpacity(0.15)
            : AppColors.border.withOpacity(0.5);
      }
      if (_hasError) return dangerColor;
      if (_isFocused) return accent;
      return isGlass ? Colors.white.withOpacity(0.25) : AppColors.border;
    }

    // 玻璃下底色：半透明白；游戏化：白/背景灰（保持原样）
    final resolvedFill = widget.fillColor ??
        (isGlass
            ? (widget.enabled
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.06))
            : (widget.enabled ? Colors.white : AppColors.background));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.primary.caption.copyWith(
              color: _hasError ? dangerColor : tc.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
        ],
        // Input Field
        Container(
          decoration: BoxDecoration(
            color: resolvedFill,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: borderColor(), width: _isFocused ? 1.5 : 1),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            cursorColor: accent,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTypography.primary.body.copyWith(
                color: tc.tertiary,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: 20, color: tc.secondary)
                  : null,
              suffixIcon: widget.suffixIcon,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm + 2,
              ),
              border: InputBorder.none,
              counterText: '',
            ),
            style: AppTypography.primary.body.copyWith(
              color: widget.textColor ??
                  (widget.enabled ? tc.primary : tc.tertiary),
            ),
            obscureText: widget.obscureText,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            textAlign: widget.textAlign,
          ),
        ),
        // Error message
        if (_hasError) ...[
          SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: AppTypography.primary.caption.copyWith(
              color: dangerColor,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
