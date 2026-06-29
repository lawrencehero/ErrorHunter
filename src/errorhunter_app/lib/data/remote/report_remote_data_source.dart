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
  ///
  /// 后端 `/reports/weekly` 默认 page_size=10、上限 20。周报每周一条，
  /// 默认 10 条只覆盖约 2.5 个月历史，老用户会丢失更早周报。
  /// 这里显式请求 page_size=20（后端上限），覆盖约 5 个月，零 UI 改动。
  /// 完整分页（滚动加载更多）见 TODO。
  Future<List<WeeklySummary>> getWeeklySummaries() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.weeklyReports,
      queryParameters: const {'page': 1, 'page_size': 20},
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? [];

    return items.map((item) {
      final map = item as Map<String, dynamic>;
      return WeeklySummary(
        id: (map['id'] ?? 0).toString(),
        weekNumber: map['week_number'] as int? ?? 0,
        // 后端 WeekStart/WeekEnd 是 DATE 列，但 Go time.Time JSON 序列化带时间
        // （上海 00:00 → UTC 前一天 16:00）。Flutter DateTime.parse 对带 Z 的
        // 字符串返回 UTC DateTime，直接取 .day 会偏移一天（显示 6/21 而非 6/22）。
        // 统一 toLocal 还原到用户本地时区后再展示。
        startDate: DateTime.parse(map['week_start'] as String).toLocal(),
        endDate: DateTime.parse(map['week_end'] as String).toLocal(),
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

    // 解析逻辑抽到 WeeklyReportModel.fromDetailJson，便于单测覆盖。
    return WeeklyReportModel.fromDetailJson(data, reportId: reportId);
  }
}
