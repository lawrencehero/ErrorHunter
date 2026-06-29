/// 错题猎手 - P5 错题列表页
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/knowledge_point_repository.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../widgets/common/cards/question_card.dart';
import '../../../widgets/common/chips/filter_chip.dart';
import '../../../widgets/common/empty_states/no_questions_empty.dart';
import '../../../widgets/common/inputs/search_bar.dart';
import '../../../widgets/common/loading/skeleton_list.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import '../models/knowledge_point_model.dart';
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

  // 知识点下拉项（按年级从后端拉取）
  List<KnowledgePoint> _knowledgePoints = const [];
  bool _kpLoading = true;

  /// 是否有任意筛选条件不为默认值
  bool get _hasActiveFilters =>
      _filterCategory != null || _filterKnowledgePoint != null;

  /// 一键重置所有筛选条件
  void _resetFilters() {
    setState(() {
      _filterCategory = null;
      _filterKnowledgePoint = null;
    });
    _tabController.removeListener(_onTabChanged);
    _tabController.index = 0;
    _tabController.addListener(_onTabChanged);
    _dispatchLoad(status: null);
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
      _loadKnowledgePoints();
      _applyDeepLink();
    });
  }

  /// 读取路由 query 参数（tab / kp）并应用为初始筛选
  void _applyDeepLink() {
    final qp = GoRouterState.of(context).uri.queryParameters;
    final tab = qp['tab'];
    final kp = qp['kp'];

    int tabIndex = 0;
    switch (tab) {
      case 'notStarted':
        tabIndex = 1;
        break;
      case 'reviewing':
        tabIndex = 2;
        break;
      case 'mastered':
        tabIndex = 3;
        break;
      default:
        tabIndex = 0;
    }

    if (kp != null && kp.isNotEmpty) {
      setState(() => _filterKnowledgePoint = kp);
    }

    if (tabIndex != 0) {
      _tabController.removeListener(_onTabChanged);
      _tabController.index = tabIndex;
      _tabController.addListener(_onTabChanged);
    }

    // 全量加载（各 tab 客户端按 status 过滤），tab 参数仅用于设置初始视觉位置
    _dispatchLoad(status: null);
  }

  /// 按当前所有筛选条件加载错题
  void _dispatchLoad({QuestionStatus? status, int page = 1, bool refresh = true}) {
    context.read<QuestionBloc>().add(LoadQuestions(
          status: status,
          category: _filterCategory,
          knowledgePointId: _filterKnowledgePoint,
          page: page,
          refresh: refresh,
        ));
  }

  /// 加载当前年级的知识点（用于知识点下拉）
  Future<void> _loadKnowledgePoints() async {
    final authState = context.read<AuthBloc>().state;
    final grade = authState is Authenticated ? authState.user.grade : '';
    if (grade.isEmpty) {
      if (mounted) setState(() => _kpLoading = false);
      return;
    }
    try {
      final points = await sl<KnowledgePointRepository>().getByGrade(grade: grade);
      if (!mounted) return;
      setState(() {
        _knowledgePoints = points;
        _kpLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _kpLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // 切 tab 不发网络请求：各 tab 已客户端按 status 过滤，
    // 指示器/动画由 TabBar + TabBarView 经 controller 自动处理。
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
    final isGlass = context.themeExt.headerStyle == HeaderStyle.transparent;
    final accentColor = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: accentColor,
        unselectedLabelColor: tc.secondary,
        labelStyle: AppTypography.primary.button,
        unselectedLabelStyle: AppTypography.primary.body,
        indicatorColor: accentColor,
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
        AppSpacing.sm,
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
                _dispatchLoad(status: null);
              },
            ),
            SizedBox(width: AppSpacing.sm),
            _FilterDropdown(
              label: '知识点',
              icon: Icons.bookmark_outline,
              selectedValue: (_knowledgePoints.any((kp) => kp.id == _filterKnowledgePoint))
                  ? _filterKnowledgePoint
                  : null,
              items: [
                const DropdownMenuItem(value: null, child: Text('全部')),
                if (_kpLoading)
                  const DropdownMenuItem(
                    enabled: false,
                    value: '__loading',
                    child: Text('加载中...'),
                  ),
                ..._knowledgePoints.map(
                  (kp) => DropdownMenuItem(value: kp.id, child: Text(kp.name)),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterKnowledgePoint = v as String?);
                _dispatchLoad(status: null);
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
    // BlocBuilder 下沉到每个 tab child：state 变化只重建各 tab 内容，
    // 不重建 TabBarView 本身 → 消除滑动动画被打断导致的抖动/滑动失效。
    return TabBarView(
      controller: _tabController,
      children: [
        for (final status in _statusTabs)
          BlocBuilder<QuestionBloc, QuestionState>(
            builder: (context, state) =>
                _QuestionTabBody(state: state, tabStatus: status),
          ),
      ],
    );
  }
}

/// 单个 tab 页内容（带 keep-alive，避免切 tab 时子页被 dispose，保住滚动位置/手势状态）。
class _QuestionTabBody extends StatefulWidget {
  const _QuestionTabBody({required this.state, required this.tabStatus});

  final QuestionState state;
  /// 该 tab 对应的 status 过滤值；null 表示「全部」不过滤。
  final QuestionStatus? tabStatus;

  @override
  State<_QuestionTabBody> createState() => _QuestionTabBodyState();
}

class _QuestionTabBodyState extends State<_QuestionTabBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = widget.state;
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;

    if (state is QuestionListLoading) {
      return const EHSkeletonList(itemCount: 6);
    }

    if (state is QuestionListLoaded) {
      // 客户端按 tab status 过滤（tabStatus==null 即「全部」不过滤）。
      final filtered = widget.tabStatus == null
          ? state.questions
          : state.questions
              .where((q) => q.status == widget.tabStatus)
              .toList(growable: false);
      // 空态判断基于「过滤后」的 list。
      if (filtered.isEmpty) {
        return EHNoQuestionsEmpty(
          onAddQuestion: () => context.go(Routes.addQuestion),
        );
      }
      return RefreshIndicator(
        color: accentColor,
        onRefresh: () async {
          // 下拉刷新全量（status: null），各 tab 自行客户端过滤。
          context.read<QuestionBloc>().add(
                const LoadQuestions(refresh: true),
              );
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pagePadding.copyWith(
            top: AppSpacing.sm,
            bottom: AppSpacing.xxl,
          ),
          itemCount: filtered.length + 1,
          separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            if (index >= filtered.length) {
              if (!state.hasMore) {
                return _buildEndOfList();
              }
              return _buildLoadMore(state);
            }
            return _buildQuestionItem(filtered[index]);
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
            Text(state.message,
                style: AppTypography.primary.body.copyWith(color: tc.primary)),
            SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () => context
                  .read<QuestionBloc>()
                  .add(const LoadQuestions(refresh: true)),
              child: Text('点击重试',
                  style: AppTypography.primary.button
                      .copyWith(color: accentColor)),
            ),
          ],
        ),
      );
    }

    return const EHSkeletonList(itemCount: 6);
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
          // 用 push 而非 go：详情页 AppBar 返回/系统返回手势能回到列表，
          // 且 ShellRoute 的 PopScope 不会把返回重定向到首页。
          onTap: () => context.push('${Routes.questions}/${question.id}'),
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
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Center(
        child: GestureDetector(
          onTap: () {
            // 加载更多：全量（status: null），仅按 category/kp 服务端筛选；hasMore 逻辑不变。
            context.read<QuestionBloc>().add(LoadQuestions(
                  page: state.currentPage + 1,
                  status: null,
                  category: state.filterCategory,
                  knowledgePointId: state.filterKnowledgePoint,
                  refresh: false,
                ));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more_rounded,
                  size: 18, color: accentColor),
              SizedBox(width: AppSpacing.xs),
              Text(
                '点击加载更多',
                style: AppTypography.primary.caption.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
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
    final isGlass = context.themeExt.headerStyle == HeaderStyle.transparent;
    final accentColor = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;

    return PopupMenuButton<Object?>(
      onSelected: onChanged,
      offset: const Offset(0, 36),
      color: isGlass ? const Color(0xFF2D2D3A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => items
          .map((item) => PopupMenuItem<Object?>(
                value: item.value,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: isGlass ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  child: item.child ?? const SizedBox.shrink(),
                ),
              ))
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selectedValue != null
              ? accentColor.withOpacity(isGlass ? 0.2 : 0.1)
              : (isGlass ? Colors.white.withOpacity(0.12) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selectedValue != null
                ? accentColor
                : (isGlass ? Colors.white.withOpacity(0.2) : AppColors.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: selectedValue != null
                    ? accentColor
                    : tc.secondary),
            SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.primary.caption.copyWith(
                color: selectedValue != null
                    ? accentColor
                    : tc.secondary,
                fontWeight:
                    selectedValue != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16,
                color: selectedValue != null
                    ? accentColor
                    : tc.tertiary),
          ],
        ),
      ),
    );
  }
}
