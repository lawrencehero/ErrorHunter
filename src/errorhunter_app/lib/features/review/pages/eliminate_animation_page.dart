/// 错题猎手 - P8 消灭动画页
/// 卡片碎裂 + 撒花粒子 + 文字浮现 + 计数展示
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../widgets/confetti_painter.dart';
import '../widgets/count_up_text.dart';

/// 消灭动画页
class EliminateAnimationPage extends StatefulWidget {
  const EliminateAnimationPage({
    super.key,
    required this.totalEliminated,
    this.isFirstInSession = true,
  });

  /// 本轮已消灭总数
  final int totalEliminated;

  /// 是否为本轮首次消灭（首次完整动画，否则简化Toast）
  final bool isFirstInSession;

  @override
  State<EliminateAnimationPage> createState() =>
      _EliminateAnimationPageState();
}

class _EliminateAnimationPageState extends State<EliminateAnimationPage>
    with TickerProviderStateMixin {
  // 总时长2秒的动画控制器
  late AnimationController _masterController;

  // 阶段1: 卡片碎裂 (0-0.8s → 0.0-0.4)
  late Animation<double> _shatterScale;
  late Animation<double> _shatterOpacity;

  // 阶段2: 撒花粒子 (0.5-1.7s → 0.25-0.85)
  late Animation<double> _confettiProgress;

  // 阶段3: 文字浮现 (0.8-1.5s → 0.4-0.75)
  late Animation<double> _textSlideY;
  late Animation<double> _textOpacity;

  // 阶段4: 计数展示 (1.2-2.0s → 0.6-1.0)
  late Animation<double> _countOpacity;

  bool _isSkipped = false;

  @override
  void initState() {
    super.initState();

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 阶段1: 卡片碎裂
    _shatterScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );
    _shatterOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );

    // 阶段2: 撒花粒子
    _confettiProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.25, 0.85, curve: Curves.linear),
      ),
    );

    // 阶段3: 文字浮现
    _textSlideY = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
      ),
    );

    // 阶段4: 计数展示
    _countOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _masterController.forward();

    // 动画完成后通知BLoC
    _masterController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isSkipped) {
        _onAnimationComplete();
      }
    });
  }

  void _skipAnimation() {
    if (_isSkipped) return;
    _isSkipped = true;
    _masterController.stop();
    _onAnimationComplete();
  }

  void _onAnimationComplete() {
    if (!mounted) return;
    context.read<ReviewBloc>().add(const ResetEliminateState());
  }

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    // 计数强调色：玻璃下用亮消灭绿保证在深色渐变上的可读性。
    final countColor = isGlass ? const Color(0xFF81C784) : AppColors.success;
    return GestureDetector(
      onTap: _skipAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ─── 撒花粒子层 ──────────────────────────────
            AnimatedBuilder(
              animation: _confettiProgress,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: ConfettiPainter(
                    progress: _confettiProgress.value,
                  ),
                );
              },
            ),

            // ─── 中心内容层 ──────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 阶段1: 碎裂的卡片
                  AnimatedBuilder(
                    animation: _shatterScale,
                    builder: (context, child) {
                      if (_shatterOpacity.value <= 0.01) {
                        return const SizedBox.shrink();
                      }
                      return Opacity(
                        opacity: _shatterOpacity.value,
                        child: Transform.scale(
                          scale: _shatterScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 200,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '✅',
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // 阶段3: 文字浮现
                  AnimatedBuilder(
                    animation: _textOpacity,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _textOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideY.value),
                          child: Text(
                            '又消灭一道错题！🎉',
                            style: AppTypography.primary.h2.copyWith(
                              color: tc.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: AppSpacing.md),

                  // 阶段4: 计数展示
                  FadeTransition(
                    opacity: _countOpacity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '已消灭 ',
                          style: AppTypography.primary.body.copyWith(
                            color: tc.secondary,
                          ),
                        ),
                        CountUpText(
                          value: widget.totalEliminated,
                          duration: const Duration(milliseconds: 800),
                          style: AppTypography.primary.number.copyWith(
                            color: countColor,
                          ),
                        ),
                        Text(
                          ' 道',
                          style: AppTypography.primary.body.copyWith(
                            color: tc.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── 底部跳过提示 ────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 0.6).animate(
                  CurvedAnimation(
                    parent: _masterController,
                    curve: const Interval(0.5, 0.7),
                  ),
                ),
                child: Center(
                  child: Text(
                    '点击任意位置跳过',
                    style: AppTypography.primary.caption.copyWith(
                      color: tc.tertiary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
