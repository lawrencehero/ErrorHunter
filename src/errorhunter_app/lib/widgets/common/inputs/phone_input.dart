/// 错题猎手 - 手机号输入框组件
/// 自动格式化：138 0000 0000
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import 'text_field.dart';

/// 手机号输入框
class EHPhoneInput extends StatefulWidget {
  const EHPhoneInput({
    super.key,
    this.controller,
    this.label = '手机号',
    this.hintText = '请输入手机号',
    this.errorText,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String label;
  final String hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<EHPhoneInput> createState() => _EHPhoneInputState();
}

class _EHPhoneInputState extends State<EHPhoneInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// 获取纯数字手机号
  String get rawPhone => _controller.text.replaceAll(' ', '');

  void _onChanged(String value) {
    // 移除空格后重新格式化
    final digits = value.replaceAll(' ', '');
    if (digits.length > 11) return;

    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 7) formatted += ' ';
      formatted += digits[i];
    }

    // 避免无限循环
    if (_controller.text != formatted) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    widget.onChanged?.call(digits);
  }

  @override
  Widget build(BuildContext context) {
    return EHTextField(
      controller: _controller,
      label: widget.label,
      hintText: widget.hintText,
      errorText: widget.errorText,
      prefixIcon: Icons.phone_android_rounded,
      keyboardType: TextInputType.phone,
      maxLength: 13, // 11位数字 + 2个空格
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: _onChanged,
      enabled: widget.enabled,
    );
  }
}
