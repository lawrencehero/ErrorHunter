/// 错题猎手 - 首页 Dashboard V4.0 (多主题支持)
/// 根据 ThemeManager 当前主题自动切换游戏化/玻璃拟态风格
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/loading/skeleton_list.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;

  final int _streakDays = 12;
  final int _pendingReviewCount = 8;
  final int _totalQuestions = 156;
  final int _eliminatedCount = 98;
  final double _eliminationRate = 0.628;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String get _userName {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) return state.user.nickname;
    return '同学';
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? _buildSkeleton()
          : isGlass
              ? _buildScrollableContent(ext, isGlass)
              : _buildGamifiedLayout(ext),
    );
  }

  // ─── 游戏化布局：固定蓝色背景+问候语，卡片从下方滚出 ────────

  Widget _buildGamifiedLayout(AppThemeExtension ext) {
    return Stack(
      children: [
        // 层1: 蓝色渐变背景（固定，铺满上半部分）
        Positioned(
          left: 0, right: 0, top: 0,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
        ),
        // 层2: 问候语（固定，不随滚动移动）
        Positioned(
          left: AppSpacing.base, right: AppSpacing.base, top: 50,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Hi，$_userName 👋',
                  style: AppTypography.primary.h1.copyWith(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800,
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
                    Text('$_streakDays天',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 层3: 可滚动内容（从蓝色区域下方开始滚动）
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: 110, bottom: 100),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Column(
              children: [
                _buildStreakCard(ext, false),
                SizedBox(height: AppSpacing.base),
                _buildTaskCard(ext, false),
                SizedBox(height: AppSpacing.base),
                _buildStatsRow(ext, false),
                SizedBox(height: AppSpacing.base),
                _buildKnowledgeSection(ext, false),
                SizedBox(height: AppSpacing.base),
                _buildWeekCard(ext, false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 游戏化蓝色顶栏 ───────────────────────────────────────

  Widget _buildGamifiedHeader() {
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
                  'Hi，$_userName 👋',
                  style: AppTypography.primary.h1.copyWith(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800,
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
                    Text('$_streakDays天',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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

  Widget _buildSkeleton() => const Padding(
    padding: EdgeInsets.only(top: 68),
    child: EHSkeletonList(itemCount: 4),
  );

  // ─── 可滚动内容 ───────────────────────────────────────────

  Widget _buildScrollableContent(AppThemeExtension ext, bool isGlass) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Column(
              children: [
                // 玻璃拟态顶栏问候
                if (isGlass) ...[
                  const SizedBox(height: 54),
                  _buildGlassTopBar(),
                  SizedBox(height: AppSpacing.base),
                ],
                // 打卡条
                _buildStreakCard(ext, isGlass),
                SizedBox(height: AppSpacing.base),
                // 今日任务
                _buildTaskCard(ext, isGlass),
                SizedBox(height: AppSpacing.base),
                // 统计
                _buildStatsRow(ext, isGlass),
                SizedBox(height: AppSpacing.base),
                // 薄弱知识点
                _buildKnowledgeSection(ext, isGlass),
                SizedBox(height: AppSpacing.base),
                // 周打卡
                _buildWeekCard(ext, isGlass),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 玻璃拟态顶栏 ─────────────────────────────────────────

  Widget _buildGlassTopBar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Hi，$_userName 👋',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
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

  Widget _buildStreakCard(AppThemeExtension ext, bool isGlass) {
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$_streakDays',
                      style: TextStyle(
                        color: isGlass ? const Color(0xFFFFB07A) : Colors.white,
                        fontSize: isGlass ? 28 : 36, fontWeight: FontWeight.w800, height: 1.0,
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
              ],
            ),
          ),
          if (!isGlass) const Text('🏆', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }

  // ─── 今日任务 ─────────────────────────────────────────────

  Widget _buildTaskCard(AppThemeExtension ext, bool isGlass) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$_pendingReviewCount',
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
          const SizedBox(height: 18),
          // 按钮
          GestureDetector(
            onTap: () => context.go(Routes.review),
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 6),
                  Text('开始复习',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 统计行 ───────────────────────────────────────────────

  Widget _buildStatsRow(AppThemeExtension ext, bool isGlass) {
    final items = [
      ('$_totalQuestions', '累计错题', AppColors.textPrimary),
      ('$_eliminatedCount', '已消灭', AppColors.success),
      ('${(_eliminationRate * 100).toStringAsFixed(0)}%', '消灭率', AppColors.brandSecondary),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == items.last ? 0 : AppSpacing.sm),
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
                  Text(item.$1,
                    style: TextStyle(
                      color: isGlass ? Colors.white : item.$3,
                      fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.0,
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
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── 薄弱知识点 ───────────────────────────────────────────

  Widget _buildKnowledgeSection(AppThemeExtension ext, bool isGlass) {
    final kpItems = [
      ('分数加减法', 12, AppColors.errorKnowledge, '🧠'),
      ('几何面积计算', 8, AppColors.errorSkill, '✏️'),
      ('应用题审题', 6, AppColors.errorPsychology, '😰'),
    ];
    final maxError = 12;

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
          ...kpItems.asMap().entries.map((e) {
            final i = e.key;
            final (name, count, color, emoji) = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < kpItems.length - 1 ? 12 : 0),
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
                        Text(name,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isGlass ? Colors.white.withOpacity(0.9) : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: count / maxError,
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
                  Text('$count题',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 周打卡 ───────────────────────────────────────────────

  Widget _buildWeekCard(AppThemeExtension ext, bool isGlass) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final completed = [true, true, true, false, true, false, false];
    final today = DateTime.now().weekday - 1;

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
              final isToday = i == today;
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
                    child: isDone
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : isToday
                            ? Text('${today + 1}',
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
    const spacing = 16.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
