/// 错题猎手 - Review BLoC States
library;

import 'package:equatable/equatable.dart';
import '../../question/models/question_model.dart';
import '../models/review_report_model.dart';

/// Review State 基类
sealed class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class ReviewInitial extends ReviewState {
  const ReviewInitial();
}

/// 加载中
class ReviewLoading extends ReviewState {
  const ReviewLoading();
}

/// 复习进行中
class ReviewInProgress extends ReviewState {
  const ReviewInProgress({
    required this.currentIndex,
    required this.total,
    required this.currentQuestion,
    required this.isAnswerShown,
    required this.isReviveCheck,
    required this.daysSinceLastMastered,
    required this.eliminatedInSession,
    this.pendingRating,
  });

  final int currentIndex;
  final int total;
  final QuestionModel currentQuestion;
  final bool isAnswerShown;
  final bool isReviveCheck;
  final int daysSinceLastMastered;
  final int eliminatedInSession;

  /// 当前待确认的自评（null = 未选择）
  final SelfEvalRating? pendingRating;

  double get progress => total > 0 ? (currentIndex + 1) / total : 0.0;

  @override
  List<Object?> get props => [
        currentIndex,
        total,
        currentQuestion.id,
        isAnswerShown,
        isReviveCheck,
        // daysSinceLastMastered 影响复活检测提示文案，纳入 props 保证变化时重建。
        daysSinceLastMastered,
        pendingRating,
        eliminatedInSession,
      ];

  ReviewInProgress copyWith({
    int? currentIndex,
    int? total,
    QuestionModel? currentQuestion,
    bool? isAnswerShown,
    bool? isReviveCheck,
    int? daysSinceLastMastered,
    int? eliminatedInSession,
    SelfEvalRating? pendingRating,
    bool clearPendingRating = false,
  }) {
    return ReviewInProgress(
      currentIndex: currentIndex ?? this.currentIndex,
      total: total ?? this.total,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      isAnswerShown: isAnswerShown ?? this.isAnswerShown,
      isReviveCheck: isReviveCheck ?? this.isReviveCheck,
      daysSinceLastMastered:
          daysSinceLastMastered ?? this.daysSinceLastMastered,
      eliminatedInSession: eliminatedInSession ?? this.eliminatedInSession,
      pendingRating:
          clearPendingRating ? null : (pendingRating ?? this.pendingRating),
    );
  }
}

/// 自评等待确认中（4秒撤销窗口）
class EvaluationPending extends ReviewState {
  const EvaluationPending({
    required this.rating,
    required this.canUndoUntil,
    required this.currentIndex,
    required this.total,
    required this.currentQuestion,
    required this.isReviveCheck,
    required this.daysSinceLastMastered,
    required this.eliminatedInSession,
  });

  final SelfEvalRating rating;
  final DateTime canUndoUntil;
  final int currentIndex;
  final int total;
  final QuestionModel currentQuestion;
  final bool isReviveCheck;
  final int daysSinceLastMastered;
  final int eliminatedInSession;

  @override
  List<Object?> get props => [rating, canUndoUntil, currentIndex];
}

/// 需要播放消灭动画
class EliminateTriggered extends ReviewState {
  const EliminateTriggered({
    required this.questionId,
    required this.isFirstInSession,
    required this.totalEliminated,
    required this.previousState,
  });

  final String questionId;
  final bool isFirstInSession;
  final int totalEliminated;

  /// 保存之前的进度状态，动画结束后恢复
  final ReviewInProgress previousState;

  @override
  List<Object?> get props => [questionId, isFirstInSession, totalEliminated];
}

/// 复习完成
class ReviewCompleted extends ReviewState {
  const ReviewCompleted(this.report);

  final ReviewReportModel report;

  @override
  List<Object?> get props => [report];
}

/// 错误状态
class ReviewError extends ReviewState {
  const ReviewError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
