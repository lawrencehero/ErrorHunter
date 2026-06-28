/// 错题猎手 - 数字递增动画组件
/// 用于消灭计数展示
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
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
    final isGlass = context.themeExt.isDarkBackground;
    // 默认成功色：玻璃下提亮为浅消灭绿，保证深色渐变背景上可读
    // （调用方仍可显式传入 style 覆盖，如 eliminate_animation_page.dart）。
    final successColor =
        isGlass ? const Color(0xFF81C784) : AppColors.success;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, currentValue, child) {
        return Text(
          '$prefix$currentValue$suffix',
          style: style ??
              AppTypography.primary.number.copyWith(
                color: successColor,
              ),
        );
      },
    );
  }
}
