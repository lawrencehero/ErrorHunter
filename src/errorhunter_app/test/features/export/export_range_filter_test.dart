/// isExportableInRange 单元测试
///
/// 守护修复：PDF 导出"近 3 个月"过滤原用 isAfter，会漏掉恰好满 3 个月
/// 当天录入的错题。改为 !isBefore 后，当天应被包含。同时覆盖本月/全部范围。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/features/export/pages/pdf_export_page.dart';

void main() {
  // 固定 now，避免测试受当前日期影响
  final now = DateTime(2026, 6, 29, 12, 0, 0);

  group('isExportableInRange - thisMonth', () {
    test('同年同月包含', () {
      expect(isExportableInRange(DateTime(2026, 6, 1), ExportTimeRange.thisMonth, now: now), isTrue);
      expect(isExportableInRange(DateTime(2026, 6, 28), ExportTimeRange.thisMonth, now: now), isTrue);
      expect(isExportableInRange(DateTime(2026, 6, 30), ExportTimeRange.thisMonth, now: now), isTrue);
    });

    test('跨年/跨月排除', () {
      expect(isExportableInRange(DateTime(2026, 5, 31), ExportTimeRange.thisMonth, now: now), isFalse);
      expect(isExportableInRange(DateTime(2026, 7, 1), ExportTimeRange.thisMonth, now: now), isFalse);
      expect(isExportableInRange(DateTime(2025, 6, 1), ExportTimeRange.thisMonth, now: now), isFalse);
    });
  });

  group('isExportableInRange - lastThreeMonths', () {
    // now = 2026-06-29，threeMonthsAgo = 2026-03-29
    test('恰好满 3 个月当天应被包含（修复 isAfter 漏当天）', () {
      expect(isExportableInRange(DateTime(2026, 3, 29), ExportTimeRange.lastThreeMonths, now: now), isTrue);
    });

    test('3 个月前一天排除', () {
      expect(isExportableInRange(DateTime(2026, 3, 28), ExportTimeRange.lastThreeMonths, now: now), isFalse);
    });

    test('当天与近期包含', () {
      expect(isExportableInRange(now, ExportTimeRange.lastThreeMonths, now: now), isTrue);
      expect(isExportableInRange(DateTime(2026, 5, 1), ExportTimeRange.lastThreeMonths, now: now), isTrue);
      expect(isExportableInRange(DateTime(2026, 4, 15), ExportTimeRange.lastThreeMonths, now: now), isTrue);
    });

    test('跨年边界：now=2026-02-10 时 threeMonthsAgo 应落在 2025-11-10', () {
      final febNow = DateTime(2026, 2, 10);
      expect(isExportableInRange(DateTime(2025, 11, 10), ExportTimeRange.lastThreeMonths, now: febNow), isTrue);
      expect(isExportableInRange(DateTime(2025, 11, 9), ExportTimeRange.lastThreeMonths, now: febNow), isFalse);
    });

    test('月末日期规范化：now=2026-05-31 前推 3 个月', () {
      // DateTime(2026, 2, 31) 会被 Dart 规范化为 2026-03-03，
      // 这里验证函数在该 now 下行为确定（不抛异常、有明确包含/排除）
      final mayNow = DateTime(2026, 5, 31);
      // 只要 2026-03-03 及之后都被包含即可
      expect(isExportableInRange(DateTime(2026, 3, 3), ExportTimeRange.lastThreeMonths, now: mayNow), isTrue);
      expect(isExportableInRange(DateTime(2026, 3, 2), ExportTimeRange.lastThreeMonths, now: mayNow), isFalse);
    });
  });

  group('isExportableInRange - all', () {
    test('任意日期均包含', () {
      expect(isExportableInRange(DateTime(2000, 1, 1), ExportTimeRange.all, now: now), isTrue);
      expect(isExportableInRange(DateTime(2099, 12, 31), ExportTimeRange.all, now: now), isTrue);
      expect(isExportableInRange(now, ExportTimeRange.all, now: now), isTrue);
    });
  });
}
