/// 错题猎手 - Report Remote Data Source
/// 调用后端周报 API，替代 MockReportDataSource
library;

import '../../features/report/models/weekly_report_model.dart';
import '../../features/report/models/dashboard_model.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// Report 远程数据源 — 对接后端 /v1/reports/* 接口
class ReportRemoteDataSource {
  ReportRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 获取 Dashboard 概览数据
  Future<DashboardData> getDashboard() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.reports,
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) return DashboardData.empty();
    return DashboardData.fromJson(data);
  }

  /// 获取周报列表
  Future<List<WeeklySummary>> getWeeklySummaries() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.weeklyReports,
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? [];

    return items.map((item) {
      final map = item as Map<String, dynamic>;
      return WeeklySummary(
        id: (map['id'] ?? 0).toString(),
        weekNumber: map['week_number'] as int? ?? 0,
        startDate: DateTime.parse(map['week_start'] as String),
        endDate: DateTime.parse(map['week_end'] as String),
        newCount: map['new_questions'] as int? ?? 0,
        eliminatedCount: map['mastered_questions'] as int? ?? 0,
        reviewCount: map['review_count'] as int? ?? 0,
      );
    }).toList();
  }

  /// 获取周报详情
  Future<WeeklyReportModel> getWeeklyReportDetail(String reportId) async {
    final endpoint =
        ApiEndpoints.withId(ApiEndpoints.weeklyReportDetail, reportId);
    final response = await _client.get<Map<String, dynamic>>(endpoint);

    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Weekly report not found');
    }

    // 构造 summary
    final summary = WeeklySummary(
      id: reportId,
      weekNumber: data['week_number'] as int? ?? 0,
      startDate: DateTime.parse(data['week_start'] as String),
      endDate: DateTime.parse(data['week_end'] as String),
      newCount: data['new_questions'] as int? ?? 0,
      eliminatedCount: data['mastered_questions'] as int? ?? 0,
      reviewCount: data['review_count'] as int? ?? 0,
    );

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
      reviewCountVsLastWeek: 0, // TODO: 后端待补充 prev_week_review_count 字段，当前暂用 0 占位
      accuracyRate: (data['review_accuracy'] as num?)?.toDouble() ?? 0.0,
      accuracyRateVsLastWeek: 0.0, // TODO: 后端待补充 prev_week_accuracy 字段，当前暂用 0.0 占位
      achievements: const [], // TODO: 后端待补充 achievements 列表接口，当前返回空数组
      topKnowledgePoints: _parseTopKnowledge(data['weak_knowledge_top']),
      mostFrequentErrorCategory:
          data['top_error_category'] as String? ?? 'UNKNOWN',
      mostFrequentErrorPercentage:
          (data['top_error_category_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 计算与上周的差值
  int _calcDelta(int current, int? previous) {
    if (previous == null) return 0;
    return current - previous;
  }

  /// 解析 Top 知识点
  List<KnowledgeRankItem> _parseTopKnowledge(dynamic rawData) {
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
