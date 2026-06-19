/// 错题猎手 - Review BLoC
/// 管理复习流程、自评撤销计时器、消灭检测
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../question/models/question_model.dart';
import '../models/review_report_model.dart';
import 'review_event.dart';
import 'review_state.dart';

/// Review BLoC
class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  ReviewBloc() : super(const ReviewInitial()) {
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

  // ─── Mock Data Generator ─────────────────────────────────
  static List<QuestionModel> _generateMockQuestions() {
    return List.generate(8, (i) {
      final isRevive = i == 2 || i == 5; // 第3和第6题为复活检测
      return QuestionModel(
        id: 'mock_q_${i + 1}',
        imageUrl: '',
        ocrText: '题目 ${i + 1}：${_mockQuestionText(i)}',
        myAnswer: _mockMyAnswer(i),
        correctAnswer: _mockCorrectAnswer(i),
        errorCategory: ErrorCategory.values[i % ErrorCategory.values.length],
        status: isRevive ? QuestionStatus.mastered : QuestionStatus.reviewing,
        knowledgePoints: [
          // TODO: 使用真实知识点数据
        ],
        solutionSteps: _mockSolutionSteps(i),
        currentReviewRound: isRevive ? 3 : (i % 3 + 1),
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(Duration(days: 30 - i)),
        subject: '数学',
      );
    });
  }

  static String _mockQuestionText(int index) {
    const texts = [
      '计算 24 × 15 的结果',
      '一个长方形的长是8cm，宽是5cm，求周长和面积',
      '解方程 3x + 7 = 22',
      '将分数 3/4 转换为小数和百分数',
      '一个圆的半径为3cm，求圆的面积（π取3.14）',
      '甲乙两地相距240km，汽车每小时行60km，几小时到达？',
      '化简比 12:18',
      '一块三角形菜地底边长20m，高15m，面积是多少？',
    ];
    return texts[index % texts.length];
  }

  static String _mockMyAnswer(int index) {
    const answers = ['340', '周长=26cm 面积=40cm²', 'x=4', '0.75 和 70%',
      '27.12cm²', '5小时', '2:3', '100m²'];
    return answers[index % answers.length];
  }

  static String _mockCorrectAnswer(int index) {
    const answers = ['360', '周长=26cm 面积=40cm²', 'x=5', '0.75 和 75%',
      '28.26cm²', '4小时', '2:3', '150m²'];
    return answers[index % answers.length];
  }

  static List<SolutionStep> _mockSolutionSteps(int index) {
    return [
      const SolutionStep(stepNumber: 1, content: '审题，明确已知条件和要求'),
      const SolutionStep(stepNumber: 2, content: '列出计算公式或方程'),
      SolutionStep(
        stepNumber: 3,
        content: '代入数据进行计算',
        isErrorStep: index % 2 == 0,
      ),
      const SolutionStep(stepNumber: 4, content: '检验结果是否合理'),
    ];
  }

  // ─── Event Handlers ──────────────────────────────────────

  Future<void> _onStartReview(
    StartReview event,
    Emitter<ReviewState> emit,
  ) async {
    emit(const ReviewLoading());

    // TODO: 调用 API 获取复习队列
    // final questions = await _reviewRepository.getReviewQueue(event.questionIds);
    await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟

    _questions = _generateMockQuestions();
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

  void _onCompleteReview(CompleteReview event, Emitter<ReviewState> emit) {
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

    emit(ReviewCompleted(ReviewReportModel(
      totalCount: _evaluations.length,
      masteredCount: mastered,
      partialCount: partial,
      forgotCount: forgot,
      durationMinutes: duration,
      streakDays: 7, // TODO: 从API获取连续打卡天数
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
    // TODO: 从 reviewHistory 计算真实天数
    return 14; // Mock: 14天前消灭的
  }

  bool _checkShouldEliminate(QuestionModel q, SelfEvalRating rating) {
    // 当 master_count 达到 3 时触发消灭
    // TODO: 从后端获取真实的 master_count
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
