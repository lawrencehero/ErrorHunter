import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/domain/repositories/report_repository.dart';
import 'package:errorhunter_app/features/report/bloc/report_bloc.dart';
import 'package:errorhunter_app/features/report/bloc/report_event.dart';
import 'package:errorhunter_app/features/report/bloc/report_state.dart';
import 'package:errorhunter_app/features/report/models/dashboard_model.dart';
import 'package:errorhunter_app/features/report/models/weekly_report_model.dart';

class _MockRepo implements ReportRepository {
  @override
  Future<List<WeeklySummary>> getWeeklySummaries() async => [_s];
  @override
  Future<WeeklyReportModel> getWeeklyReportDetail(String id) async =>
      WeeklyReportModel.mock(summary: _s);
  @override
  Future<DashboardData> getDashboard() async => throw UnimplementedError();
}
final _s = WeeklySummary(id:'1', weekNumber:1, startDate:DateTime(2026,6,22), endDate:DateTime(2026,6,28), newCount:1, eliminatedCount:0, reviewCount:1);

void main() {
  test('bloc: LoadWeeklyReports -> WeeklyReportsLoaded', () async {
    final b = ReportBloc(_MockRepo());
    b.add(const LoadWeeklyReports());
    await b.stream.firstWhere((s) => s is WeeklyReportsLoaded);
    expect(b.state, isA<WeeklyReportsLoaded>());
    await b.close();
  });
  test('bloc: 局部 bloc 详情不污染全局 bloc', () async {
    final g = ReportBloc(_MockRepo());
    g.add(const LoadWeeklyReports());
    await g.stream.firstWhere((s) => s is WeeklyReportsLoaded);
    final l = ReportBloc(_MockRepo());
    l.add(const LoadWeeklyReportDetail('1'));
    await l.stream.firstWhere((s) => s is WeeklyReportDetailLoaded);
    expect(g.state, isA<WeeklyReportsLoaded>());
    expect(l.state, isA<WeeklyReportDetailLoaded>());
    await g.close(); await l.close();
  });
}
