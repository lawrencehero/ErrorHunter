/// 错题猎手 - Dashboard 数据模型
library;

import 'package:equatable/equatable.dart';

/// Dashboard 概览数据
class DashboardData extends Equatable {
  const DashboardData({
    required this.nickname,
    required this.streakDays,
    required this.pendingReviewCount,
    required this.totalQuestions,
    required this.masteredCount,
    required this.eliminationRate,
    this.weakKnowledge = const [],
    this.weeklyCompleted = const [],
  });

  final String nickname;
  final int streakDays;
  final int pendingReviewCount;
  final int totalQuestions;
  final int masteredCount;
  final double eliminationRate; // 0-100
  final List<WeakKnowledgeItem> weakKnowledge;
  final List<bool> weeklyCompleted; // 本周一到周日是否打卡

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final greeting = json['greeting'] as Map<String, dynamic>? ?? {};
    final todayTask = json['today_task'] as Map<String, dynamic>? ?? {};
    final statistics = json['statistics'] as Map<String, dynamic>? ?? {};
    final weakKp = json['weak_knowledge_top'] as List<dynamic>? ?? [];
    final weeklyRaw = json['weekly_completed'] as List<dynamic>? ?? [];

    return DashboardData(
      nickname: greeting['nickname'] as String? ?? '同学',
      streakDays: greeting['streak_days'] as int? ?? 0,
      pendingReviewCount: todayTask['pending_review_count'] as int? ?? 0,
      totalQuestions: statistics['total_questions'] as int? ?? 0,
      masteredCount: statistics['mastered_count'] as int? ?? 0,
      eliminationRate: (statistics['elimination_rate'] as num?)?.toDouble() ?? 0.0,
      weakKnowledge: weakKp.map((item) {
        final map = item as Map<String, dynamic>;
        final rawId = map['id'];
        return WeakKnowledgeItem(
          id: rawId is int ? rawId.toString() : rawId as String?,
          name: map['name'] as String? ?? '',
          count: map['count'] as int? ?? 0,
        );
      }).toList(),
      weeklyCompleted: weeklyRaw.map((v) => v == true).toList(),
    );
  }

  /// 空数据（新用户）
  factory DashboardData.empty() => const DashboardData(
    nickname: '同学',
    streakDays: 0,
    pendingReviewCount: 0,
    totalQuestions: 0,
    masteredCount: 0,
    eliminationRate: 0.0,
  );

  @override
  List<Object?> get props => [
    nickname, streakDays, pendingReviewCount,
    totalQuestions, masteredCount, eliminationRate,
  ];
}

/// 薄弱知识点项
class WeakKnowledgeItem extends Equatable {
  const WeakKnowledgeItem({this.id, required this.name, required this.count});

  final String? id;
  final String name;
  final int count;

  @override
  List<Object?> get props => [id, name, count];
}
