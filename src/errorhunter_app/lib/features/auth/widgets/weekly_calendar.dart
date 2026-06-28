/// 错题猎手 - 本周打卡日历 V3.0 (游戏化)
/// 渐变完成圆点 + 3D底影 + chunky卡片
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

class WeeklyCalendar extends StatelessWidget {
  const WeeklyCalendar({super.key, required this.completedDays, this.todayIndex = 0});
  final List<bool> completedDays;
  final int todayIndex;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    final tc = context.textColors;
    // 玻璃下强调色提亮为暖琥珀（避免蓝色叠渐变背景）
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // 玻璃下：半透明白底 + 白描边，去掉 chunky 底影
        color: isGlass ? Colors.white.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25), width: 1) : null,
        boxShadow: isGlass
            ? null
            : [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                BoxShadow(color: AppColors.border, offset: const Offset(0, 3), blurRadius: 0),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isGlass ? Colors.white.withOpacity(0.15) : AppColors.brandPrimaryPale,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_today_rounded, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Text('本周打卡',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tc.primary),
              ),
              const Spacer(),
              Text('${completedDays.where((d) => d).length}/7',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tc.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) => _buildDay(isGlass, tc, accent, i)),
          ),
        ],
      ),
    );
  }

  Widget _buildDay(bool isGlass, AppTextThemeColors tc, Color accent, int index) {
    final isCompleted = index < completedDays.length && completedDays[index];
    final isToday = index == todayIndex;

    return Column(
      children: [
        Text(_weekLabels[index],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isToday ? accent : tc.tertiary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCompleted ? AppGradients.success : null,
            color: isCompleted
                ? null
                : (isToday
                    ? (isGlass ? Colors.white.withOpacity(0.12) : AppColors.brandPrimaryPale)
                    : (isGlass ? Colors.white.withOpacity(0.06) : const Color(0xFFF2F2F7))),
            border: isToday && !isCompleted
                ? Border.all(color: accent, width: 2.5)
                : isCompleted
                    ? null
                    : Border.all(
                        color: isGlass ? Colors.white.withOpacity(0.15) : AppColors.border,
                        width: 1.5,
                      ),
            boxShadow: (isCompleted && !isGlass)
                ? [BoxShadow(color: AppColors.successDark, offset: const Offset(0, 3), blurRadius: 0)]
                : null,
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : isToday
                  ? Text('${todayIndex + 1}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
        ),
      ],
    );
  }
}
