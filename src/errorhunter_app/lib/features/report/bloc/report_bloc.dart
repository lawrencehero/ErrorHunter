/// 错题猎手 - Report Bloc
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/weekly_report_model.dart';
import 'report_event.dart';
import 'report_state.dart';

/// 周报 BLoC
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc() : super(const ReportInitial()) {
    on<LoadWeeklyReports>(_onLoadWeeklyReports);
    on<LoadWeeklyReportDetail>(_onLoadWeeklyReportDetail);
  }

  Future<void> _onLoadWeeklyReports(
    LoadWeeklyReports event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading());

    // TODO: 替换为真实API调用
    await Future.delayed(const Duration(milliseconds: 600));

    final now = DateTime.now();
    final reports = List.generate(8, (i) {
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

    emit(WeeklyReportsLoaded(reports));
  }

  Future<void> _onLoadWeeklyReportDetail(
    LoadWeeklyReportDetail event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading());

    // TODO: 替换为真实API调用
    await Future.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();
    final summary = WeeklySummary(
      id: event.reportId,
      weekNumber: 24,
      startDate: now.subtract(const Duration(days: 6)),
      endDate: now,
      newCount: 15,
      eliminatedCount: 12,
      reviewCount: 42,
    );

    emit(WeeklyReportDetailLoaded(
      WeeklyReportModel.mock(summary: summary),
    ));
  }
}
