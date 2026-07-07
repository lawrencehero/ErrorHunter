/// 错题猎手 - "已消灭"勾选徽标 widget 测试
///
/// 守护 CustomPaint 在多尺寸/玻璃态下不抛异常，且渲染出 CustomPaint 节点。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/widgets/common/icons/eliminated_check_icon.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('EliminatedCheckIcon 各尺寸/玻璃态渲染无异常', (tester) async {
    for (final size in [12.0, 16.0, 24.0, 40.0]) {
      for (final isGlass in [false, true]) {
        await tester.pumpWidget(_wrap(
          EliminatedCheckIcon(size: size, isGlass: isGlass),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'size=$size isGlass=$isGlass 不应抛异常');
        expect(
          find.descendant(
            of: find.byType(EliminatedCheckIcon),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
          reason: 'size=$size isGlass=$isGlass 应渲染一个 CustomPaint',
        );
        final box = tester.getSize(find.byType(EliminatedCheckIcon));
        expect(box, Size(size, size),
            reason: '尺寸应为 ${size}x$size');
      }
    }
  });
}
