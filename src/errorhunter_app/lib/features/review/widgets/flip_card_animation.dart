/// 错题猎手 - 3D翻转卡片动画组件
/// 支持正面/背面切换，0.3s 3D翻转效果
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 3D翻转卡片动画
class FlipCardAnimation extends StatefulWidget {
  const FlipCardAnimation({
    super.key,
    required this.front,
    required this.back,
    required this.isFlipped,
    this.duration = const Duration(milliseconds: 300),
  });

  /// 卡片正面
  final Widget front;

  /// 卡片背面
  final Widget back;

  /// 是否翻转到背面
  final bool isFlipped;

  /// 翻转动画时长
  final Duration duration;

  @override
  State<FlipCardAnimation> createState() => _FlipCardAnimationState();
}

class _FlipCardAnimationState extends State<FlipCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant FlipCardAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * math.pi;
        final isShowingBack = angle > math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 透视效果
            ..rotateY(angle),
          child: isShowingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.back,
                )
              : widget.front,
        );
      },
    );
  }
}
