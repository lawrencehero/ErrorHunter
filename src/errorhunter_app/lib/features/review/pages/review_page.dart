/// 错题猎手 - P7 复习主页面
/// 全屏沉浸模式：翻卡 + 自评 + 滑动手势 + 消灭检测
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';
import '../../../widgets/common/dialogs/snackbar.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../bloc/review_state.dart';
import '../models/review_report_model.dart';
import '../widgets/flip_card_animation.dart';
import '../widgets/revive_check_card.dart';
import '../widgets/review_card_back.dart';
import '../widgets/review_card_front.dart';
import '../widgets/review_progress_bar.dart';
import 'eliminate_animation_page.dart';

/// 复习主页面
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, this.questionIds});

  /// 指定复习的错题ID列表，null 表示由后端推荐
  final List<String>? questionIds;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 进入全屏沉浸模式
    _setImmersiveMode(true);
    // 启动复习会话
    context.read<ReviewBloc>().add(StartReview(questionIds: widget.questionIds));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 退出时恢复系统UI
    _setImmersiveMode(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App 切后台或失去焦点时恢复系统 UI，防止沉浸模式泄漏
        _setImmersiveMode(false);
        break;
      case AppLifecycleState.resumed:
        // App 回到前台时重新设置沉浸模式
        _setImmersiveMode(true);
        break;
      default:
        break;
    }
  }

  /// 设置或取消沉浸模式
  void _setImmersiveMode(bool immersive) {
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmDialog();
      },
      child: BlocConsumer<ReviewBloc, ReviewState>(
        listener: _onStateChanged,
        builder: (context, state) {
          if (state is ReviewLoading) {
            return const Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is ReviewError) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('😵', style: TextStyle(fontSize: 48)),
                    SizedBox(height: AppSpacing.md),
                    Text(state.message,
                        style: AppTypography.primary.body
                            .copyWith(color: tc.secondary)),
                    SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: () => context.go(Routes.home),
                      child: Text('返回首页'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is EliminateTriggered) {
            return EliminateAnimationPage(
              totalEliminated: state.totalEliminated,
              isFirstInSession: state.isFirstInSession,
            );
          }

          if (state is ReviewInProgress || state is EvaluationPending) {
            return _buildReviewContent(state);
          }

          // ReviewCompleted 通过 listener 导航，这里兜底
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  // ─── State Listener ──────────────────────────────────────

  void _onStateChanged(BuildContext context, ReviewState state) {
    if (state is ReviewCompleted) {
      context.pushReplacement(Routes.reviewReport, extra: state.report);
      return;
    }

    if (state is EvaluationPending) {
      _showUndoSnackbar(state);
      return;
    }
  }

  // ─── Snackbar for Undo ───────────────────────────────────

  void _showUndoSnackbar(EvaluationPending state) {
    if (!mounted) return;
    EHSnackbar.show(
      context,
      message: '已评价为「${state.rating.label}」',
      actionLabel: '撤销',
      onAction: () {
        context.read<ReviewBloc>().add(const UndoEvaluation());
      },
      duration: const Duration(seconds: 4),
    );
  }

  // ─── Exit Confirm Dialog ─────────────────────────────────

  Future<void> _showExitConfirmDialog() async {
    final confirmed = await EHConfirmDialog.show(
      context,
      title: '结束复习？',
      content: '未评价的题目将不计入本次复习记录',
      confirmText: '结束复习',
      cancelText: '继续复习',
      isDestructive: true,
      icon: Icons.exit_to_app,
    );
    if (confirmed == true && mounted) {
      context.go(Routes.home);
    }
  }

  // ─── Build Review Content ────────────────────────────────

  Widget _buildReviewContent(ReviewState state) {
    final tc = context.textColors;
    late int currentIndex;
    late int total;
    late bool isAnswerShown;
    late bool isReviveCheck;
    late int daysSinceLastMastered;
    late var currentQuestion;
    SelfEvalRating? pendingRating;
    bool evaluationLocked = false;

    if (state is ReviewInProgress) {
      currentIndex = state.currentIndex;
      total = state.total;
      isAnswerShown = state.isAnswerShown;
      isReviveCheck = state.isReviveCheck;
      daysSinceLastMastered = state.daysSinceLastMastered;
      currentQuestion = state.currentQuestion;
      pendingRating = state.pendingRating;
    } else if (state is EvaluationPending) {
      currentIndex = state.currentIndex;
      total = state.total;
      isAnswerShown = true;
      isReviveCheck = state.isReviveCheck;
      daysSinceLastMastered = state.daysSinceLastMastered;
      currentQuestion = state.currentQuestion;
      pendingRating = state.rating;
      evaluationLocked = true;
    } else {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ─── 顶栏 ────────────────────────────────────
            _buildTopBar(currentIndex, total),

            // ─── 进度条 ──────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: ReviewProgressBar(
                progress: total > 0 ? (currentIndex + 1) / total : 0.0,
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // ─── 复活检测提示（如有）────────────────────
            if (isReviveCheck)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                child: ReviveCheckCard(daysSinceMastered: daysSinceLastMastered),
              ),

            if (isReviveCheck) SizedBox(height: AppSpacing.sm),

            // ─── 翻转卡片区域 ────────────────────────────
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300) {
                    // 左滑 → 下一题（仅在答案已显示或已有评价时）
                    if (isAnswerShown || evaluationLocked) {
                      // 如果还没评价，不允许跳过
                      if (!evaluationLocked && pendingRating == null) {
                        HapticFeedback.lightImpact();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请先评价再进入下一题 👆'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        return;
                      }
                    }
                  } else if (velocity > 300) {
                    // 右滑 → 回看上一题
                    context.read<ReviewBloc>().add(const GoToPrevious());
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                  child: FlipCardAnimation(
                    isFlipped: isAnswerShown,
                    front: ReviewCardFront(
                      question: currentQuestion,
                      onShowAnswer: () {
                        context.read<ReviewBloc>().add(const ShowAnswer());
                      },
                    ),
                    back: ReviewCardBack(
                      question: currentQuestion,
                      isReviveCheck: isReviveCheck,
                      daysSinceLastMastered: daysSinceLastMastered,
                      onEvaluate: (rating) {
                        context.read<ReviewBloc>().add(SelfEvaluate(rating));
                      },
                      selectedRating: pendingRating,
                      evaluationLocked: evaluationLocked,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ─────────────────────────────────────────────

  Widget _buildTopBar(int currentIndex, int total) {
    final tc = context.textColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // 退出按钮
          IconButton(
            onPressed: _showExitConfirmDialog,
            icon: const Icon(Icons.close, size: 24),
            color: tc.secondary,
          ),

          // 进度文字
          Expanded(
            child: Center(
              child: Text(
                '${currentIndex + 1}/$total',
                style: AppTypography.primary.h3.copyWith(
                  color: tc.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // 设置图标（占位保持居中）
          IconButton(
            onPressed: () {
              // TODO: 打开复习设置
            },
            icon: const Icon(Icons.settings_outlined, size: 24),
            color: tc.secondary,
          ),
        ],
      ),
    );
  }
}
