/// 错题猎手 - 文本输入框组件
/// 支持 label、hint、error、prefix/suffix icon
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

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

  Color get _borderColor {
    if (!widget.enabled) return AppColors.border.withOpacity(0.5);
    if (_hasError) return AppColors.danger;
    if (_isFocused) return AppColors.brandPrimary;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.primary.caption.copyWith(
              color: _hasError ? AppColors.danger : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
        ],
        // Input Field
        Container(
          decoration: BoxDecoration(
            color: widget.fillColor ?? (widget.enabled ? Colors.white : AppColors.background),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: _borderColor, width: _isFocused ? 1.5 : 1),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTypography.primary.body.copyWith(
                color: AppColors.textTertiary,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: 20, color: AppColors.textSecondary)
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
              color: widget.enabled ? AppColors.textPrimary : AppColors.textTertiary,
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
              color: AppColors.danger,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
