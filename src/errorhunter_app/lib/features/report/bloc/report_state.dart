/// 错题猎手 - Report Bloc States
library;

import 'package:equatable/equatable.dart';
import '../models/weekly_report_model.dart';
import '../models/dashboard_model.dart';

/// Report State 基类
sealed class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class ReportInitial extends ReportState {
  const ReportInitial();
}

/// 加载中
class ReportLoading extends ReportState {
  const ReportLoading();
}

/// Dashboard 加载完成
class DashboardLoaded extends ReportState {
  const DashboardLoaded(this.dashboard);

  final DashboardData dashboard;

  @override
  List<Object?> get props => [dashboard];
}

/// 周报列表加载完成
class WeeklyReportsLoaded extends ReportState {
  const WeeklyReportsLoaded(this.reports);

  final List<WeeklySummary> reports;

  @override
  List<Object?> get props => [reports];
}

/// 周报详情加载完成
class WeeklyReportDetailLoaded extends ReportState {
  const WeeklyReportDetailLoaded(this.report);

  final WeeklyReportModel report;

  @override
  List<Object?> get props => [report];
}

/// 加载失败
class ReportError extends ReportState {
  const ReportError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
