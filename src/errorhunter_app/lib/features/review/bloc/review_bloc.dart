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
    // 当 master_count 达到 3 时触发消灭
    // TODO: 从后端获取真实的 master_count（后端就绪后替换）
    final mockMasterCount = q.currentReviewRound >= 3 &&
        (rating == SelfEvalRating.mastered ||
            rating == SelfEvalRating.remembered);
    return mockMasterCount;
  }

  @override
  Future<void> close() {
    _undoTimer?.cancel();
    return super.close();
  }
}
