/// 错题猎手 - 复习历史时间线 widget 测试
///
/// 守护修复：
/// 1. 复习序号按时间顺序自增（1,2,3…），与艾宾浩斯轮次解耦。后端在自评 FAILED
///    时会把 review_round 重置为 1，导致同一题的复习历史出现多条"第1轮复习"。
///    修复后无论是否掌握，每条记录的序号都唯一递增。
/// 2. 详情接口限 20 条：当 totalReviewCount > 返回条数时，最旧可见记录补偏移，
///    使最新一条序号 = 总次数。
/// 3. 时间线自身不再渲染"复习历史 / 共 N 轮"标题（由详情页可折叠区块标题行
///    统一展示，折叠态可见），这里只断言各轮记录文案。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/features/question/models/question_model.dart';
import 'package:errorhunter_app/features/question/widgets/review_history_timeline.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

ReviewRecord _rec(String id, int round, DateTime date, String result) =>
    ReviewRecord(
      id: id,
      reviewRound: round,
      reviewDate: date,
      result: result,
    );

void main() {
  testWidgets(
    '复习序号按时间自增，FAILED 重置轮次不再产生重复"第1轮复习"',
    (tester) async {
      // 后端返回倒序（最新在前），且三条记录的 review_round 都是 1
      // （连续三次自评 FAILED，艾宾浩斯轮次每次重置）。
      final records = [
        _rec('r3', 1, DateTime(2026, 7, 7), 'FAILED'),
        _rec('r2', 1, DateTime(2026, 7, 6), 'FAILED'),
        _rec('r1', 1, DateTime(2026, 7, 5), 'FAILED'),
      ];
      await tester.pumpWidget(_wrap(ReviewHistoryTimeline(
        records: records,
        totalReviewCount: 3,
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 三条记录序号分别为 3/2/1（最新在前），不再重复"第1轮"。
      expect(find.text('第3轮复习'), findsOneWidget);
      expect(find.text('第2轮复习'), findsOneWidget);
      expect(find.text('第1轮复习'), findsOneWidget);
      // 时间线自身不渲染标题/总轮次（交由详情页标题行）。
      expect(find.text('复习历史'), findsNothing);
      expect(find.text('共 3 轮'), findsNothing);
    },
  );

  testWidgets(
    'totalReviewCount 大于返回条数时补偏移，最新一条序号 = 总次数',
    (tester) async {
      // 累计复习 5 次，但详情接口只返回最近 3 条（倒序）。
      final records = [
        _rec('r5', 5, DateTime(2026, 7, 7), 'MASTERED'),
        _rec('r4', 4, DateTime(2026, 7, 6), 'PARTIAL'),
        _rec('r3', 3, DateTime(2026, 7, 5), 'FAILED'),
      ];
      await tester.pumpWidget(_wrap(ReviewHistoryTimeline(
        records: records,
        totalReviewCount: 5,
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 偏移 = 5 - 3 = 2，最早可见(r3)=第3轮，最新(r5)=第5轮。
      expect(find.text('第5轮复习'), findsOneWidget);
      expect(find.text('第4轮复习'), findsOneWidget);
      expect(find.text('第3轮复习'), findsOneWidget);
      expect(find.text('共 5 轮'), findsNothing);
    },
  );

  testWidgets(
    '未传 totalReviewCount（mock/旧缓存）时回退为记录条数，序号仍按时间自增',
    (tester) async {
      // mock 数据为顺序（最早在前），reviewCount 缺省 0。
      final records = [
        _rec('r1', 1, DateTime(2026, 7, 5), 'FAILED'),
        _rec('r2', 2, DateTime(2026, 7, 6), 'MASTERED'),
      ];
      await tester.pumpWidget(_wrap(ReviewHistoryTimeline(records: records)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('第1轮复习'), findsOneWidget);
      expect(find.text('第2轮复习'), findsOneWidget);
      expect(find.text('共 2 轮'), findsNothing);
    },
  );

  testWidgets('无复习记录时展示空态，不渲染序号与总轮次', (tester) async {
    await tester.pumpWidget(_wrap(const ReviewHistoryTimeline(records: [])));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('暂无复习记录'), findsOneWidget);
    expect(find.text('共 0 轮'), findsNothing);
  });

  testWidgets('宽屏下时间线条目不溢出（守护 IntrinsicHeight+Text 2px 溢出）',
      (tester) async {
    // Chrome 桌面端逻辑宽度约 981，曾出现 _TimelineItem 内容 Column
    // "overflowed by 2.0 pixels"（IntrinsicHeight 对文本行高 intrinsic 估算
    // 与运行时相差约 1px/行）。这里以 981 宽度断言无渲染异常。
    // ignore: deprecated_member_use
    final window = tester.binding.window;
    // ignore: deprecated_member_use
    window.physicalSizeTestValue = const Size(981, 1200);
    // ignore: deprecated_member_use
    window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      // ignore: deprecated_member_use
      window.clearPhysicalSizeTestValue();
      // ignore: deprecated_member_use
      window.clearDevicePixelRatioTestValue();
    });

    final records = [
      _rec('r3', 1, DateTime(2026, 7, 7), 'FAILED'),
      _rec('r2', 1, DateTime(2026, 7, 6), 'FAILED'),
      _rec('r1', 1, DateTime(2026, 7, 5), 'FAILED'),
    ];
    await tester.pumpWidget(_wrap(ReviewHistoryTimeline(
      records: records,
      totalReviewCount: 3,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('复习时间按本地时区显示，不显示 UTC（守护 toLocal 回归）',
      (tester) async {
    // 后端 reviewed_at 带偏移：2026-07-07T20:11:41+08:00。
    // DateTime.parse 得到 isUtc=true 的 DateTime（hour=12 UTC）。修复前
    // _formatDate 直接取 .hour 会显示 "7/7 12:11"（UTC）；修复后应显示本地时间。
    final raw = '2026-07-07T20:11:41.109776+08:00';
    final parsed = DateTime.parse(raw);
    final records = [
      ReviewRecord(
        id: 'r1',
        reviewRound: 1,
        reviewDate: parsed,
        result: 'MASTERED',
      ),
    ];
    await tester.pumpWidget(_wrap(ReviewHistoryTimeline(records: records)));
    await tester.pumpAndSettle();

    // 期望显示本地时区的时间串（与机器时区无关地计算）。
    final local = parsed.toLocal();
    final expected =
        '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(find.text(expected), findsOneWidget,
        reason: '应显示本地时区时间 $expected，而非 UTC');

    // 守护：在 +08:00 机器上不应出现 UTC 串 "7/7 12:11"。
    expect(find.text('7/7 12:11'), findsNothing);
  });
}
