/// 错题猎手 - 复习历史时间线组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import '../models/question_model.dart';

// 时间线条目内文本统一用 forceStrutHeight 锁定行高，使 IntrinsicHeight 的
// intrinsic 估算与运行时一致——否则真实字体（如 Chrome 的 Roboto）下文本实际
// 行高会比 intrinsic 多约 1px/行，两条文本叠加导致内容 Column 溢出 2px。
const _captionStrut = StrutStyle(fontSize: 14, height: 1.5, forceStrutHeight: true);
const _dateStrut = StrutStyle(fontSize: 11, height: 1.5, forceStrutHeight: true);

/// 复习历史时间线
///
/// [totalReviewCount] 为该错题累计复习次数（后端 review_count，含未返回的旧记录）。
/// 传入时用于计算每条记录的全局序号与标题处的总轮次；为 0（mock/旧缓存）时回退为
/// 当前记录条数。
class ReviewHistoryTimeline extends StatelessWidget {
  const ReviewHistoryTimeline({
    super.key,
    required this.records,
    this.totalReviewCount = 0,
  });

  final List<ReviewRecord> records;
  final int totalReviewCount;

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

    // 复习序号按时间顺序自增（1,2,3…），与艾宾浩斯轮次（FAILED 会重置回 1）解耦，
    // 避免出现多条"第1轮复习"。后端返回的记录可能为倒序（reviewed_at DESC）或
    // 顺序（mock），这里按 reviewed_at 升序定位，保证序号与发生先后一致。
    // 当总次数大于返回条数（详情接口限 20 条）时，最旧可见记录的序号补上偏移，
    // 使最新一条序号 = 总次数。
    final visibleCount = records.length;
    final totalCount = totalReviewCount > 0 ? totalReviewCount : visibleCount;
    final offset = totalCount > visibleCount ? totalCount - visibleCount : 0;

    // 按复习时间升序的稳定排序，记录原索引 → 全局序号映射。
    final sorted = records.asMap().entries.toList()
      ..sort((a, b) {
        final cmp = a.value.reviewDate.compareTo(b.value.reviewDate);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    final attemptByIndex = <int, int>{};
    for (var pos = 0; pos < sorted.length; pos++) {
      // pos=0 是最早的可见记录 → 序号 = offset + 1。
      attemptByIndex[sorted[pos].key] = offset + pos + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题"复习历史"与"共 N 轮"由详情页可折叠区块的标题行统一展示，
        // 展开后这里只渲染各轮次记录，避免重复标题。
        ...records.asMap().entries.map((entry) {
          final index = entry.key;
          final record = entry.value;
          final isLast = index == records.length - 1;
          return _TimelineItem(
            record: record,
            attemptNumber: attemptByIndex[index] ?? (index + 1),
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
    required this.attemptNumber,
    required this.isLast,
  });

  final ReviewRecord record;

  /// 该次复习的全局序号（按时间顺序自增，不受是否掌握影响）。
  final int attemptNumber;
  final bool isLast;

  Color _resultColor(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    // 后端 SelfRating 枚举：MASTERED / PARTIAL / FAILED（主路径）。
    // 兼容旧值 CORRECT/WRONG/PARTIAL 以防本地缓存残留的旧记录。
    switch (record.result) {
      case 'MASTERED':
      case 'CORRECT':
        return isGlass ? const Color(0xFF81C784) : AppColors.success;
      case 'FAILED':
      case 'WRONG':
        return isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
      case 'PARTIAL':
        return isGlass ? const Color(0xFFFFB74D) : AppColors.warning;
      default:
        return context.textColors.tertiary;
    }
  }

  String get _resultLabel {
    // 后端 SelfRating 枚举：MASTERED / PARTIAL / FAILED（主路径）。
    // 兼容旧值 CORRECT/WRONG/PARTIAL 以防本地缓存残留的旧记录。
    switch (record.result) {
      case 'MASTERED':
      case 'CORRECT':
        return '✓ 掌握';
      case 'FAILED':
      case 'WRONG':
        return '✗ 不会';
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '第$attemptNumber轮复习',
                        strutStyle: _captionStrut,
                        style: AppTypography.primary.caption.copyWith(
                          color: tc.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDate(record.reviewDate),
                        strutStyle: _dateStrut,
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
                    strutStyle: _captionStrut,
                    style: AppTypography.primary.caption.copyWith(
                      color: resultColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (record.note != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      record.note!,
                      strutStyle: _captionStrut,
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
    // 后端 reviewed_at 带时区偏移（如 +08:00），DateTime.parse 会得到 isUtc=true
    // 的 DateTime，直接取 .hour 等字段是 UTC 值。这里先转本地时区再格式化，
    // 避免复习历史显示成 UTC 时间。
    final local = date.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
