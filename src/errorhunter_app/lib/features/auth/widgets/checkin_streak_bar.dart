/// 错题猎手 - 打卡激励条 V3.0 (游戏化)
/// 橙色渐变 + chunky 3D底影 + 火焰动画 + 进度条
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/animations.dart';
import '../../../theme/theme_manager.dart';

class CheckinStreakBar extends StatefulWidget {
  const CheckinStreakBar({super.key, required this.streakDays});
  final int streakDays;

  @override
  State<CheckinStreakBar> createState() => _CheckinStreakBarState();
}

class _CheckinStreakBarState extends State<CheckinStreakBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppAnimations.streakFireCycle,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    // 玻璃下强调色提亮为暖橙红（与游戏化暖渐变呼应，避免在玻璃上叠 chunky 底影）
    final accent = isGlass ? const Color(0xFFFFAB91) : AppColors.brandSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // 玻璃下保留暖色渐变作为强调（叠在玻璃背景上仍可读），但去掉 chunky 底影
        gradient: AppGradients.warm,
        borderRadius: BorderRadius.circular(20),
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25), width: 1) : null,
        boxShadow: isGlass
            ? null
            : [
                BoxShadow(
                  color: AppColors.brandSecondaryDark,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Row(
        children: [
          // 火焰动画
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(scale: _pulseAnimation.value, child: child);
            },
            child: Text('🔥', style: TextStyle(fontSize: isGlass ? 28.0 : 32.0)),
          ),
          const SizedBox(width: 14),
          // 文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续打卡',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${widget.streakDays}',
                      style: TextStyle(
                        color: isGlass ? accent : Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '天',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 进度条
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isGlass ? accent : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 奖杯
          const Text('🏆', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }
}
