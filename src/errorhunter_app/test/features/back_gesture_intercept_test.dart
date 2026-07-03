/// 回归测试：非首页一级 tab 根页按系统返回 → 回首页（不退出 App）。
///
/// 修复方案：TabBackToHomeObserver（WidgetsBindingObserver.didPopRoute）——系统返回
/// 最低层钩子。前三次用 PopScope 失败：ShellRoute 不是 PopScope 能管理的 ModalRoute，
/// go_router 把 tab 根页返回路由到顶层 Navigator 时绕过 shell 上的 PopScope（真机不生效）。
/// 本方案与 /add 顶层路由 PopScope 走同一返回路径（系统返回→engine.handlePopRoute→
/// 遍历 observer），/add 真机已验证生效，故本方案真机可生效。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:errorhunter_app/router/app_router.dart';

void main() {
  group('TabBackToHomeObserver.shouldIntercept', () {
    test('非首页一级 tab 根页应拦截', () {
      expect(TabBackToHomeObserver.shouldIntercept('/questions'), isTrue);
      expect(TabBackToHomeObserver.shouldIntercept('/reports/weekly'), isTrue);
      expect(TabBackToHomeObserver.shouldIntercept('/profile'), isTrue);
    });

    test('首页 / 子页 / 全屏页不拦截（交给默认）', () {
      expect(TabBackToHomeObserver.shouldIntercept('/home'), isFalse);
      expect(TabBackToHomeObserver.shouldIntercept('/questions/23'), isFalse);
      expect(TabBackToHomeObserver.shouldIntercept('/reports/weekly/1'), isFalse);
      expect(TabBackToHomeObserver.shouldIntercept('/add'), isFalse);
      expect(TabBackToHomeObserver.shouldIntercept('/review'), isFalse);
    });
  });

  testWidgets('系统返回(handlePopRoute) 在错题本 tab → 回首页', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const Text('home')),
            GoRoute(
                path: '/questions', builder: (_, __) => const Text('questions')),
            GoRoute(
                path: '/reports/weekly', builder: (_, __) => const Text('reports')),
            GoRoute(
                path: '/profile', builder: (_, __) => const Text('profile')),
          ],
        ),
      ],
    );
    final observer = TabBackToHomeObserver(router);

    await tester.pumpWidget(
        _ObserverHost(observer: observer, router: router));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/home');

    // 切到错题本 tab
    router.go('/questions');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/questions');

    // 模拟系统返回（真机系统返回走同一 handlePopRoute 路径）
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue, reason: 'observer 应拦截非首页 tab 根页返回');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/home',
        reason: '错题本 tab 按返回应回首页，而非退出');
  });

  testWidgets('首页 tab 按返回不拦截（交给默认→退出语义）', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const Text('home')),
            GoRoute(
                path: '/questions', builder: (_, __) => const Text('questions')),
          ],
        ),
      ],
    );
    final observer = TabBackToHomeObserver(router);
    await tester.pumpWidget(
        _ObserverHost(observer: observer, router: router));
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    expect(handled, isFalse, reason: '首页返回 observer 不拦截，交给默认');
  });
}

/// 注册/注销 observer 的测试宿主（复刻 ErrorHunterApp 的接线）。
class _ObserverHost extends StatefulWidget {
  const _ObserverHost({required this.observer, required this.router});
  final TabBackToHomeObserver observer;
  final GoRouter router;
  @override
  State<_ObserverHost> createState() => _ObserverHostState();
}

class _ObserverHostState extends State<_ObserverHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(widget.observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(widget.observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: widget.router);
}
