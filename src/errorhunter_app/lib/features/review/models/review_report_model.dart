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
    required this.durationSeconds,
    this.durationMinutes = 0,
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

  /// 复习用时（秒）。精确到秒，避免分钟截断导致短复习显示"0 分钟"。
  final int durationSeconds;

  /// 复习用时（分钟，向下取整）。保留用于向后兼容/旧展示；新展示用
  /// [formattedDuration]（基于 [durationSeconds]）。
  final int durationMinutes;

  /// 连续打卡天数
  final int streakDays;

  /// 本轮消灭数量
  final int eliminatedCount;

  /// 友好的用时文案：< 60 秒显示"X 秒"，否则显示"X 分钟"（向下取整）。
  /// 复习结束弹窗用客户端会话秒数，首页"查看复习"用后端汇总秒数，统一走此处。
  String get formattedDuration {
    if (durationSeconds < 60) return '$durationSeconds 秒';
    return '${durationSeconds ~/ 60} 分钟';
  }

  @override
  List<Object?> get props => [
        totalCount,
        masteredCount,
        partialCount,
        forgotCount,
        durationSeconds,
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
      durationSeconds: 0,
      durationMinutes: 0,
      streakDays: 0,
      eliminatedCount: 0,
    );
  }

  /// 由后端今日复习汇总（GET /v1/reviews/today-summary）构造。
  /// 今日未复习时各项为 0，等价于 empty；今日复习过则展示真实结果数据。
  /// failed_count 映射到 forgotCount（"完全不会"）。
  /// 用时优先取 duration_seconds（精确）；旧后端未返回时回退 duration_minutes*60。
  factory ReviewReportModel.fromTodaySummary(Map<String, dynamic> json) {
    final minutes = (json['duration_minutes'] as num?)?.toInt() ?? 0;
    return ReviewReportModel(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      masteredCount: (json['mastered_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      forgotCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      durationSeconds:
          (json['duration_seconds'] as num?)?.toInt() ?? minutes * 60,
      durationMinutes: minutes,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      eliminatedCount: (json['eliminated_count'] as num?)?.toInt() ?? 0,
    );
  }
}
