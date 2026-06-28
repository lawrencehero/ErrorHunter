/// 错题猎手 - Report Repository Mock 实现
/// 使用 MockReportDataSource 提供数据，后端就绪后替换为 Remote 实现
library;

import '../../domain/repositories/report_repository.dart';
import '../../features/report/models/weekly_report_model.dart';
import '../../features/report/models/dashboard_model.dart';
import '../mock/mock_report_data_source.dart';

/// Report Repository 的 Mock 实现
class ReportRepositoryMock implements ReportRepository {
  ReportRepositoryMock({MockReportDataSource? dataSource})
      : _dataSource = dataSource ?? MockReportDataSource();

  final MockReportDataSource _dataSource;

  @override
  Future<DashboardData> getDashboard() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return DashboardData(
      nickname: '小明',
      streakDays: 12,
      pendingReviewCount: 8,
      totalQuestions: 156,
      masteredCount: 98,
      eliminationRate: 62.8,
      // 本周打卡假数据：周一~周几按"今天"动态生成。
      // 今天之前假设已复习（true），今天尚未复习（false），未来天必为 false。
      // 与 home_page._buildWeekCard / WeeklyCalendar 的"周一为索引0"约定一致。
      weeklyCompleted: _mockWeeklyCompleted(),
    );
  }

  /// 生成 mock 本周打卡（周一为索引 0）。今天尚未复习 → false。
  List<bool> _mockWeeklyCompleted() {
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    return List.generate(7, (i) {
      if (i >= today) return false; // 今天及之后未打卡
      return true; // 过去几天假设已复习
    });
  }

  @override
  Future<List<WeeklySummary>> getWeeklySummaries() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _dataSource.getWeeklySummaries();
  }

  @override
  Future<WeeklyReportModel> getWeeklyReportDetail(String reportId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _dataSource.getWeeklyReportDetail(reportId);
  }
}
