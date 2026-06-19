/// 错题猎手 - Report Repository Mock 实现
/// 使用 MockReportDataSource 提供数据，后端就绪后替换为 Remote 实现
library;

import '../../domain/repositories/report_repository.dart';
import '../../features/report/models/weekly_report_model.dart';
import '../mock/mock_report_data_source.dart';

/// Report Repository 的 Mock 实现
class ReportRepositoryMock implements ReportRepository {
  ReportRepositoryMock({MockReportDataSource? dataSource})
      : _dataSource = dataSource ?? MockReportDataSource();

  final MockReportDataSource _dataSource;

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
