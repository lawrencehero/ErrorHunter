/// 错题猎手 - 本周打卡日历 V3.0 (游戏化)
/// 渐变完成圆点 + 3D底影 + chunky卡片
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

class WeeklyCalendar extends StatelessWidget {
  const WeeklyCalendar({super.key, required this.completedDays, this.todayIndex = 0});
  final List<bool> completedDays;
  final int todayIndex;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
                decoration: const BoxDecoration(color: AppColors.brandPrimaryPale, shape: BoxShape.circle),
                child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 8),
              Text('本周打卡',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text('${completedDays.where((d) => d).length}/7',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) => _buildDay(i)),
          ),
        ],
      ),
    );
  }

  Widget _buildDay(int index) {
    final isCompleted = index < completedDays.length && completedDays[index];
    final isToday = index == todayIndex;

    return Column(
      children: [
        Text(_weekLabels[index],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isToday ? AppColors.brandPrimary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCompleted ? AppGradients.success : null,
            color: isCompleted ? null : (isToday ? AppColors.brandPrimaryPale : const Color(0xFFF2F2F7)),
            border: isToday && !isCompleted
                ? Border.all(color: AppColors.brandPrimary, width: 2.5)
                : isCompleted ? null : Border.all(color: AppColors.border, width: 1.5),
            boxShadow: isCompleted
                ? [BoxShadow(color: AppColors.successDark, offset: const Offset(0, 3), blurRadius: 0)]
                : null,
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : isToday
                  ? Text('${todayIndex + 1}',
                      style: const TextStyle(
                        color: AppColors.brandPrimary,
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
