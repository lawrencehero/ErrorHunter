/// 错题猎手 - Review BLoC
/// 管理复习流程、自评撤销计时器、消灭检测
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../question/models/question_model.dart';
import '../models/review_report_model.dart';
import '../../../domain/repositories/review_repository.dart';
import 'review_event.dart';
import 'review_state.dart';

/// Review BLoC
class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  final ReviewRepository _reviewRepository;

  ReviewBloc(this._reviewRepository) : super(const ReviewInitial()) {
    on<StartReview>(_onStartReview);
    on<ShowAnswer>(_onShowAnswer);
    on<SelfEvaluate>(_onSelfEvaluate);
    on<UndoEvaluation>(_onUndoEvaluation);
    on<ConfirmAndNext>(_onConfirmAndNext);
    on<GoToPrevious>(_onGoToPrevious);
    on<CompleteReview>(_onCompleteReview);
    on<CheckEliminate>(_onCheckEliminate);
    on<ResetEliminateState>(_onResetEliminateState);
  }

  // ─── Internal State ──────────────────────────────────────
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  DateTime? _startTime;
  final Map<String, SelfEvalRating> _evaluations = {};
  int _eliminatedInSession = 0;
  bool _hasShownFirstEliminate = false;
  Timer? _undoTimer;

  // ─── Event Handlers ──────────────────────────────────────

  Future<void> _onStartReview(
    StartReview event,
    Emitter<ReviewState> emit,
  ) async {
    // 清理可能残留的撤销计时器（如用户退出后重新开始复习）
    _undoTimer?.cancel();
    _undoTimer = null;

    emit(const ReviewLoading());

    _questions = await _reviewRepository.getReviewQueue(
      questionIds: event.questionIds,
    );
    _currentIndex = 0;
    _startTime = DateTime.now();
    _evaluations.clear();
    _eliminatedInSession = 0;
    _hasShownFirstEliminate = false;

    if (_questions.isEmpty) {
      emit(ReviewCompleted(ReviewReportModel.empty()));
      return;
    }

    emit(_buildInProgressState());
  }

  void _onShowAnswer(ShowAnswer event, Emitter<ReviewState> emit) {
    final currentState = state;
    if (currentState is ReviewInProgress) {
      emit(currentState.copyWith(isAnswerShown: true));
    }
  }

  void _onSelfEvaluate(SelfEvaluate event, Emitter<ReviewState> emit) {
    _undoTimer?.cancel();

    final currentState = state;
    if (currentState is! ReviewInProgress) return;

    final questionId = currentState.currentQuestion.id;
    _evaluations[questionId] = event.rating;

    // 检查是否触发消灭
    final shouldEliminate = _checkShouldEliminate(
      currentState.currentQuestion,
      event.rating,
    );

    if (shouldEliminate) {
      _eliminatedInSession++;
      final isFirst = !_hasShownFirstEliminate;
      _hasShownFirstEliminate = true;

      // 消灭路径：评价已最终确定，立即提交后端（fire-and-forget，失败不阻断）
      _submitReviewResult(
        currentState.currentQuestion,
        event.rating,
      );

      emit(EliminateTriggered(
        questionId: questionId,
        isFirstInSession: isFirst,
        totalEliminated: _eliminatedInSession,
        previousState: currentState.copyWith(
          pendingRating: event.rating,
          eliminatedInSession: _eliminatedInSession,
        ),
      ));
      return;
    }

    // 进入4秒撤销窗口
    emit(EvaluationPending(
      rating: event.rating,
      canUndoUntil: DateTime.now().add(const Duration(seconds: 4)),
      currentIndex: currentState.currentIndex,
      total: currentState.total,
      currentQuestion: currentState.currentQuestion,
      isReviveCheck: currentState.isReviveCheck,
      daysSinceLastMastered: currentState.daysSinceLastMastered,
      eliminatedInSession: currentState.eliminatedInSession,
    ));

    // 4秒后自动确认
    _undoTimer = Timer(const Duration(seconds: 4), () {
      add(const ConfirmAndNext());
    });
  }

  void _onUndoEvaluation(UndoEvaluation event, Emitter<ReviewState> emit) {
    _undoTimer?.cancel();

    final currentState = state;
    if (currentState is! EvaluationPending) return;

    // 移除评价
    _evaluations.remove(currentState.currentQuestion.id);

    // 恢复到背面展示状态
    emit(ReviewInProgress(
      currentIndex: currentState.currentIndex,
      total: currentState.total,
      currentQuestion: currentState.currentQuestion,
      isAnswerShown: true,
      isReviveCheck: currentState.isReviveCheck,
      daysSinceLastMastered: currentState.daysSinceLastMastered,
      eliminatedInSession: currentState.eliminatedInSession,
    ));
  }

  void _onConfirmAndNext(ConfirmAndNext event, Emitter<ReviewState> emit) {
    _undoTimer?.cancel();

    final currentState = state;
    late int currentIndex;
    late int total;

    if (currentState is EvaluationPending) {
      currentIndex = currentState.currentIndex;
      total = currentState.total;
      // 撤销窗口结束确认：评价最终确定，提交后端（fire-and-forget，失败不阻断）
      _submitReviewResult(
        currentState.currentQuestion,
        currentState.rating,
      );
    } else if (currentState is ReviewInProgress) {
      currentIndex = currentState.currentIndex;
      total = currentState.total;
    } else {
      return;
    }

    // 移到下一题
    if (currentIndex < total - 1) {
      _currentIndex = currentIndex + 1;
      emit(_buildInProgressState());
    } else {
      // 最后一题完成
      add(const CompleteReview());
    }
  }

  void _onGoToPrevious(GoToPrevious event, Emitter<ReviewState> emit) {
    _undoTimer?.cancel();

    final currentState = state;

    // 如果在等待确认中，先提交当前评价
    if (currentState is EvaluationPending) {
      // 已提交的不能改
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      // 回看模式：已评可查看不可改评
      final question = _questions[_currentIndex];
      final hasEval = _evaluations.containsKey(question.id);

      emit(ReviewInProgress(
        currentIndex: _currentIndex,
        total: _questions.length,
        currentQuestion: question,
        isAnswerShown: hasEval, // 已评的直接显示答案
        isReviveCheck: _isReviveCheck(question),
        daysSinceLastMastered: _daysSinceMastered(question),
        eliminatedInSession: _eliminatedInSession,
        pendingRating: hasEval ? _evaluations[question.id] : null,
      ));
    }
  }

  Future<void> _onCompleteReview(
    CompleteReview event,
    Emitter<ReviewState> emit,
  ) async {
    _undoTimer?.cancel();

    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inMinutes
        : 0;

    var mastered = 0;
    var partial = 0;
    var forgot = 0;

    for (final entry in _evaluations.entries) {
      switch (entry.value) {
        case SelfEvalRating.mastered || SelfEvalRating.remembered:
          mastered++;
        case SelfEvalRating.partial:
          partial++;
        case SelfEvalRating.forgot || SelfEvalRating.forgotten:
          forgot++;
      }
    }

    final streakDays = await _reviewRepository.getStreakDays();

    emit(ReviewCompleted(ReviewReportModel(
      totalCount: _evaluations.length,
      masteredCount: mastered,
      partialCount: partial,
      forgotCount: forgot,
      durationMinutes: duration,
      streakDays: streakDays,
      eliminatedCount: _eliminatedInSession,
    )));
  }

  void _onCheckEliminate(CheckEliminate event, Emitter<ReviewState> emit) {
    // 由 UI 层在动画完成后调用
  }

  void _onResetEliminateState(
    ResetEliminateState event,
    Emitter<ReviewState> emit,
  ) {
    _undoTimer?.cancel();
    _undoTimer = null;

    final currentState = state;
    if (currentState is EliminateTriggered) {
      // 动画结束，恢复进度并自动下一题
      final prev = currentState.previousState;
      if (prev.currentIndex < prev.total - 1) {
        _currentIndex = prev.currentIndex + 1;
        emit(_buildInProgressState());
      } else {
        add(const CompleteReview());
      }
    }
  }

  // ─── Helpers ─────────────────────────────────────────────

  ReviewInProgress _buildInProgressState() {
    final question = _questions[_currentIndex];
    return ReviewInProgress(
      currentIndex: _currentIndex,
      total: _questions.length,
      currentQuestion: question,
      isAnswerShown: false,
      isReviveCheck: _isReviveCheck(question),
      daysSinceLastMastered: _daysSinceMastered(question),
      eliminatedInSession: _eliminatedInSession,
    );
  }

  bool _isReviveCheck(QuestionModel q) {
    return q.status == QuestionStatus.mastered;
  }

  int _daysSinceMastered(QuestionModel q) {
    if (!_isReviveCheck(q)) return 0;
    // TODO: 从 reviewHistory 计算真实天数（后端返回完整数据后可移除）
    return 14;
  }

  bool _checkShouldEliminate(QuestionModel q, SelfEvalRating rating) {
    // ⚠️ 临时方案：用 currentReviewRound >= 3 模拟 master_count 达到阈值
    // TODO: 后端返回真实 master_count 后，替换为 q.masterCount >= 3
    final mockMasterCount = q.currentReviewRound >= 3 &&
        (rating == SelfEvalRating.mastered ||
            rating == SelfEvalRating.remembered);
    return mockMasterCount;
  }

  /// 前端 SelfEvalRating → 后端 self_rating 字符串映射。
  ///
  /// 后端只接受 MASTERED / PARTIAL / FAILED（见 scheduler.go SelfRating 常量），
  /// 前端有 mastered/remembered/partial/forgot/forgotten 五种，需收敛：
  ///   mastered   → MASTERED
  ///   remembered → MASTERED
  ///   partial    → PARTIAL
  ///   forgot     → FAILED
  ///   forgotten  → FAILED
  static String _mapToBackendRating(SelfEvalRating rating) {
    switch (rating) {
      case SelfEvalRating.mastered:
      case SelfEvalRating.remembered:
        return 'MASTERED';
      case SelfEvalRating.partial:
        return 'PARTIAL';
      case SelfEvalRating.forgot:
      case SelfEvalRating.forgotten:
        return 'FAILED';
    }
  }

  /// 提交单题复习结果到后端（fire-and-forget，失败仅忽略，不阻断复习流程）。
  void _submitReviewResult(QuestionModel question, SelfEvalRating rating) {
    // 不 await：UI 不应被网络请求阻塞；失败也不影响本地复习体验。
    _reviewRepository
        .submitReviewResult(
          questionId: question.id,
          selfRating: _mapToBackendRating(rating),
          isReviveCheck: _isReviveCheck(question),
        )
        .catchError((_) {
          // 静默忽略：复习体验优先，dashboard 刷新容错由后端兜底。
        });
  }

  @override
  Future<void> close() {
    _undoTimer?.cancel();
    return super.close();
  }
}
