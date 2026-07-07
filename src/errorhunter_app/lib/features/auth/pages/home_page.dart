/// 错题猎手 - 首页 Dashboard V4.0 (多主题支持)
/// 根据 ThemeManager 当前主题自动切换游戏化/玻璃拟态风格
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di/injection.dart';
import '../../../domain/repositories/review_repository.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';

import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/loading/skeleton_list.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../report/bloc/report_bloc.dart';
import '../../report/bloc/report_event.dart';
import '../../report/bloc/report_state.dart';
import '../../report/models/dashboard_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<ReportBloc>().add(const LoadDashboard());
  }

  String _getUserName(DashboardData? dashboard) {
    // 优先使用 dashboard 中的昵称，fallback 到 AuthBloc
    if (dashboard != null && dashboard.nickname.isNotEmpty) {
      return dashboard.nickname;
    }
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) return authState.user.nickname;
    return '同学';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        final ext = context.themeExt;
        final isGlass = ext.isDarkBackground;

        if (state is ReportLoading || state is ReportInitial) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildSkeleton(),
          );
        }

        if (state is ReportError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildErrorView(state.message),
          );
        }

        if (state is DashboardLoaded) {
          final dashboard = state.dashboard;
          final isNewUser = dashboard.totalQuestions == 0;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: isNewUser
                ? _buildEmptyState(ext, isGlass, dashboard)
                : isGlass
                    ? _buildScrollableContent(ext, isGlass, dashboard)
                    : _buildGamifiedLayout(ext, dashboard),
          );
        }

        // 其他未知状态 → 骨架屏
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildSkeleton(),
        );
      },
    );
  }

  // ─── 错误视图 ──────────────────────────────────────────────

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15, fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.read<ReportBloc>().add(const LoadDashboard()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Text('重新加载',
                  style: TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 空状态引导（新用户） ───────────────────────────────────

  Widget _buildEmptyState(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    final userName = _getUserName(dashboard);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.base,
        bottom: AppSpacing.xxl,
        left: AppSpacing.base,
        right: AppSpacing.base,
      ),
      child: Column(
        children: [
          // 问候
          if (isGlass) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Hi，$userName 👋',
                    style: AppTypography.primary.h1.copyWith(
                      color: Colors.white, fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.base),
          ],
          // 空状态卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: isGlass
                ? BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  )
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                      BoxShadow(color: AppColors.brandPrimaryDark, offset: const Offset(0, 4), blurRadius: 0),
                    ],
                  ),
            child: Column(
              children: [
                Text('🎯', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('欢迎加入错题猎手！',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: isGlass ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('还没有错题记录哦，快去添加你的第一道错题吧！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: isGlass ? Colors.white.withOpacity(0.7) : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go(Routes.addQuestion),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isGlass ? null : [
                        BoxShadow(color: AppColors.brandPrimaryDark, offset: const Offset(0, 4), blurRadius: 0),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 6),
                        Text('拍照录入错题',
                          style: AppTypography.primary.button.copyWith(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 游戏化布局：固定蓝色顶栏 + 下方滚动内容 ──────────────

  Widget _buildGamifiedLayout(AppThemeExtension ext, DashboardData dashboard) {
    final userName = _getUserName(dashboard);
    final topPadding = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        // 固定蓝色顶栏（不随滚动移动）
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: topPadding + 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hi，$userName 👋',
                        style: AppTypography.primary.h1.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('${dashboard.streakDays}天',
                            style: AppTypography.primary.caption.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // 可滚动内容区域
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: AppSpacing.base,
              bottom: 100,
              left: AppSpacing.base,
              right: AppSpacing.base,
            ),
            child: Column(
              children: [
                _buildStreakCard(ext, false, dashboard),
                SizedBox(height: AppSpacing.base),
                _buildTaskCard(ext, false, dashboard),
                SizedBox(height: AppSpacing.base),
                _buildStatsRow(ext, false, dashboard),
                SizedBox(height: AppSpacing.base),
                _buildKnowledgeSection(ext, false, dashboard),
                SizedBox(height: AppSpacing.base),
                _buildWeekCard(ext, false, dashboard),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 游戏化蓝色顶栏 ───────────────────────────────────────

  Widget _buildGamifiedHeader(DashboardData dashboard) {
    final userName = _getUserName(dashboard);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: CustomPaint(
        painter: _DotPatternPainter(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.base, 16, AppSpacing.base, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Hi，$userName 👋',
                  style: AppTypography.primary.h1.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text('${dashboard.streakDays}天',
                      style: AppTypography.primary.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 骨架屏 ───────────────────────────────────────────────

  Widget _buildSkeleton() => Padding(
    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16),
    child: const EHSkeletonList(itemCount: 4),
  );

  // ─── 可滚动内容 ───────────────────────────────────────────

  Widget _buildScrollableContent(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    final userName = _getUserName(dashboard);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.base,
        bottom: AppSpacing.xxl,
        left: AppSpacing.base,
        right: AppSpacing.base,
      ),
      child: Column(
        children: [
          // 玻璃拟态顶栏问候
          if (isGlass) ...[
            _buildGlassTopBar(userName),
            SizedBox(height: AppSpacing.base),
          ],
          // 打卡条
          _buildStreakCard(ext, isGlass, dashboard),
          SizedBox(height: AppSpacing.base),
          // 今日任务
          _buildTaskCard(ext, isGlass, dashboard),
          SizedBox(height: AppSpacing.base),
          // 统计
          _buildStatsRow(ext, isGlass, dashboard),
          SizedBox(height: AppSpacing.base),
          // 薄弱知识点
          _buildKnowledgeSection(ext, isGlass, dashboard),
          SizedBox(height: AppSpacing.base),
          // 周打卡
          _buildWeekCard(ext, isGlass, dashboard),
        ],
      ),
    );
  }

  // ─── 玻璃拟态顶栏 ─────────────────────────────────────────

  Widget _buildGlassTopBar(String userName) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Hi，$userName 👋',
            style: AppTypography.primary.h1.copyWith(
              color: Colors.white, fontSize: 22,
            ),
          ),
        ),
        _glassIcon(Icons.cloud_done_rounded),
        const SizedBox(width: 10),
        _glassIcon(Icons.notifications_outlined, showBadge: true),
      ],
    );
  }

  Widget _glassIcon(IconData icon, {bool showBadge = false}) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          if (showBadge)
            Positioned(
              right: 6, top: 6,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF667EEA), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 打卡条 ───────────────────────────────────────────────

  Widget _buildStreakCard(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: isGlass
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            )
          : BoxDecoration(
              gradient: AppGradients.warm,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.brandSecondaryDark, offset: const Offset(0, 4), blurRadius: 0),
              ],
            ),
      child: Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: isGlass ? 24.0 : 32.0)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('连续打卡',
                  style: TextStyle(
                    color: isGlass ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.85),
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${dashboard.streakDays}',
                        style: TextStyle(
                          color: isGlass ? const Color(0xFFFFB07A) : Colors.white,
                          fontSize: isGlass ? 32 : 36, fontWeight: FontWeight.w800, height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('天',
                        style: TextStyle(
                          color: isGlass ? Colors.white.withOpacity(0.7) : Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isGlass) const Text('🏆', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }

  // ─── 今日任务 ─────────────────────────────────────────────

  Widget _buildTaskCard(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: isGlass
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            )
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                BoxShadow(color: AppColors.brandPrimaryDark, offset: const Offset(0, 4), blurRadius: 0),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isGlass ? Colors.white.withOpacity(0.1) : AppColors.brandPrimaryPale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('📝 今日任务',
              style: TextStyle(
                color: isGlass ? Colors.white.withOpacity(0.7) : AppColors.brandPrimary,
                fontSize: 12, fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${dashboard.pendingReviewCount}',
                  style: TextStyle(
                    color: isGlass ? Colors.white : AppColors.brandPrimary,
                    fontSize: 56, fontWeight: FontWeight.w800, height: 0.85, letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('道错题等你复习',
                    style: TextStyle(
                      color: isGlass ? Colors.white.withOpacity(0.8) : AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 按钮：今日待复习数为 0（今日任务已完成）时变"查看复习"，
          // 拉取今日复习汇总展示真实结果数据（今日复习过则非零，未复习则全零）。
          (() {
            final done = dashboard.pendingReviewCount == 0;
            return GestureDetector(
              onTap: () async {
                if (!done) {
                  context.go(Routes.review);
                  return;
                }
                final report = await sl<ReviewRepository>().getTodaySummary();
                if (!context.mounted) return;
                context.go(Routes.reviewReport, extra: report);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isGlass ? null : [
                    BoxShadow(color: AppColors.brandPrimaryDark, offset: const Offset(0, 4), blurRadius: 0),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      done ? Icons.menu_book_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(done ? '查看复习' : '开始复习',
                      style: AppTypography.primary.button.copyWith(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })(),
        ],
      ),
    );
  }

  // ─── 统计行 ───────────────────────────────────────────────

  Widget _buildStatsRow(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    final eliminationDisplay = (dashboard.eliminationRate / 100 * 100).toStringAsFixed(0);
    // (值, 标签, 文本色, 背景色, 跳转tab)
    final items = [
      ('${dashboard.totalQuestions}', '累计错题', AppColors.textPrimary, const Color(0xFFFFB74D), 'all'),
      ('${dashboard.masteredCount}', '已消灭', AppColors.success, const Color(0xFF81C784), 'mastered'),
      ('$eliminationDisplay%', '消灭率', AppColors.brandSecondary, const Color(0xFFCE93D8), null),
    ];

    return Row(
      children: items.map((item) {
        final tapRoute = item.$5 == null
            ? null
            : '${Routes.questions}?tab=${item.$5}';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == items.last ? 0 : AppSpacing.sm),
            child: GestureDetector(
              onTap: tapRoute == null ? null : () => context.go(tapRoute),
              child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: isGlass
                  ? BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    )
                  : BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        BoxShadow(color: AppColors.border, offset: const Offset(0, 3), blurRadius: 0),
                      ],
                    ),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.$1,
                      style: TextStyle(
                        color: isGlass ? item.$4 : item.$3,
                        fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.$2,
                    style: TextStyle(
                      color: isGlass ? Colors.white.withOpacity(0.6) : AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              ), // GestureDetector
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── 薄弱知识点 ───────────────────────────────────────────

  Widget _buildKnowledgeSection(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    final weakItems = dashboard.weakKnowledge;
    // 知识点颜色循环列表
    const kpColors = [AppColors.errorKnowledge, AppColors.errorSkill, AppColors.errorPsychology];
    final maxError = weakItems.isNotEmpty
        ? weakItems.map((e) => e.count).reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: isGlass
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            )
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                BoxShadow(color: AppColors.border, offset: const Offset(0, 3), blurRadius: 0),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isGlass ? Colors.white.withOpacity(0.1) : const Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, size: 16,
                  color: isGlass ? Colors.white.withOpacity(0.7) : AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Text('薄弱知识点',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: isGlass ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (weakItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('暂无薄弱知识点，继续保持！💪',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: isGlass ? Colors.white.withOpacity(0.6) : AppColors.textTertiary,
                ),
              ),
            )
          else
            ...weakItems.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final color = kpColors[i % kpColors.length];
              final kpRoute = (item.id == null || item.id!.isEmpty)
                  ? null
                  : '${Routes.questions}?kp=${item.id}';
              return GestureDetector(
                onTap: kpRoute == null ? null : () => context.go(kpRoute),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < weakItems.length - 1 ? 12 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: isGlass ? Colors.white.withOpacity(0.9) : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxError > 0 ? item.count / maxError : 0,
                              minHeight: 8,
                              backgroundColor: isGlass
                                  ? Colors.white.withOpacity(0.1)
                                  : color.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${item.count}题',
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── 周打卡 ───────────────────────────────────────────────

  Widget _buildWeekCard(AppThemeExtension ext, bool isGlass, DashboardData dashboard) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    // 使用后端返回的本周打卡数据（周一至周日）；未返回的天视为未打卡
    final weeklyFromApi = dashboard.weeklyCompleted;
    final completed = List.generate(7, (i) {
      if (i < weeklyFromApi.length) return weeklyFromApi[i];
      return false;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: isGlass
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            )
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                BoxShadow(color: AppColors.border, offset: const Offset(0, 3), blurRadius: 0),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isGlass ? Colors.white.withOpacity(0.1) : AppColors.brandPrimaryPale,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_today_rounded, size: 16,
                  color: isGlass ? Colors.white.withOpacity(0.7) : AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('本周打卡',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: isGlass ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              Text('${completed.where((d) => d).length}/7',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: isGlass ? Colors.white.withOpacity(0.6) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isDone = completed[i];
              final isToday = i == today - 1;
              return Column(
                children: [
                  Text(labels[i],
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isToday
                          ? (isGlass ? Colors.white : AppColors.brandPrimary)
                          : (isGlass ? Colors.white.withOpacity(0.5) : AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDone ? AppGradients.success : null,
                      color: isDone ? null
                          : (isToday
                              ? (isGlass ? Colors.white.withOpacity(0.1) : AppColors.brandPrimaryPale)
                              : (isGlass ? Colors.white.withOpacity(0.05) : const Color(0xFFF2F2F7))),
                      border: isToday && !isDone
                          ? Border.all(color: isGlass ? Colors.white : AppColors.brandPrimary, width: 2.5)
                          : isDone ? null : Border.all(
                              color: isGlass ? Colors.white.withOpacity(0.1) : AppColors.border, width: 1.5),
                      boxShadow: isDone && !isGlass
                          ? [BoxShadow(color: AppColors.successDark, offset: const Offset(0, 3), blurRadius: 0)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : isToday
                            ? Text('$today',
                                style: TextStyle(
                                  color: isGlass ? Colors.white : AppColors.brandPrimary,
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── 波点图案绘制器 ───────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
