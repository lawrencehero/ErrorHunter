/// 错题猎手 - 复习进度条组件
/// 渐变色微型进度条，进度 = 消灭计数 / 3，与消灭状态一致
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/icons/eliminated_check_icon.dart';

/// 复习进度条
///
/// 进度语义：masterCount / 3（消灭阈值）。mc=3 即已消灭 → 100%。
/// 与 status（已消灭）一致；不再用 round/total（原实现下已消灭题显示 80%、新题 20%）。
class ReviewProgressBar extends StatelessWidget {
  const ReviewProgressBar({
    super.key,
    required this.masterCount,
    this.isEliminated = false,
    this.height = 4.0,
    this.showLabel = true,
    this.nextReviewDate,
  });

  /// 消灭计数（master_count，0-3）。
  final int masterCount;

  /// 是否已消灭（status=MASTERED/PERMANENTLY_MASTERED）。已消灭强制 100%。
  final bool isEliminated;

  final double height;
  final bool showLabel;

  /// 下次复习日期（后端 next_review_date）。非空且未消灭时在进度条下方展示
  /// "下次复习 M月D日"。已消灭题不展示（其下次复习语义为复活检测，另处展示）。
  final DateTime? nextReviewDate;

  /// 消灭阈值（与 QuestionModel.masteryThreshold 一致）。
  static const int masteryThreshold = 3;

  double get _progress =>
      isEliminated ? 1.0 : (masterCount / masteryThreshold).clamp(0.0, 1.0);

  /// 零值 time.Time{}（0001-01-01）视为无有效日期。
  bool get _hasNextReviewDate =>
      nextReviewDate != null && nextReviewDate!.year > 2000;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '复习进度',
                style: AppTypography.primary.caption.copyWith(
                  color: tc.secondary,
                ),
              ),
              isEliminated
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '已消灭',
                          style: AppTypography.primary.caption.copyWith(
                            color: isGlass
                                ? const Color(0xFF81C784)
                                : AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        EliminatedCheckIcon(size: 14, isGlass: isGlass),
                      ],
                    )
                  : Text(
                      '已掌握 $masterCount/$masteryThreshold',
                      style: AppTypography.primary.caption.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: height,
            backgroundColor: isGlass
                ? Colors.white.withOpacity(0.15)
                : AppColors.border.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
                _gradientColor(isGlass: isGlass)),
          ),
        ),
        if (!isEliminated && _hasNextReviewDate) ...[
          SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: tc.tertiary,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                // next_review_date 是日期（后端 date 类型，序列化为 UTC 午夜），
                // 语义为"哪天复习"，按月/日取值，不做时区转换。
                '下次复习 ${nextReviewDate!.month}月${nextReviewDate!.day}日',
                style: AppTypography.primary.caption.copyWith(
                  color: tc.tertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _gradientColor({required bool isGlass}) {
    if (_progress >= 1.0) {
      return isGlass ? const Color(0xFF81C784) : AppColors.success;
    }
    if (_progress >= 0.6) {
      return isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    }
    if (_progress >= 0.3) {
      return isGlass ? const Color(0xFFFFB74D) : AppColors.warning;
    }
    return isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
  }
}
