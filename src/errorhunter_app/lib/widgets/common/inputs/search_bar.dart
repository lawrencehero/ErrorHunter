/// 错题猎手 - 搜索栏组件
/// 带搜索图标和清除按钮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 搜索栏
class EHSearchBar extends StatefulWidget {
  const EHSearchBar({
    super.key,
    this.controller,
    this.hintText = '搜索错题...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autoFocus = false,
    this.enabled = true,
    this.backgroundColor,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autoFocus;
  final bool enabled;
  final Color? backgroundColor;

  @override
  State<EHSearchBar> createState() => _EHSearchBarState();
}

class _EHSearchBarState extends State<EHSearchBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.background,
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autoFocus,
        enabled: widget.enabled,
        style: AppTypography.primary.body.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.primary.body.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _hasText
              ? GestureDetector(
                  onTap: _clear,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
        ),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
