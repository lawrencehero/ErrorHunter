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

  /// 该周报对应的 ISO 周序号（1-53）。
  ///
  /// 后端 `week_number` 实际是 `isoYear*100+isoWeek`（如 202626），
  /// 不能直接当成「第 N 周」展示，否则会出现「第 202626 周」。
  /// 这里从 `weekStart` 本地计算 ISO 周序，与后端生成逻辑一致，
  /// 跨年周（如 12-29 属于下一年的第 1 周）也能正确显示。
  int get isoWeekNumber => _isoWeekNumber(startDate);

  /// 周报标题，如「第 26 周周报」。
  String get title => '第$isoWeekNumber周周报';

  /// ISO 8601 周序计算。
  /// 算法：取当前周四所在年的 ISO 周序（周四决定 ISO 年）。
  static int _isoWeekNumber(DateTime date) {
    // 本周周四（ISO 周由周四所在年/周决定）：(4 - weekday) % 7，Dart % 对负数返回非负。
    final thursday = date.add(Duration(days: (4 - date.weekday) % 7));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstMonday =
        firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
    return ((thursday.difference(firstMonday).inDays) ~/ 7) + 1;
  }
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

  /// 最多错因分类代码；本周无新增错题时为 null（后端字段 omitempty 不返回）。
  final String? mostFrequentErrorCategory;

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

  /// 从后端 `/reports/weekly/:id` 响应体（已脱去外层 `data` 包装）构造详情模型。
  ///
  /// 抽成静态方法便于单测覆盖字段映射。注意：
  /// - `week_start`/`week_end` 是 DATE 列，Go time.Time JSON 序列化带时区
  ///   （上海 00:00 → UTC 前一天 16:00），需 `toLocal()` 还原后再展示日期。
  /// - `top_error_category` 为 `*ErrorCategory` + omitempty，本周无新增错题时
  ///   不返回，这里保持 null（不再回退 'UNKNOWN'）。
  /// - `prev_week_new`/`prev_week_mastered`/`prev_week_review_count` 为 `*int` +
  ///   omitempty，首周无上周周报时不返回，delta 记 0（UI 显示「持平 vs 上周」）。
  /// - `prev_week_accuracy` 为 `*float64` + omitempty，首周不返回，delta 记 0.0。
  /// - `achievements` 为 JSONB `[]string`，后端缺省返回 `[]`；每条文案映射为一个
  ///   [AchievementItem]，icon 按文案关键词选取（未命中则统一 ✨）。
  factory WeeklyReportModel.fromDetailJson(
    Map<String, dynamic> data, {
    required String reportId,
  }) {
    final summary = WeeklySummary(
      id: reportId,
      weekNumber: data['week_number'] as int? ?? 0,
      startDate: DateTime.parse(data['week_start'] as String).toLocal(),
      endDate: DateTime.parse(data['week_end'] as String).toLocal(),
      newCount: data['new_questions'] as int? ?? 0,
      eliminatedCount: data['mastered_questions'] as int? ?? 0,
      reviewCount: data['review_count'] as int? ?? 0,
    );

    final accuracyRate = (data['review_accuracy'] as num?)?.toDouble() ?? 0.0;

    return WeeklyReportModel(
      summary: summary,
      newCountVsLastWeek: _calcDelta(
        data['new_questions'] as int? ?? 0,
        data['prev_week_new'] as int?,
      ),
      eliminatedCountVsLastWeek: _calcDelta(
        data['mastered_questions'] as int? ?? 0,
        data['prev_week_mastered'] as int?,
      ),
      reviewCountVsLastWeek: _calcDelta(
        data['review_count'] as int? ?? 0,
        data['prev_week_review_count'] as int?,
      ),
      accuracyRate: accuracyRate,
      accuracyRateVsLastWeek: _calcDeltaDouble(
        accuracyRate,
        (data['prev_week_accuracy'] as num?)?.toDouble(),
      ),
      achievements: _parseAchievements(data['achievements']),
      topKnowledgePoints: _parseTopKnowledge(data['weak_knowledge_top']),
      mostFrequentErrorCategory: data['top_error_category'] as String?,
      mostFrequentErrorPercentage:
          (data['top_error_category_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static int _calcDelta(int current, int? previous) {
    if (previous == null) return 0;
    return current - previous;
  }

  static double _calcDeltaDouble(double current, double? previous) {
    if (previous == null) return 0.0;
    // 保留 2 位小数，避免浮点尾巴（与后端 decimal(5,2) 精度对齐）
    final delta = current - previous;
    return double.parse(delta.toStringAsFixed(2));
  }

  /// 后端 achievements 为 JSONB `[]string`（如 `["连续打卡达人","消灭能手"]`）。
  /// 每条文案映射为 AchievementItem：title=文案，description 默认鼓励语，icon 按
  /// 文案关键词选取。空数组或缺失 → 空列表（详情页显示「本周暂无成就」）。
  static List<AchievementItem> _parseAchievements(dynamic rawData) {
    if (rawData == null) return const [];
    if (rawData is! List) return const [];

    return rawData
        .whereType<String>()
        .map((title) => AchievementItem(
              icon: _achievementIcon(title),
              title: title,
              description: _achievementDescription(title),
            ))
        .toList();
  }

  /// 按成就文案关键词选取 emoji 图标；未命中统一 ✨。
  static String _achievementIcon(String title) {
    if (title.contains('打卡') || title.contains('全勤')) return '🔥';
    if (title.contains('消灭')) return '🎯';
    if (title.contains('正确率')) return '⭐';
    if (title.contains('录入') || title.contains('勤勉')) return '📝';
    if (title.contains('复习')) return '📚';
    return '✨';
  }

  /// 按成就文案关键词给出鼓励性描述；未命中给通用鼓励语。
  static String _achievementDescription(String title) {
    if (title.contains('全勤')) return '一周七天全程坚持，超级自律';
    if (title.contains('打卡')) return '坚持复习，习惯养成中';
    if (title.contains('消灭')) return '精准打击，错题清零提速';
    if (title.contains('正确率')) return '知识掌握稳步提升';
    if (title.contains('录入') || title.contains('勤勉')) return '勤于收集错题，复习素材更充实';
    if (title.contains('复习')) return '复习频次充足，巩固到位';
    return '继续保持，稳步前进';
  }

  static List<KnowledgeRankItem> _parseTopKnowledge(dynamic rawData) {
    if (rawData == null) return [];
    if (rawData is! List) return [];

    return rawData.asMap().entries.map((entry) {
      final item = entry.value as Map<String, dynamic>;
      return KnowledgeRankItem(
        name: item['name'] as String? ?? '',
        errorCount: item['count'] as int? ?? 0,
        rank: entry.key + 1,
      );
    }).toList();
  }
}
