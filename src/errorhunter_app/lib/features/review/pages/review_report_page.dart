/// 错题猎手 - P7b 复习报告页
/// 复习完成后展示统计数据和连续打卡天数
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/buttons/text_button.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../report/bloc/report_bloc.dart';
import '../../report/bloc/report_event.dart';
import '../models/review_report_model.dart';

/// 复习报告页
class ReviewReportPage extends StatelessWidget {
  const ReviewReportPage({super.key, required this.report});

  final ReviewReportModel report;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    // 玻璃拟态下背景为深色渐变，需切换强调色与文字色保证对比度。
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    final streakColor =
        isGlass ? const Color(0xFFFFAB91) : AppColors.brandSecondary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              // ─── 顶部标题 ──────────────────────────────
              SizedBox(height: AppSpacing.lg),
              Text(
                '🎉',
                style: TextStyle(fontSize: 56),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                '复习完成！',
                style: AppTypography.primary.h1.copyWith(
                  color: tc.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                '今天的努力，明天的进步 💪',
                style: AppTypography.primary.body.copyWith(
                  color: tc.secondary,
                ),
              ),

              SizedBox(height: AppSpacing.xxl),

              // ─── 统计卡片 ──────────────────────────────
              EHBaseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 今日复习总数
                    _StatRow(
                      emoji: '📚',
                      label: '今日复习',
                      value: '${report.totalCount} 道',
                      color: accent,
                      isGlass: isGlass,
                    ),

                    Divider(
                        height: AppSpacing.lg * 2,
                        color: isGlass
                            ? Colors.white.withOpacity(0.15)
                            : AppColors.border),

                    // 完全掌握
                    _StatRow(
                      emoji: '😄',
                      label: '完全掌握',
                      value: '${report.masteredCount} 道',
                      color: isGlass ? const Color(0xFF81C784) : AppColors.success,
                      isGlass: isGlass,
                    ),

                    SizedBox(height: AppSpacing.md),

                    // 部分记得
                    _StatRow(
                      emoji: '🤔',
                      label: '部分记得',
                      value: '${report.partialCount} 道',
                      color: isGlass ? const Color(0xFFFFB74D) : AppColors.warning,
                      isGlass: isGlass,
                    ),

                    SizedBox(height: AppSpacing.md),

                    // 完全不会
                    _StatRow(
                      emoji: '😵',
                      label: '完全不会',
                      value: '${report.forgotCount} 道',
                      color: isGlass ? const Color(0xFFEF9A9A) : AppColors.danger,
                      isGlass: isGlass,
                    ),

                    Divider(
                        height: AppSpacing.lg * 2,
                        color: isGlass
                            ? Colors.white.withOpacity(0.15)
                            : AppColors.border),

                    // 用时（< 60 秒显示"X 秒"，避免短复习显示"0 分钟"）
                    _StatRow(
                      emoji: '⏱️',
                      label: '用时',
                      value: report.formattedDuration,
                      color: isGlass ? tc.secondary : AppColors.textSecondary,
                      isGlass: isGlass,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.base),

              // ─── 连续打卡 ──────────────────────────────
              if (report.streakDays > 0)
                EHBaseCard(
                  backgroundColor: (isGlass ? Colors.white : AppColors.brandSecondary)
                      .withOpacity(isGlass ? 0.12 : 0.08),
                  border: Border.all(
                    color: (isGlass ? Colors.white : AppColors.brandSecondary)
                        .withOpacity(isGlass ? 0.25 : 0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 28)),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        '连续打卡 ${report.streakDays} 天',
                        style: AppTypography.primary.h3.copyWith(
                          color: streakColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

              // 消灭数量（如有）
              if (report.eliminatedCount > 0) ...[
                SizedBox(height: AppSpacing.base),
                EHBaseCard(
                  backgroundColor: (isGlass ? Colors.white : AppColors.success)
                      .withOpacity(isGlass ? 0.12 : 0.08),
                  border: Border.all(
                    color: (isGlass ? Colors.white : AppColors.success)
                        .withOpacity(isGlass ? 0.25 : 0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('✅', style: TextStyle(fontSize: 28)),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        '本轮消灭 ${report.eliminatedCount} 道错题！',
                        style: AppTypography.primary.h3.copyWith(
                          color: isGlass ? const Color(0xFF81C784) : AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: AppSpacing.xxxl),

              // ─── 操作按钮 ──────────────────────────────
              EHPrimaryButton(
                text: '返回首页',
                onPressed: () {
                  // 复习完成后刷新首页 dashboard（连续打卡/本周打卡/待复习数），
                  // 否则回首页看到的仍是复习前的旧数据。
                  context.read<ReportBloc>().add(const LoadDashboard());
                  context.go(Routes.home);
                },
                size: EHButtonSize.lg,
                fullWidth: true,
              ),

              SizedBox(height: AppSpacing.md),

              EHTextButton(
                text: '分享复习报告',
                icon: Icons.share_outlined,
                onPressed: () {
                  // TODO: 实现分享功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('分享功能开发中...')),
                  );
                },
                size: EHButtonSize.lg,
              ),

              SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统计行组件
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.isGlass = false,
  });

  final String emoji;
  final String label;
  final String value;
  final Color color;
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 24)),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTypography.primary.body.copyWith(
              color: tc.secondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.primary.h3.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
