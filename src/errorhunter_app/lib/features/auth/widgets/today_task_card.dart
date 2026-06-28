/// 错题猎手 - 今日任务卡片 V3.0 (游戏化)
/// 白色卡片 + chunky蓝底影 + 超大数字 + 渐变3D按钮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

class TodayTaskCard extends StatelessWidget {
  const TodayTaskCard({super.key, required this.pendingCount, this.onStartReview});
  final int pendingCount;
  final VoidCallback? onStartReview;

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    final tc = context.textColors;
    // 玻璃下强调色提亮为暖琥珀（避免蓝色叠渐变背景）
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 玻璃下：半透明白底 + 白描边，去掉 chunky 蓝底影
        color: isGlass ? Colors.white.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25), width: 1) : null,
        boxShadow: isGlass
            ? null
            : [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                BoxShadow(
                  color: AppColors.brandPrimaryDark,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isGlass ? Colors.white.withOpacity(0.15) : AppColors.brandPrimaryPale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '📝 今日任务',
              style: TextStyle(
                color: isGlass ? Colors.white : AppColors.brandPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 超大数字 + 描述
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pendingCount',
                style: TextStyle(
                  color: isGlass ? accent : AppColors.brandPrimary,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 0.85,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '道错题等你复习',
                  style: TextStyle(
                    color: tc.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 3D 渐变按钮（玻璃下去掉 chunky 底影，保留渐变主操作视觉）
          GestureDetector(
            onTap: onStartReview,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(16),
                border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25), width: 1) : null,
                boxShadow: isGlass
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.brandPrimaryDark,
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '开始复习',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
