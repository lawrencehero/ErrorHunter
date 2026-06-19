/// 错题猎手 - OTP验证码输入框组件
/// 6位数字独立方框样式
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// OTP验证码输入框
class EHOtpInput extends StatefulWidget {
  const EHOtpInput({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.errorText,
    this.enabled = true,
    this.autoFocus = true,
  });

  /// 输入完成回调，参数为完整验证码字符串
  final ValueChanged<String> onCompleted;

  /// 验证码长度（默认6位）
  final int length;

  /// 错误提示
  final String? errorText;

  /// 是否启用
  final bool enabled;

  /// 是否自动聚焦
  final bool autoFocus;

  @override
  State<EHOtpInput> createState() => _EHOtpInputState();
}

class _EHOtpInputState extends State<EHOtpInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<String> _values;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _values = List.filled(widget.length, '');

    // 添加焦点监听
    for (int i = 0; i < widget.length; i++) {
      _focusNodes[i].addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // 处理粘贴多位数字
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < digits.length && (index + i) < widget.length; i++) {
        _values[index + i] = digits[i];
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = index + digits.length;
      if (nextIndex < widget.length) {
        _focusNodes[nextIndex].requestFocus();
      }
      _checkComplete();
      return;
    }

    _values[index] = value;

    if (value.isNotEmpty && index < widget.length - 1) {
      // 输入后自动跳到下一格
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // 删除后自动回到上一格
      _focusNodes[index - 1].requestFocus();
    }

    _checkComplete();
  }

  void _checkComplete() {
    final code = _values.join();
    if (code.length == widget.length && _values.every((c) => c.isNotEmpty)) {
      widget.onCompleted(code);
    }
  }

  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            return Container(
              width: 44,
              height: 52,
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                autofocus: widget.autoFocus && index == 0,
                enabled: widget.enabled,
                style: AppTypography.primary.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide(
                      color: _getBorderColor(index),
                      width: _focusNodes[index].hasFocus ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide(
                      color: _hasError ? AppColors.danger : AppColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide(
                      color: _hasError ? AppColors.danger : AppColors.brandPrimary,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide(
                      color: AppColors.border.withOpacity(0.5),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (v) => _onChanged(index, v),
              ),
            );
          }),
        ),
        if (_hasError) ...[
          SizedBox(height: AppSpacing.sm),
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

  Color _getBorderColor(int index) {
    if (_hasError) return AppColors.danger;
    if (_focusNodes[index].hasFocus) return AppColors.brandPrimary;
    return AppColors.border;
  }
}
