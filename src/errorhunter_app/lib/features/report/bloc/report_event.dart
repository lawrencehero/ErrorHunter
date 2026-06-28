/// 错题猎手 - Report Bloc Events
library;

import 'package:equatable/equatable.dart';

/// Report Event 基类
sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

/// 加载 Dashboard 概览
class LoadDashboard extends ReportEvent {
  const LoadDashboard();
}

/// 加载周报列表
class LoadWeeklyReports extends ReportEvent {
  const LoadWeeklyReports();
}

/// 加载周报详情
class LoadWeeklyReportDetail extends ReportEvent {
  const LoadWeeklyReportDetail(this.reportId);

  final String reportId;

  @override
  List<Object?> get props => [reportId];
}
