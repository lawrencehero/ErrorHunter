/// 错题猎手 - 复习进度条 widget 测试
///
/// 守护"下次复习时间"展示：
/// 1. 未消灭且 nextReviewDate 有效 → 进度条下方显示"下次复习 M月D日"；
/// 2. 已消灭 → 不显示（已消灭题下次复习语义为复活检测，另处展示）；
/// 3. nextReviewDate 为零值（后端 time.Time{} → 0001-01-01）→ 不显示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/features/question/widgets/review_progress_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('未消灭且 nextReviewDate 有效 → 显示"下次复习 M月D日"', (tester) async {
    final date = DateTime.parse('2026-07-13T00:00:00Z');
    await tester.pumpWidget(_wrap(ReviewProgressBar(
      masterCount: 1,
      isEliminated: false,
      nextReviewDate: date,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // date 为 UTC 午夜 7/13，按日期语义取月/日 → "下次复习 7月13日"。
    expect(find.text('下次复习 7月13日'), findsOneWidget);
  });

  testWidgets('已消灭 → 不显示下次复习', (tester) async {
    final date = DateTime.parse('2026-07-13T00:00:00Z');
    await tester.pumpWidget(_wrap(ReviewProgressBar(
      masterCount: 3,
      isEliminated: true,
      nextReviewDate: date,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('下次复习 7月13日'), findsNothing);
  });

  testWidgets('nextReviewDate 为零值（0001-01-01）→ 不显示', (tester) async {
    await tester.pumpWidget(_wrap(ReviewProgressBar(
      masterCount: 1,
      isEliminated: false,
      nextReviewDate: DateTime.parse('0001-01-01T00:00:00Z'),
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('下次复习'), findsNothing);
  });

  testWidgets('未传 nextReviewDate → 不显示下次复习', (tester) async {
    await tester.pumpWidget(_wrap(const ReviewProgressBar(
      masterCount: 1,
      isEliminated: false,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('下次复习'), findsNothing);
  });
}
