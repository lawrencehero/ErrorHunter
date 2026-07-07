/// 错题猎手 - GoRouter 路由配置
/// 来源：界面与交互设计文档 V1.0 §2.1-2.2
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/auth/pages/home_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/onboarding_page.dart';
import '../features/auth/pages/profile_completion_page.dart';
import '../features/auth/pages/splash_screen.dart';
import '../features/auth/pages/user_agreement_page.dart';
import '../features/auth/pages/privacy_policy_page.dart';
import '../features/export/pages/pdf_export_page.dart';
import '../features/profile/pages/deactivate_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/reminder_settings_page.dart';
import '../features/profile/pages/storage_management_page.dart';
import '../features/question/pages/add_question_page.dart';
import '../features/question/pages/question_detail_page.dart';
import '../features/question/pages/question_list_page.dart';
import '../features/question/bloc/question_bloc.dart';
import '../features/question/pages/recycle_bin_page.dart';
import '../features/settings/pages/theme_selector_page.dart';
import '../widgets/common/bottom_nav_bar.dart';
import '../features/report/pages/weekly_report_detail_page.dart';
import '../features/report/pages/weekly_report_list_page.dart';
import '../features/report/bloc/report_bloc.dart';
import '../features/review/models/review_report_model.dart';
import '../features/review/pages/eliminate_animation_page.dart';
import '../features/review/pages/review_page.dart';
import '../features/review/pages/review_report_page.dart';
import '../widgets/common/app_background.dart';

/// 包装全屏推入页：为其附加 AppBackground 渐变/纯色背景。
///
/// 顶层 GoRoute 默认走 MaterialPageRoute（Zoom 转场），其进入页首帧会暴露
/// 底层白底，玻璃主题下表现为"先闪白底再出渐变"。让推入页自带 AppBackground
/// 使路由在转场期间即为不透明主题背景，从根因上消除白闪。
Widget _withBackground(Widget page) => AppBackground(child: page);

/// 路由路径常量
class Routes {
  Routes._();

  // ─── Auth ────────────────────────────────────────────────
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String profileCompletion = '/profile-completion';

  // ─── Main Tabs ───────────────────────────────────────────
  static const String home = '/home';
  static const String questions = '/questions';
  static const String addQuestion = '/add';
  static const String profile = '/profile';

  // ─── Question Detail & Edit ──────────────────────────────
  static const String questionDetail = '/questions/:id';
  static const String questionEdit = '/questions/:id/edit';

  // ─── Review ──────────────────────────────────────────────
  static const String review = '/review';
  static const String reviewReport = '/review/report';
  static const String eliminateAnimation = '/eliminate';

  // ─── Reports ─────────────────────────────────────────────
  static const String weeklyReports = '/reports/weekly';
  static const String weeklyReportDetail = '/reports/weekly/:id';

  // ─── Settings ────────────────────────────────────────────
  static const String settingsReminder = '/settings/reminder';
  static const String settingsStorage = '/settings/storage';
  static const String settingsTheme = '/settings/theme';
  static const String recycleBin = '/recycle-bin';
  static const String pdfExport = '/export/pdf';

  // ─── Account ─────────────────────────────────────────────
  static const String deactivate = '/account/deactivate';

  // ─── Legal ──────────────────────────────────────────────────
  static const String userAgreement = '/legal/user-agreement';
  static const String privacyPolicy = '/legal/privacy-policy';
}

/// 全局路由观察者：供页面用 RouteAware.didPopNext 监听"上层路由 pop 回到自己"
/// （如周报详情返回列表时，列表页自动重新加载数据，避免共用 Bloc 状态错位空白）。
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// 路由构建器
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  observers: [routeObserver],
  // ✅ 监听 AuthBloc state 变化，每次变化重新评估 redirect
  refreshListenable: GoRouterRefreshStream(sl<AuthBloc>().stream),
  redirect: (context, state) {
    final authState = sl<AuthBloc>().state;
    final loc = state.matchedLocation;

    // AuthLoading / AuthInitial：splash 期间正在验证，不要重定向
    if (authState is AuthLoading || authState is AuthInitial) {
      return null;
    }

    // 当前处于 auth 流程的页面（不需要强制重定向）
    // /legal/* 也允许未登录访问：注册/登录页可点开《用户协议》《隐私政策》
    final isAtAuthFlow = loc == Routes.splash
        || loc == Routes.onboarding
        || loc == Routes.login
        || loc == Routes.profileCompletion
        || loc.startsWith('/legal/');

    // 已登录但停留在 auth 流程 → 跳到首页
    // 注意：splash 不在此列——splash 有自己的最短品牌展示(800ms)+BlocListener 跳转逻辑，
    // 这里若重定向会破坏品牌动画。splash 卡住的极端情况由其 5s 超时兜底。
    if (authState is Authenticated &&
        (loc == Routes.login ||
            loc == Routes.profileCompletion ||
            loc == Routes.onboarding)) {
      return Routes.home;
    }

    // 未登录但访问受保护页面 → 跳到登录页
    if (authState is Unauthenticated && !isAtAuthFlow) {
      return Routes.login;
    }

    return null;
  },
  routes: [
    // ─── Auth Flow ──────────────────────────────────────
    GoRoute(
      path: Routes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: Routes.profileCompletion,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ProfileCompletionPage(
          registrationToken: extra['registration_token'] as String? ?? '',
          phone: extra['phone'] as String? ?? '',
        );
      },
    ),

    // ─── Main Shell (Bottom Navigation) ─────────────────
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: Routes.home,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: Routes.questions,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: QuestionListPage()),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => _withBackground(BlocProvider<QuestionBloc>(
                create: (_) => sl<QuestionBloc>(),
                child: QuestionDetailPage(
                  questionId: state.pathParameters['id']!,
                ),
              )),
            ),
          ],
        ),
        GoRoute(
          path: Routes.weeklyReports,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WeeklyReportListPage()),
        ),
        GoRoute(
          path: Routes.profile,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
      ],
    ),

    // ─── Full-screen Pages (outside ShellRoute, no bottom nav) ──
    GoRoute(
      path: Routes.addQuestion,
      builder: (context, state) => _withBackground(const AddQuestionPage()),
    ),

    // ─── Full-screen Pages ──────────────────────────────
    GoRoute(
      path: Routes.review,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final ids = (extra['questionIds'] as List?)?.cast<String>();
        return _withBackground(ReviewPage(questionIds: ids));
      },
    ),
    GoRoute(
      path: Routes.reviewReport,
      builder: (context, state) {
        final report = state.extra as ReviewReportModel?;
        return _withBackground(
            ReviewReportPage(report: report ?? ReviewReportModel.empty()));
      },
    ),
    GoRoute(
      path: Routes.eliminateAnimation,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return _withBackground(EliminateAnimationPage(
          totalEliminated: args?['totalEliminated'] as int? ?? 1,
          isFirstInSession: args?['isFirstInSession'] as bool? ?? true,
        ));
      },
    ),

    // ─── Reports Detail ─────────────────────────────────
    // 详情页使用独立的局部 ReportBloc（BlocProvider 就地创建），避免与列表/首页
    // 共用的全局 ReportBloc 相互污染：详情 LoadWeeklyReportDetail 把状态置为
    // WeeklyReportDetailLoaded，若走全局 bloc，返回列表时列表页 BlocBuilder 不认
    // 该状态会卡在兜底转圈。这里隔离后，全局 bloc 仍保持 WeeklyReportsLoaded，
    // 返回列表直接显示，无需依赖 didPopNext 重载。
    GoRoute(
      path: Routes.weeklyReportDetail,
      builder: (context, state) => _withBackground(BlocProvider<ReportBloc>(
        create: (_) => sl<ReportBloc>(),
        child: WeeklyReportDetailPage(
          reportId: state.pathParameters['id']!,
        ),
      )),
    ),

    // ─── Settings ───────────────────────────────────────
    GoRoute(
      path: Routes.settingsReminder,
      builder: (context, state) => _withBackground(const ReminderSettingsPage()),
    ),
    GoRoute(
      path: Routes.settingsStorage,
      builder: (context, state) => _withBackground(const StorageManagementPage()),
    ),
    GoRoute(
      path: Routes.settingsTheme,
      builder: (context, state) => _withBackground(const ThemeSelectorPage()),
    ),
    GoRoute(
      path: Routes.recycleBin,
      builder: (context, state) => _withBackground(const RecycleBinPage()),
    ),
    GoRoute(
      path: Routes.pdfExport,
      builder: (context, state) => _withBackground(const PdfExportPage()),
    ),

    // ─── Account ────────────────────────────────────────
    GoRoute(
      path: Routes.deactivate,
      builder: (context, state) => _withBackground(const DeactivatePage()),
    ),

    // ─── Legal ──────────────────────────────────────────
    GoRoute(
      path: Routes.userAgreement,
      builder: (context, state) => _withBackground(const UserAgreementPage()),
    ),
    GoRoute(
      path: Routes.privacyPolicy,
      builder: (context, state) => _withBackground(const PrivacyPolicyPage()),
    ),
  ],
);

/// 主框架 Shell（底部 Tab 导航 + 浮动录入按钮）
class _MainShell extends StatelessWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
        extendBody: false,
        bottomNavigationBar: EHBottomNavBar(
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) => _onItemTapped(index, context),
          onFabPressed: () => context.go(Routes.addQuestion),
          items: const [
            EHBottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: '首页',
            ),
            EHBottomNavItem(
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book,
              label: '错题本',
            ),
            EHBottomNavItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart,
              label: '周报',
            ),
            EHBottomNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: '我的',
            ),
          ],
        ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(Routes.home)) return 0;
    if (location.startsWith(Routes.questions)) return 1;
    if (location.startsWith(Routes.weeklyReports)) return 2;
    if (location.startsWith(Routes.profile)) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(Routes.home);
      case 1:
        context.go(Routes.questions);
      case 2:
        context.go(Routes.weeklyReports);
      case 3:
        context.go(Routes.profile);
    }
  }
}

/// 把 AuthBloc.state stream 转成 Listenable，触发 GoRouter 重新评估 redirect
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// 系统返回最低层钩子：在「非首页一级 tab 根页」按系统返回 → 回首页 tab，而非退出 App。
///
/// 为何不用 PopScope：ShellRoute 不是 PopScope 能管理的 ModalRoute，go_router 把 tab
/// 根页的返回路由到顶层 Navigator 时绕过 shell 上的 PopScope（真机验证不生效，前三次
/// 修复失败的根因）。对比之下，/add 等顶层路由的 PopScope 能生效（root Navigator 上的
/// ModalRoute）。WidgetsBindingObserver.didPopRoute 是系统返回的最低层钩子，与 /add 的
/// PopScope 走同一返回路径（系统返回 → engine.handlePopRoute → 遍历 observer），真机
/// 稳定触发——这是本方案能在真机生效的依据。
///
/// didPopRoute 返回 false 时交给默认（Router 的 BackButtonDispatcher）：
/// 首页根页 → 无栈 pop → 退出 App；详情子页 → pop 子页；/add 等全屏页 → 其自身 PopScope 接管。
class TabBackToHomeObserver extends WidgetsBindingObserver {
  TabBackToHomeObserver(this._router);

  final GoRouter _router;

  /// 当前是否处于「非首页一级 tab 根页」——抽成可测纯函数。
  static bool shouldIntercept(String location) =>
      location == Routes.questions ||
      location == Routes.weeklyReports ||
      location == Routes.profile;

  @override
  Future<bool> didPopRoute() async {
    final loc = _router.routerDelegate.currentConfiguration.uri.toString();
    if (shouldIntercept(loc)) {
      _router.go(Routes.home);
      return true;
    }
    return false;
  }
}
