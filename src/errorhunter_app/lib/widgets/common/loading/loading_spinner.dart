/// 错题猎手 - 加载旋转器
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// 加载旋转器尺寸
enum EHLoadingSpinnerSize { sm, md, lg }

/// 加载旋转器
class EHLoadingSpinner extends StatelessWidget {
  const EHLoadingSpinner({
    super.key,
    this.size = EHLoadingSpinnerSize.md,
    this.color,
  });

  final EHLoadingSpinnerSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _dimension,
      height: _dimension,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.brandPrimary,
        ),
      ),
    );
  }

  double get _dimension {
    switch (size) {
      case EHLoadingSpinnerSize.sm:
        return 20.0;
      case EHLoadingSpinnerSize.md:
        return 36.0;
      case EHLoadingSpinnerSize.lg:
        return 48.0;
    }
  }

  double get _strokeWidth {
    switch (size) {
      case EHLoadingSpinnerSize.sm:
        return 2.0;
      case EHLoadingSpinnerSize.md:
        return 3.0;
      case EHLoadingSpinnerSize.lg:
        return 4.0;
    }
  }
}
