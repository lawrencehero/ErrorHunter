/// 错题猎手 - Report Bloc
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/report_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

/// 周报 BLoC
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository _reportRepository;

  ReportBloc(this._reportRepository) : super(const ReportInitial()) {
    on<LoadWeeklyReports>(_onLoadWeeklyReports);
    on<LoadWeeklyReportDetail>(_onLoadWeeklyReportDetail);
  }

  Future<void> _onLoadWeeklyReports(
    LoadWeeklyReports event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading());

    final reports = await _reportRepository.getWeeklySummaries();
    emit(WeeklyReportsLoaded(reports));
  }

  Future<void> _onLoadWeeklyReportDetail(
    LoadWeeklyReportDetail event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading());

    final report =
        await _reportRepository.getWeeklyReportDetail(event.reportId);
    emit(WeeklyReportDetailLoaded(report));
  }
}
