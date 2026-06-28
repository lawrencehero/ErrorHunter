/// 错题猎手 - Report Repository 抽象接口
/// 定义周报相关的数据访问契约
library;

import '../../features/report/models/weekly_report_model.dart';
import '../../features/report/models/dashboard_model.dart';

/// 周报仓库抽象
abstract class ReportRepository {
  /// 获取 Dashboard 概览数据
  Future<DashboardData> getDashboard();

  /// 获取周报列表
  Future<List<WeeklySummary>> getWeeklySummaries();

  /// 获取周报详情
  Future<WeeklyReportModel> getWeeklyReportDetail(String reportId);
}
