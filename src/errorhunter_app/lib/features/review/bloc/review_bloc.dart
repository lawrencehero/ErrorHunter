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
    on<ExitReview>(_onExitReview);
  }

  // ─── Internal State ──────────────────────────────────────
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  DateTime? _startTime;
  // 当前题开始作答时间，用于计算单题复习用时（review_duration_sec）。
  // 每次切到新题（_buildInProgressState）时重置为 now。
  DateTime? _questionStartTime;
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
    _questionStartTime = _startTime;
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
        reviewDurationSec: _currentQuestionDurationSec(),
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
        reviewDurationSec: _currentQuestionDurationSec(),
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

    // 若当前题正处在 4 秒撤销窗口内（EvaluationPending），回看前先把该评价
    // 确认提交。否则撤销计时器被 cancel 后，评价既不会自动确认、也不会提交，
    // 造成"评了但没提交"的静默丢失。
    if (currentState is EvaluationPending) {
      _submitReviewResult(
        currentState.currentQuestion,
        currentState.rating,
        reviewDurationSec: _currentQuestionDurationSec(),
      );
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

  void _onExitReview(ExitReview event, Emitter<ReviewState> emit) {
    // 中途退出：若仍处于撤销窗口内，先把评价确认提交，再清理计时器。
    // 否则 _undoTimer 在 close() 时被 cancel，EvaluationPending 的评价既不
    // 自动确认也不提交，造成"评了但没上传"的静默丢失。
    _undoTimer?.cancel();
    _undoTimer = null;

    final currentState = state;
    if (currentState is EvaluationPending) {
      _submitReviewResult(
        currentState.currentQuestion,
        currentState.rating,
        reviewDurationSec: _currentQuestionDurationSec(),
      );
    }
    // 不 emit 新状态：page 随后会 context.go(home)，bloc 即将 dispose。
  }

  // ─── Helpers ─────────────────────────────────────────────

  ReviewInProgress _buildInProgressState() {
    final question = _questions[_currentIndex];
    // 切到新题重置单题计时（首题在 _onStartReview 已设置）。
    _questionStartTime = DateTime.now();
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

  /// 计算当前题已用复习秒数（从 _questionStartTime 起）。
  /// 用于提交 review_duration_sec；返回 null 当计时未启动（防御）。
  int? _currentQuestionDurationSec() {
    final start = _questionStartTime;
    if (start == null) return null;
    final sec = DateTime.now().difference(start).inSeconds;
    return sec < 0 ? 0 : sec;
  }

  int _daysSinceMastered(QuestionModel q) {
    if (!_isReviveCheck(q)) return 0;
    // 后端 model.Question.MasteredAt 已在 JSON 输出（mastered_at），
    // QuestionModel.fromJson 解析为 masteredAt。据此计算真实"已消灭 N 天"，
    // 替代原先写死的 14。未携带该字段（旧缓存/mock 缺失）时回退 14，避免文案突兀。
    final masteredAt = q.masteredAt;
    if (masteredAt == null) return 14;
    final days = DateTime.now().difference(masteredAt).inDays;
    return days < 0 ? 0 : days;
  }

  bool _checkShouldEliminate(QuestionModel q, SelfEvalRating rating) {
    // 复活检测题（status=MASTERED）已消灭过，走 revive_result 提交路径，
    // 不应再触发消灭动画——否则每道复活检测题评"还记得"都会弹动画，
    // 与"复活检测"语义冲突。复活题的"再次消灭"由后端永久消灭分支处理。
    if (_isReviveCheck(q)) return false;

    // 消灭判定以"消灭计数"为准：后端 master_count >= 3 即消灭。
    // QuestionModel.masterCount 现已从后端 master_count 解析；旧缓存/mock
    // 未携带时为 0，此时回退到 currentReviewRound >= 3 的近似（仅影响 mock，
    // 真机数据以 master_count 为准）。
    final positiveRating = rating == SelfEvalRating.mastered ||
        rating == SelfEvalRating.remembered;
    if (!positiveRating) return false;
    if (q.masterCount >= 3) return true;
    // 兼容回退：仅当后端未返回 master_count（字段缺失，如 mock）时生效。
    // 真机数据 master_count 一定存在（model.Question.MasterCount not null），
    // 此分支不会被命中，避免用 round 误判真实数据。
    if (q.masterCount == 0 && q.currentReviewRound >= 3) return true;
    return false;
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

  /// 前端 SelfEvalRating → 后端 revive_result 字符串映射。
  ///
  /// 后端 handleReviveCheck 强制要求 revive_result（REMEMBERED/FORGOTTEN），
  /// 缺失返回 EReviveResultRequired（400）。复活检测题的"还记得/忘记"语义
  /// 只能通过该字段传达，self_rating 在复活分支不被使用。
  /// 非复活检测题返回 null（不传该字段）。
  static String? _mapToReviveResult(
      SelfEvalRating rating, bool isReviveCheck) {
    if (!isReviveCheck) return null;
    switch (rating) {
      case SelfEvalRating.remembered:
      case SelfEvalRating.mastered:
        return 'REMEMBERED';
      case SelfEvalRating.forgotten:
      case SelfEvalRating.forgot:
        return 'FORGOTTEN';
      case SelfEvalRating.partial:
        // 复活检测只有双按钮，不应出现 partial；保守视为忘记。
        return 'FORGOTTEN';
    }
  }

  /// 提交单题复习结果到后端（fire-and-forget，失败仅忽略，不阻断复习流程）。
  ///
  /// [reviewDurationSec] 由调用方传入当前题的复习用时（从 _startTime 或单题计时
  /// 计算）；后端 ReviewRecord.ReviewDurationSec 据此落库，否则永久 nil。
  void _submitReviewResult(
    QuestionModel question,
    SelfEvalRating rating, {
    int? reviewDurationSec,
  }) {
    final isReviveCheck = _isReviveCheck(question);
    // 不 await：UI 不应被网络请求阻塞；失败也不影响本地复习体验。
    _reviewRepository
        .submitReviewResult(
          questionId: question.id,
          selfRating: _mapToBackendRating(rating),
          reviewDurationSec: reviewDurationSec,
          isReviveCheck: isReviveCheck,
          reviveResult: _mapToReviveResult(rating, isReviveCheck),
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
