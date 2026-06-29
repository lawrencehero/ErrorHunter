/// 回归测试：周报 model 的周序计算、可空错因、标题展示。
/// 覆盖本次修复：
/// 1. week_number 后端是 isoYear*100+isoWeek（如 202626），不能直接展示，
///    前端改用 WeeklySummary.isoWeekNumber / title 从 weekStart 本地计算。
/// 2. mostFrequentErrorCategory 改为可空，本周无新增错题时为 null。
import 'package:errorhunter_app/features/report/models/weekly_report_model.dart';
import 'package:flutter_test/flutter_test.dart';

WeeklySummary _summary(DateTime start, DateTime end) => WeeklySummary(
      id: '1',
      weekNumber: 0, // 后端原始 6 位值，前端不再直接用于展示
      startDate: start,
      endDate: end,
      newCount: 0,
      eliminatedCount: 0,
      reviewCount: 0,
    );

void main() {
  group('WeeklySummary.isoWeekNumber', () {
    test('普通周一对应 ISO 周序', () {
      // 2026-06-22 是周一，ISO 第 26 周
      final s = _summary(DateTime(2026, 6, 22), DateTime(2026, 6, 28));
      expect(s.isoWeekNumber, 26);
      expect(s.title, '第26周周报');
    });

    test('跨年周：12-29 属于下一年第 1 周', () {
      // 2025-12-29 周一，ISO 2026 第 1 周
      final s = _summary(DateTime(2025, 12, 29), DateTime(2026, 1, 4));
      expect(s.isoWeekNumber, 1);
      expect(s.title, '第1周周报');
    });

    test('年末第 53 周', () {
      // 2026-12-28 周一，ISO 第 53 周
      final s = _summary(DateTime(2026, 12, 28), DateTime(2027, 1, 3));
      expect(s.isoWeekNumber, 53);
      expect(s.title, '第53周周报');
    });

    test('后端 6 位 weekNumber 不再用于标题', () {
      // 即便后端返回 202626，title 也只显示 26
      final s = WeeklySummary(
        id: '1',
        weekNumber: 202626,
        startDate: DateTime(2026, 6, 22),
        endDate: DateTime(2026, 6, 28),
        newCount: 0,
        eliminatedCount: 0,
        reviewCount: 0,
      );
      expect(s.weekNumber, 202626); // 原始值保留
      expect(s.title, '第26周周报'); // 标题用 ISO 周序
    });
  });

  group('WeeklyReportModel.mostFrequentErrorCategory 可空', () {
    test('本周无新增错题：category 为 null（后端 omitempty 不返回）', () {
      final m = WeeklyReportModel(
        summary: _summary(DateTime(2026, 6, 22), DateTime(2026, 6, 28)),
        newCountVsLastWeek: 0,
        eliminatedCountVsLastWeek: 0,
        reviewCountVsLastWeek: 0,
        accuracyRate: 0.0,
        accuracyRateVsLastWeek: 0.0,
        achievements: const [],
        topKnowledgePoints: const [],
        mostFrequentErrorCategory: null,
        mostFrequentErrorPercentage: 0.0,
      );
      expect(m.mostFrequentErrorCategory, isNull);
      // 详情页据此渲染空态文案，而非回退到 'UNKNOWN' chip
    });

    test('有错因：category 为枚举字符串', () {
      final m = WeeklyReportModel(
        summary: _summary(DateTime(2026, 6, 22), DateTime(2026, 6, 28)),
        newCountVsLastWeek: 0,
        eliminatedCountVsLastWeek: 0,
        reviewCountVsLastWeek: 0,
        accuracyRate: 78.5,
        accuracyRateVsLastWeek: 0.0,
        achievements: const [],
        topKnowledgePoints: const [],
        mostFrequentErrorCategory: 'KNOWLEDGE',
        mostFrequentErrorPercentage: 42.5,
      );
      expect(m.mostFrequentErrorCategory, 'KNOWLEDGE');
      expect(m.mostFrequentErrorPercentage, 42.5);
    });

    test('mock 工厂仍可构造（category 为非空字符串赋给可空字段）', () {
      final m = WeeklyReportModel.mock(
        summary: _summary(DateTime(2026, 6, 22), DateTime(2026, 6, 28)),
      );
      expect(m.mostFrequentErrorCategory, 'KNOWLEDGE');
      expect(m.mostFrequentErrorPercentage, 42.5);
    });
  });
}
