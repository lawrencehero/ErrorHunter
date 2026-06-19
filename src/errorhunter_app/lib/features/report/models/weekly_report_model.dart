/// 错题猎手 - 周报数据模型
library;

import 'package:equatable/equatable.dart';

/// 周统计摘要（用于列表页）
class WeeklySummary extends Equatable {
  const WeeklySummary({
    required this.id,
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.newCount,
    required this.eliminatedCount,
    required this.reviewCount,
  });

  final String id;
  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final int newCount;
  final int eliminatedCount;
  final int reviewCount;

  @override
  List<Object?> get props => [id, weekNumber];
}

/// 成就项
class AchievementItem extends Equatable {
  const AchievementItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final String icon;
  final String title;
  final String description;

  @override
  List<Object?> get props => [title];
}

/// 知识点排名
class KnowledgeRankItem extends Equatable {
  const KnowledgeRankItem({
    required this.name,
    required this.errorCount,
    required this.rank,
  });

  final String name;
  final int errorCount;
  final int rank;

  @override
  List<Object?> get props => [name, rank];
}

/// 周报详情模型
class WeeklyReportModel extends Equatable {
  const WeeklyReportModel({
    required this.summary,
    required this.newCountVsLastWeek,
    required this.eliminatedCountVsLastWeek,
    required this.reviewCountVsLastWeek,
    required this.accuracyRate,
    required this.accuracyRateVsLastWeek,
    required this.achievements,
    required this.topKnowledgePoints,
    required this.mostFrequentErrorCategory,
    required this.mostFrequentErrorPercentage,
  });

  final WeeklySummary summary;

  /// 新增错题 vs 上周变化
  final int newCountVsLastWeek;

  /// 消灭错题 vs 上周变化
  final int eliminatedCountVsLastWeek;

  /// 复习次数 vs 上周变化
  final int reviewCountVsLastWeek;

  /// 正确率 (0-100)
  final double accuracyRate;

  /// 正确率 vs 上周变化
  final double accuracyRateVsLastWeek;

  /// 本周成就
  final List<AchievementItem> achievements;

  /// Top3 知识点
  final List<KnowledgeRankItem> topKnowledgePoints;

  /// 最多错因分类代码
  final String mostFrequentErrorCategory;

  /// 最多错因占比
  final double mostFrequentErrorPercentage;

  @override
  List<Object?> get props => [summary];

  factory WeeklyReportModel.mock({required WeeklySummary summary}) {
    return WeeklyReportModel(
      summary: summary,
      newCountVsLastWeek: 3,
      eliminatedCountVsLastWeek: 5,
      reviewCountVsLastWeek: -2,
      accuracyRate: 78.5,
      accuracyRateVsLastWeek: 4.2,
      achievements: const [
        AchievementItem(
          icon: '🔥',
          title: '连续打卡7天',
          description: '坚持就是胜利！',
        ),
        AchievementItem(
          icon: '🎯',
          title: '消灭10道题',
          description: '精准打击，效率惊人',
        ),
        AchievementItem(
          icon: '⭐',
          title: '正确率突破75%',
          description: '知识掌握稳步提升',
        ),
      ],
      topKnowledgePoints: const [
        KnowledgeRankItem(name: '分数运算', errorCount: 8, rank: 1),
        KnowledgeRankItem(name: '几何面积', errorCount: 5, rank: 2),
        KnowledgeRankItem(name: '小数乘法', errorCount: 3, rank: 3),
      ],
      mostFrequentErrorCategory: 'KNOWLEDGE',
      mostFrequentErrorPercentage: 42.5,
    );
  }
}
