/// 错题猎手 - Report Mock 数据源
/// 提供周报的模拟数据，后端就绪后替换为 RemoteDataSource
library;

import '../../features/report/models/weekly_report_model.dart';

/// Report 模块的 Mock 数据源
class MockReportDataSource {
  /// 生成周报列表
  List<WeeklySummary> getWeeklySummaries() {
    final now = DateTime.now();
    return List.generate(8, (i) {
      final endDate = now.subtract(Duration(days: i * 7));
      final startDate = endDate.subtract(const Duration(days: 6));
      return WeeklySummary(
        id: 'week_${now.year}_${52 - i}',
        weekNumber: 52 - i,
        startDate: startDate,
        endDate: endDate,
        newCount: 12 + i * 2,
        eliminatedCount: 8 + i,
        reviewCount: 35 + i * 5,
      );
    });
  }

  /// 生成周报详情
  WeeklyReportModel getWeeklyReportDetail(String reportId) {
    final now = DateTime.now();
    final summary = WeeklySummary(
      id: reportId,
      weekNumber: 24,
      startDate: now.subtract(const Duration(days: 6)),
      endDate: now,
      newCount: 15,
      eliminatedCount: 12,
      reviewCount: 42,
    );
    return WeeklyReportModel.mock(summary: summary);
  }
}
