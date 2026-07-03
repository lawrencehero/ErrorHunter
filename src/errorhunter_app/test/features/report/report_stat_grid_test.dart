/// 错题猎手 - 周报四宫格统计组件 widget 测试
///
/// 回归：曾使用 `GridView.count` + `childAspectRatio: 1.6` 固定单元格高度，
/// 叠加 `EHStatCard` 的 `Clip.antiAlias` 会裁剪掉底部趋势文案（如「持平 vs 上周」）
/// 的下半部分。改为按内容自适应高度后，断言：
/// 1. 不抛 RenderFlex overflow 异常；
/// 2. 趋势文案完整命中（含较长文案如「持平 vs 上周」「+12 vs 上周」）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/features/report/widgets/report_stat_grid.dart';
import 'package:errorhunter_app/widgets/common/cards/stat_card.dart';

Widget _wrap(Widget child) {
  // 复刻周报详情页真实布局约束：
  // - 常见手机逻辑宽度 360（较小机型，更易复现裁剪）；
  // - SingleChildScrollView + 水平 16px pagePadding（与详情页一致）。
  // 这样每张卡片宽度 ≈ (360-32-8)/2 ≈ 160，与真机接近。
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    ),
  );
}

/// 把测试视图逻辑宽度设为 360（模拟较小手机），DPR=1。
/// 必须在 pumpWidget 之前调用。
void _usePhoneWidth(WidgetTester tester) {
  // ignore: deprecated_member_use
  final window = tester.binding.window;
  // ignore: deprecated_member_use
  window.physicalSizeTestValue = const Size(360, 800);
  // ignore: deprecated_member_use
  window.devicePixelRatioTestValue = 1.0;
  addTearDown(() {
    // ignore: deprecated_member_use
    window.clearPhysicalSizeTestValue();
    // ignore: deprecated_member_use
    window.clearDevicePixelRatioTestValue();
  });
}

/// 断言趋势文案 Rect 完整落在其所在 EHStatCard 的裁剪边界内。
///
/// EHStatCard 外层 Container 使用 Clip.antiAlias；旧实现用
/// childAspectRatio:1.6 固定单元格高度，趋势行底部会越界被裁掉。
/// 这里通过趋势 Text 向上定位到 EHStatCard 根，比较二者 Rect。
void _assertTrendInsideCard(WidgetTester tester, String trendText) {
  final trendRect = tester.getRect(find.text(trendText));
  final cardFinder = find.ancestor(
    of: find.text(trendText),
    matching: find.byType(EHStatCard),
  );
  expect(cardFinder, findsOneWidget);
  final cardRect = tester.getRect(cardFinder);
  expect(
    trendRect.bottom,
    lessThanOrEqualTo(cardRect.bottom + 0.5),
    reason: '趋势文案「$trendText」底部(${trendRect.bottom})超出卡片底部'
        '(${cardRect.bottom})，底部被裁剪',
  );
  expect(
    trendRect.top,
    greaterThanOrEqualTo(cardRect.top - 0.5),
    reason: '趋势文案「$trendText」顶部(${trendRect.top})超出卡片顶部'
        '(${cardRect.top})，顶部被裁剪',
  );
}

void main() {
  testWidgets(
    'ReportStatGrid: 趋势文案完整显示，不溢出/不裁剪（含「持平 vs 上周」）',
    (tester) async {
      _usePhoneWidth(tester);
      await tester.pumpWidget(_wrap(
        const ReportStatGrid(
          newCount: 12,
          newVsLastWeek: 0, // 「持平 vs 上周」
          eliminatedCount: 8,
          eliminatedVsLastWeek: 3, // 「+3 vs 上周」
          reviewCount: 15,
          reviewVsLastWeek: -2, // 「-2 vs 上周」
          accuracyRate: 92,
          accuracyVsLastWeek: 5, // 「+5% vs 上周」
        ),
      ));
      await tester.pumpAndSettle();

      // 不应有任何渲染异常（含 RenderFlex overflow / clip 行为异常）。
      expect(tester.takeException(), isNull);

      // 数值与标签命中。
      expect(find.text('新增错题'), findsOneWidget);
      expect(find.text('消灭错题'), findsOneWidget);
      expect(find.text('复习次数'), findsOneWidget);
      expect(find.text('正确率'), findsOneWidget);

      // 趋势文案完整命中（断言未被裁剪掉）。
      // 注意：_formatTrend 产出格式为「vs上周」（无空格），保持与生产代码一致。
      expect(find.text('持平 vs上周'), findsOneWidget);
      expect(find.text('+3 vs上周'), findsOneWidget);
      expect(find.text('-2 vs上周'), findsOneWidget);
      expect(find.text('+5% vs上周'), findsOneWidget);

      // 关键回归断言：每张卡片的趋势文案 Rect 必须完整落在该卡片的
      // 裁剪边界（EHStatCard 外层 Container，Clip.antiAlias）之内。
      // 旧实现用 childAspectRatio:1.6 固定高度，趋势行底部会越界被裁掉。
      _assertTrendInsideCard(tester, '持平 vs上周');
      _assertTrendInsideCard(tester, '+3 vs上周');
      _assertTrendInsideCard(tester, '-2 vs上周');
      _assertTrendInsideCard(tester, '+5% vs上周');
    },
  );

  testWidgets(
    'ReportStatGrid: 较长趋势文案「+12 vs 上周」也能完整显示',
    (tester) async {
      _usePhoneWidth(tester);
      await tester.pumpWidget(_wrap(
        const ReportStatGrid(
          newCount: 128,
          newVsLastWeek: 12,
          eliminatedCount: 64,
          eliminatedVsLastWeek: 0,
          reviewCount: 99,
          reviewVsLastWeek: 10,
          accuracyRate: 100,
          accuracyVsLastWeek: -8,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('+12 vs上周'), findsOneWidget);
      expect(find.text('持平 vs上周'), findsOneWidget);
      expect(find.text('+10 vs上周'), findsOneWidget);
      expect(find.text('-8% vs上周'), findsOneWidget);

      // 关键回归断言：趋势 Text 的渲染尺寸应能容纳其文字高度，
      // 即垂直方向没有被压缩到 0 / 被父容器裁剪。
      final trendText = find.text('+12 vs上周');
      final box = tester.renderObject<RenderBox>(trendText);
      expect(box.size.height, greaterThan(0));

      _assertTrendInsideCard(tester, '+12 vs上周');
    },
  );
}
