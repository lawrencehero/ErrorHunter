/// 错题猎手 - P10 周报列表页
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/loading/loading_spinner.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';
import '../models/weekly_report_model.dart';

/// 学情周报列表页
class WeeklyReportListPage extends StatefulWidget {
  const WeeklyReportListPage({super.key});

  @override
  State<WeeklyReportListPage> createState() => _WeeklyReportListPageState();
}

class _WeeklyReportListPageState extends State<WeeklyReportListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ReportBloc>().add(const LoadWeeklyReports());
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '学情周报',
          style: AppTypography.primary.h3.copyWith(
            color: tc.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<ReportBloc, ReportState>(
        builder: (context, state) {
          if (state is ReportLoading) {
            return const Center(child: EHLoadingSpinner());
          }
          if (state is ReportError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  SizedBox(height: AppSpacing.sm),
                  Text(state.message,
                      style: AppTypography.primary.body
                          .copyWith(color: tc.secondary)),
                ],
              ),
            );
          }
          if (state is WeeklyReportsLoaded) {
            return _buildList(state.reports);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildList(List<WeeklySummary> reports) {
    return ListView.separated(
      padding: AppSpacing.pagePadding.copyWith(
        top: AppSpacing.base,
        bottom: AppSpacing.xxl,
      ),
      itemCount: reports.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final report = reports[index];
        return _ReportCard(report: report);
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final WeeklySummary report;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final dateRange =
        '${report.startDate.month}/${report.startDate.day} - ${report.endDate.month}/${report.endDate.day}';

    return EHBaseCard(
      onTap: () => context.push(
        Routes.weeklyReportDetail.replaceAll(':id', report.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('📊 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  '第${report.weekNumber}周周报',
                  style: AppTypography.primary.h3.copyWith(
                    color: tc.primary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: tc.tertiary),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          // 日期范围
          Text(
            dateRange,
            style: AppTypography.primary.caption.copyWith(
              color: tc.secondary,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          // 统计摘要
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: '新增',
                  value: '${report.newCount}',
                  color: AppColors.brandPrimary,
                ),
                _buildDivider(),
                _StatItem(
                  label: '消灭',
                  value: '${report.eliminatedCount}',
                  color: AppColors.success,
                ),
                _buildDivider(),
                _StatItem(
                  label: '复习',
                  value: '${report.reviewCount}次',
                  color: AppColors.brandSecondary,
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          // 查看详情链接
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '查看详情 →',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 0.5,
      height: 24,
      color: AppColors.border,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.primary.h3.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.primary.caption.copyWith(
            color: tc.secondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
