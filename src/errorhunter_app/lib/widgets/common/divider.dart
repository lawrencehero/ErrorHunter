/// 错题猎手 - 分割线组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';

/// 分割线
class EHDivider extends StatelessWidget {
  const EHDivider({
    super.key,
    this.color,
    this.thickness = 0.5,
    this.indent,
    this.endIndent,
    this.margin,
    this.vertical = false,
  });

  final Color? color;
  final double thickness;
  final double? indent;
  final double? endIndent;
  final EdgeInsets? margin;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Container(
        width: thickness,
        margin: margin ?? EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        color: color ?? AppColors.border,
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Divider(
        color: color ?? AppColors.border,
        thickness: thickness,
        height: thickness,
        indent: indent,
        endIndent: endIndent,
      ),
    );
  }
}
