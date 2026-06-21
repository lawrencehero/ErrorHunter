/// 错题猎手 - GoRouter 路由配置
/// 来源：界面与交互设计文档 V1.0 §2.1-2.2
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/pages/home_page.dart';
import '../features/auth/pages/onboarding_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/pages/splash_screen.dart';
import '../features/export/pages/pdf_export_page.dart';
import '../features/profile/pages/deactivate_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/reminder_settings_page.dart';
import '../features/profile/pages/storage_management_page.dart';
import '../features/question/pages/add_question_page.dart';
import '../features/question/pages/question_detail_page.dart';
import '../features/question/pages/question_list_page.dart';
import '../features/question/pages/recycle_bin_page.dart';
import '../features/settings/pages/theme_selector_page.dart';
import '../widgets/common/bottom_nav_bar.dart';
import '../features/report/pages/weekly_report_detail_page.dart';
import '../features/report/pages/weekly_report_list_page.dart';
import '../features/review/models/review_report_model.dart';
import '../features/review/pages/eliminate_animation_page.dart';
import '../features/review/pages/review_page.dart';
import '../features/review/pages/review_report_page.dart';

/// 路由路径常量
class Routes {
  Routes._();

  // ─── Auth ────────────────────────────────────────────────
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';

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
}

/// 路由构建器
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
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
      builder: (context, state) => const RegisterPage(),
    ),

    // ─── Main Shell (Bottom Navigation) ─────────────────
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: Routes.questions,
          builder: (context, state) => const QuestionListPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => QuestionDetailPage(
                questionId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: Routes.weeklyReports,
          builder: (context, state) => const WeeklyReportListPage(),
        ),
        GoRoute(
          path: Routes.profile,
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),

    // ─── Full-screen Pages (outside ShellRoute, no bottom nav) ──
    GoRoute(
      path: Routes.addQuestion,
      builder: (context, state) => const AddQuestionPage(),
    ),

    // ─── Full-screen Pages ──────────────────────────────
    GoRoute(
      path: Routes.review,
      builder: (context, state) => const ReviewPage(),
    ),
    GoRoute(
      path: Routes.reviewReport,
      builder: (context, state) {
        final report = state.extra as ReviewReportModel?;
        return ReviewReportPage(report: report ?? ReviewReportModel.empty());
      },
    ),
    GoRoute(
      path: Routes.eliminateAnimation,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return EliminateAnimationPage(
          totalEliminated: args?['totalEliminated'] as int? ?? 1,
          isFirstInSession: args?['isFirstInSession'] as bool? ?? true,
        );
      },
    ),

    // ─── Reports Detail ─────────────────────────────────
    GoRoute(
      path: Routes.weeklyReportDetail,
      builder: (context, state) => WeeklyReportDetailPage(
        reportId: state.pathParameters['id']!,
      ),
    ),

    // ─── Settings ───────────────────────────────────────
    GoRoute(
      path: Routes.settingsReminder,
      builder: (context, state) => const ReminderSettingsPage(),
    ),
    GoRoute(
      path: Routes.settingsStorage,
      builder: (context, state) => const StorageManagementPage(),
    ),
    GoRoute(
      path: Routes.settingsTheme,
      builder: (context, state) => const ThemeSelectorPage(),
    ),
    GoRoute(
      path: Routes.recycleBin,
      builder: (context, state) => const RecycleBinPage(),
    ),
    GoRoute(
      path: Routes.pdfExport,
      builder: (context, state) => const PdfExportPage(),
    ),

    // ─── Account ────────────────────────────────────────
    GoRoute(
      path: Routes.deactivate,
      builder: (context, state) => const DeactivatePage(),
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
