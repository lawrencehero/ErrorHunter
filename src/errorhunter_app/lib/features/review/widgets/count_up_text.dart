/// 错题猎手 - 数字递增动画组件
/// 用于消灭计数展示
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

/// 数字递增动画文字
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
    this.style,
  });

  final int value;
  final String prefix;
  final String suffix;
  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, currentValue, child) {
        return Text(
          '$prefix$currentValue$suffix',
          style: style ??
              AppTypography.primary.number.copyWith(
                color: AppColors.success,
              ),
        );
      },
    );
  }
}
