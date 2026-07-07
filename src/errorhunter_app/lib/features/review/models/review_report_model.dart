/// 错题猎手 - 复习报告模型
library;

import 'package:equatable/equatable.dart';

/// 自评结果枚举
enum SelfEvalRating {
  mastered('MASTERED', '完全掌握', '😄', '🟢'),
  partial('PARTIAL', '部分记得', '🤔', '🟡'),
  forgot('FORGOT', '完全不会', '😵', '🔴'),
  remembered('REMEMBERED', '还记得', '😊', '🟢'),
  forgotten('FORGOTTEN', '忘记了', '😅', '🔴');

  const SelfEvalRating(this.code, this.label, this.emoji, this.colorTag);

  final String code;
  final String label;
  final String emoji;
  final String colorTag;

  static SelfEvalRating fromCode(String code) {
    return SelfEvalRating.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SelfEvalRating.forgot,
    );
  }
}

/// 复习报告数据模型
class ReviewReportModel extends Equatable {
  const ReviewReportModel({
    required this.totalCount,
    required this.masteredCount,
    required this.partialCount,
    required this.forgotCount,
    required this.durationMinutes,
    required this.streakDays,
    required this.eliminatedCount,
  });

  /// 今日复习总数
  final int totalCount;

  /// 完全掌握数量
  final int masteredCount;

  /// 部分记得数量
  final int partialCount;

  /// 完全不会数量
  final int forgotCount;

  /// 复习用时（分钟）
  final int durationMinutes;

  /// 连续打卡天数
  final int streakDays;

  /// 本轮消灭数量
  final int eliminatedCount;

  @override
  List<Object?> get props => [
        totalCount,
        masteredCount,
        partialCount,
        forgotCount,
        durationMinutes,
        streakDays,
        eliminatedCount,
      ];

  factory ReviewReportModel.empty() {
    return const ReviewReportModel(
      totalCount: 0,
      masteredCount: 0,
      partialCount: 0,
      forgotCount: 0,
      durationMinutes: 0,
      streakDays: 0,
      eliminatedCount: 0,
    );
  }

  /// 由后端今日复习汇总（GET /v1/reviews/today-summary）构造。
  /// 今日未复习时各项为 0，等价于 empty；今日复习过则展示真实结果数据。
  /// failed_count 映射到 forgotCount（"完全不会"）。
  factory ReviewReportModel.fromTodaySummary(Map<String, dynamic> json) {
    return ReviewReportModel(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      masteredCount: (json['mastered_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      forgotCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      eliminatedCount: (json['eliminated_count'] as num?)?.toInt() ?? 0,
    );
  }
}
