/// 错题猎手 - P5 错题列表页
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/cards/question_card.dart';
import '../../../widgets/common/chips/filter_chip.dart';
import '../../../widgets/common/empty_states/no_questions_empty.dart';
import '../../../widgets/common/inputs/search_bar.dart';
import '../../../widgets/common/loading/skeleton_list.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import '../models/question_model.dart';
import '../widgets/review_progress_bar.dart';

/// 错题列表页
class QuestionListPage extends StatefulWidget {
  const QuestionListPage({super.key});

  @override
  State<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearchMode = false;
  final _searchController = TextEditingController();

  // Filter state
  ErrorCategory? _filterCategory;
  String? _filterKnowledgePoint;

  /// 是否有任意筛选条件不为默认值
  bool get _hasActiveFilters =>
      _filterCategory != null || _filterKnowledgePoint != null;

  /// 一键重置所有筛选条件
  void _resetFilters() {
    setState(() {
      _filterCategory = null;
      _filterKnowledgePoint = null;
    });
    context.read<QuestionBloc>().add(const LoadQuestions(refresh: true));
  }

  static const _statusTabs = [
    null, // 全部
    QuestionStatus.notStarted,
    QuestionStatus.reviewing,
    QuestionStatus.mastered,
  ];

  static const _tabLabels = ['全部', '未掌握', '复习中', '已消灭'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuestionBloc>().add(const LoadQuestions(refresh: true));
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final status = _statusTabs[_tabController.index];
    context.read<QuestionBloc>().add(FilterByStatus(status));
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        context.read<QuestionBloc>().add(const LoadQuestions(refresh: true));
      }
    });
  }

  void _onSearch(String keyword) {
    context.read<QuestionBloc>().add(SearchQuestions(keyword));
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearchMode
            ? EHSearchBar(
                controller: _searchController,
                autoFocus: true,
                onChanged: _onSearch,
                onClear: () {
                  context.read<QuestionBloc>().add(const LoadQuestions(refresh: true));
                },
              )
            : Text(
                '错题本',
                style: AppTypography.primary.h2.copyWith(
                  color: tc.primary,
                ),
              ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.base),
            child: GestureDetector(
              onTap: _toggleSearch,
              child: Icon(
                _isSearchMode ? Icons.close_rounded : Icons.search_rounded,
                color: tc.secondary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status tabs (horizontal scroll)
          if (!_isSearchMode) _buildStatusTabs(),
          // Filter bar
          if (!_isSearchMode) _buildFilterBar(),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final tc = context.textColors;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.brandPrimary,
        unselectedLabelColor: tc.secondary,
        labelStyle: AppTypography.primary.button,
        unselectedLabelStyle: AppTypography.primary.body,
        indicatorColor: AppColors.brandPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
      ),
    );
  }

  Widget _buildFilterBar() {
    final tc = context.textColors;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterDropdown(
              label: '错因',
              icon: Icons.filter_list_rounded,
              selectedValue: _filterCategory != null
                  ? ErrorCategory.fromCode(_filterCategory!.code).shortLabel
                  : null,
              items: const [
                DropdownMenuItem(value: null, child: Text('全部')),
                DropdownMenuItem(
                    value: ErrorCategory.knowledge, child: Text('🧠 知识性')),
                DropdownMenuItem(
                    value: ErrorCategory.skill, child: Text('✏️ 技能性')),
                DropdownMenuItem(
                    value: ErrorCategory.psychology, child: Text('😰 心理性')),
                DropdownMenuItem(
                    value: ErrorCategory.habit, child: Text('📖 习惯性')),
              ],
              onChanged: (v) {
                setState(() => _filterCategory = v as ErrorCategory?);
                context.read<QuestionBloc>().add(FilterByCategory(v as ErrorCategory?));
              },
            ),
            SizedBox(width: AppSpacing.sm),
            _FilterDropdown(
              label: '知识点',
              icon: Icons.bookmark_outline,
              selectedValue: _filterKnowledgePoint,
              items: const [
                DropdownMenuItem(value: null, child: Text('全部')),
                DropdownMenuItem(value: 'kp01', child: Text('四则运算')),
                DropdownMenuItem(value: 'kp02', child: Text('运算顺序')),
                DropdownMenuItem(value: 'kp03', child: Text('分数化简')),
              ],
              onChanged: (v) {
                setState(() => _filterKnowledgePoint = v as String?);
                context
                    .read<QuestionBloc>()
                    .add(FilterByKnowledgePoint(v as String?));
              },
            ),
            SizedBox(width: AppSpacing.sm),
            _FilterDropdown(
              label: '时间',
              icon: Icons.access_time_rounded,
              selectedValue: null,
              items: const [
                DropdownMenuItem(value: null, child: Text('全部')),
                DropdownMenuItem(value: 'today', child: Text('今天')),
                DropdownMenuItem(value: 'week', child: Text('本周')),
                DropdownMenuItem(value: 'month', child: Text('本月')),
              ],
              onChanged: (_) {
                // TODO: BLoC 尚不支持时间筛选事件，待后续实现
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('时间筛选即将上线'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            // Bug #27: 一键重置按钮
            if (_hasActiveFilters) ...[
              SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _resetFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        '重置',
                        style: AppTypography.primary.caption.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return BlocBuilder<QuestionBloc, QuestionState>(
      builder: (context, state) {
        if (state is QuestionListLoading) {
          return const EHSkeletonList(itemCount: 6);
        }

        if (state is QuestionListLoaded) {
          if (state.questions.isEmpty) {
            return EHNoQuestionsEmpty(
              onAddQuestion: () => context.go(Routes.addQuestion),
            );
          }
          return RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: () async {
              context.read<QuestionBloc>().add(const LoadQuestions(refresh: true));
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.pagePadding.copyWith(
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl,
              ),
              // Bug #46: +1 for load-more or end-of-list indicator
              itemCount: state.questions.length + 1,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= state.questions.length) {
                  // Bug #46: Show end-of-list indicator when no more data
                  if (!state.hasMore) {
                    return _buildEndOfList();
                  }
                  // Load more trigger
                  return _buildLoadMore(state);
                }
                return _buildQuestionItem(state.questions[index]);
              },
            ),
          );
        }

        if (state is QuestionError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                SizedBox(height: AppSpacing.sm),
                Text(state.message, style: AppTypography.primary.body),
                SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: () => context
                      .read<QuestionBloc>()
                      .add(const LoadQuestions(refresh: true)),
                  child: Text('点击重试',
                      style: AppTypography.primary.button
                          .copyWith(color: AppColors.brandPrimary)),
                ),
              ],
            ),
          );
        }

        // Initial state - show skeleton (load already triggered in initState)
        return const EHSkeletonList(itemCount: 6);
      },
    );
  }

  Widget _buildQuestionItem(QuestionModel question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EHQuestionCard(
          data: EHQuestionCardData(
            id: question.id,
            subject: question.subject,
            title: question.ocrText ?? '无文字内容',
            thumbnailUrl: question.imageUrl.isEmpty ? null : question.imageUrl,
            errorCategory: question.errorCategory.code,
            status: question.status.code,
            createdAt: question.createdAt,
            reviewCount: question.currentReviewRound,
          ),
          onTap: () => context.go('${Routes.questions}/${question.id}'),
        ),
        // Micro progress bar
        if (question.currentReviewRound > 0)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
            child: ReviewProgressBar(
              currentRound: question.currentReviewRound,
              totalRounds: question.totalReviewRounds,
              height: 4,
              showLabel: false,
            ),
          ),
      ],
    );
  }

  /// Bug #46: 列表底部"已经到底了"提示
  Widget _buildEndOfList() {
    final tc = context.textColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          '— 已经到底了 —',
          style: AppTypography.primary.caption.copyWith(
            color: tc.tertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore(QuestionListLoaded state) {
    final tc = context.textColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Center(
        child: GestureDetector(
          onTap: () {
            context.read<QuestionBloc>().add(LoadQuestions(
                  page: state.currentPage + 1,
                  status: state.filterStatus,
                  category: state.filterCategory,
                ));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '加载更多...',
                style: AppTypography.primary.caption.copyWith(
                  color: tc.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 筛选下拉组件
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    this.selectedValue,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final Object? selectedValue;
  final List<DropdownMenuItem<Object?>> items;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return PopupMenuButton<Object?>(
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => items
          .map((item) => PopupMenuItem<Object?>(
                value: item.value,
                child: item.child ?? const SizedBox.shrink(),
              ))
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selectedValue != null
              ? AppColors.brandPrimary.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selectedValue != null
                ? AppColors.brandPrimary
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: selectedValue != null
                    ? AppColors.brandPrimary
                    : tc.secondary),
            SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.primary.caption.copyWith(
                color: selectedValue != null
                    ? AppColors.brandPrimary
                    : tc.secondary,
                fontWeight:
                    selectedValue != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16,
                color: selectedValue != null
                    ? AppColors.brandPrimary
                    : tc.tertiary),
          ],
        ),
      ),
    );
  }
}
