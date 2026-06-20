/// 错题猎手 - Report Repository 真实实现
/// 调用 ReportRemoteDataSource 对接后端 API
library;

import '../../domain/repositories/report_repository.dart';
import '../../features/report/models/weekly_report_model.dart';
import '../remote/report_remote_data_source.dart';

/// Report Repository 的真实实现
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({required ReportRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final ReportRemoteDataSource _dataSource;

  @override
  Future<List<WeeklySummary>> getWeeklySummaries() =>
      _dataSource.getWeeklySummaries();

  @override
  Future<WeeklyReportModel> getWeeklyReportDetail(String reportId) =>
      _dataSource.getWeeklyReportDetail(reportId);
}
