/// 错题猎手 - 复习历史时间线组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import '../models/question_model.dart';

/// 复习历史时间线
class ReviewHistoryTimeline extends StatelessWidget {
  const ReviewHistoryTimeline({
    super.key,
    required this.records,
  });

  final List<ReviewRecord> records;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          '暂无复习记录',
          style: AppTypography.primary.caption.copyWith(
            color: tc.tertiary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '复习历史',
          style: AppTypography.primary.h3.copyWith(
            color: tc.primary,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        ...records.asMap().entries.map((entry) {
          final index = entry.key;
          final record = entry.value;
          final isLast = index == records.length - 1;
          return _TimelineItem(
            record: record,
            isLast: isLast,
          );
        }),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.record,
    required this.isLast,
  });

  final ReviewRecord record;
  final bool isLast;

  Color _resultColor(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    switch (record.result) {
      case 'CORRECT':
        return isGlass ? const Color(0xFF81C784) : AppColors.success;
      case 'WRONG':
        return isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
      case 'PARTIAL':
        return isGlass ? const Color(0xFFFFB74D) : AppColors.warning;
      default:
        return context.textColors.tertiary;
    }
  }

  String get _resultLabel {
    switch (record.result) {
      case 'CORRECT':
        return '✓ 正确';
      case 'WRONG':
        return '✗ 错误';
      case 'PARTIAL':
        return '△ 部分记得';
      default:
        return record.result;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final resultColor = _resultColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: resultColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isGlass
                          ? Colors.white.withOpacity(0.15)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '第${record.reviewRound}轮复习',
                        style: AppTypography.primary.caption.copyWith(
                          color: tc.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDate(record.reviewDate),
                        style: AppTypography.primary.caption.copyWith(
                          color: tc.tertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    _resultLabel,
                    style: AppTypography.primary.caption.copyWith(
                      color: resultColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (record.note != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      record.note!,
                      style: AppTypography.primary.caption.copyWith(
                        color: tc.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
