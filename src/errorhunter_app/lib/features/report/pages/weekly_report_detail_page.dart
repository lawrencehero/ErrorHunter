/// 错题猎手 - P10 周报详情页
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/buttons/secondary_button.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/chips/error_category_chip.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../../../widgets/common/divider.dart';
import '../../../widgets/common/loading/loading_spinner.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';
import '../models/weekly_report_model.dart';
import '../widgets/report_achievement_list.dart';
import '../widgets/report_stat_grid.dart';

/// 周报详情页
class WeeklyReportDetailPage extends StatefulWidget {
  const WeeklyReportDetailPage({super.key, required this.reportId});

  final String reportId;

  @override
  State<WeeklyReportDetailPage> createState() => _WeeklyReportDetailPageState();
}

class _WeeklyReportDetailPageState extends State<WeeklyReportDetailPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<ReportBloc>()
        .add(LoadWeeklyReportDetail(widget.reportId));
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        if (state is ReportLoading) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(null),
            body: const Center(child: EHLoadingSpinner()),
          );
        }
        if (state is WeeklyReportDetailLoaded) {
          return _buildContent(state.report);
        }
        if (state is ReportError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(null),
            body: Center(
              child: Text(state.message,
                  style: AppTypography.primary.body
                      .copyWith(color: tc.secondary)),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(null),
          body: const SizedBox.shrink(),
        );
      },
    );
  }

  AppBar _buildAppBar(WeeklyReportModel? report) {
    final tc = context.textColors;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        report != null ? '第${report.summary.weekNumber}周周报' : '周报详情',
        style: AppTypography.primary.h3.copyWith(
          color: tc.primary,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded, size: 22),
          onPressed: () {
            EHToast.show(context,
                message: '分享功能开发中...', type: EHToastType.info);
          },
        ),
      ],
    );
  }

  Widget _buildContent(WeeklyReportModel report) {
    final tc = context.textColors;
    final dateRange =
        '${report.summary.startDate.month}/${report.summary.startDate.day} - ${report.summary.endDate.month}/${report.summary.endDate.day}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(report),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期范围
            Center(
              child: Container(
                margin: EdgeInsets.only(bottom: AppSpacing.base),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withOpacity(0.08),
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Text(
                  '📅 $dateRange',
                  style: AppTypography.primary.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // ─── 四宫格统计 ──────────────────────────────
            ReportStatGrid(
              newCount: report.summary.newCount,
              newVsLastWeek: report.newCountVsLastWeek,
              eliminatedCount: report.summary.eliminatedCount,
              eliminatedVsLastWeek: report.eliminatedCountVsLastWeek,
              reviewCount: report.summary.reviewCount,
              reviewVsLastWeek: report.reviewCountVsLastWeek,
              accuracyRate: report.accuracyRate,
              accuracyVsLastWeek: report.accuracyRateVsLastWeek,
            ),

            SizedBox(height: AppSpacing.lg),

            // ─── 本周成就 ────────────────────────────────
            ReportAchievementList(achievements: report.achievements),

            SizedBox(height: AppSpacing.lg),

            // ─── 重点关注知识点 Top3 ─────────────────────
            EHBaseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📚 ', style: TextStyle(fontSize: 18)),
                      Text(
                        '重点关注知识点',
                        style: AppTypography.primary.h3.copyWith(
                          color: tc.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  ...report.topKnowledgePoints.asMap().entries.map((entry) {
                    final kp = entry.value;
                    final medals = ['🥇', '🥈', '🥉'];
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Text(medals[kp.rank - 1] ?? '',
                              style: const TextStyle(fontSize: 20)),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              kp.name,
                              style: AppTypography.primary.body.copyWith(
                                color: tc.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${kp.errorCount}道错题',
                            style: AppTypography.primary.caption.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            // ─── 本周最多错因 ────────────────────────────
            EHBaseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🏷️ ', style: TextStyle(fontSize: 18)),
                      Text(
                        '本周最多错因',
                        style: AppTypography.primary.h3.copyWith(
                          color: tc.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      EHErrorCategoryChip(
                        category: report.mostFrequentErrorCategory,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        '${report.mostFrequentErrorPercentage.toStringAsFixed(1)}%',
                        style: AppTypography.primary.h2.copyWith(
                          color: AppColors.errorCategoryColor(
                            report.mostFrequentErrorCategory,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        '的错题属于此类型',
                        style: AppTypography.primary.caption.copyWith(
                          color: tc.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.xl),
            const EHDivider(),
            SizedBox(height: AppSpacing.base),

            // ─── 分享按钮组 ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: EHPrimaryButton(
                    text: '📤 分享周报',
                    onPressed: () {
                      EHToast.show(context,
                          message: '分享功能开发中...', type: EHToastType.info);
                    },
                    fullWidth: true,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: EHSecondaryButton(
                    text: '👨‍👩‍👧 家长版',
                    onPressed: () {
                      EHToast.show(context,
                          message: '家长版包含学习建议模块，即将上线',
                          type: EHToastType.info);
                    },
                    fullWidth: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
