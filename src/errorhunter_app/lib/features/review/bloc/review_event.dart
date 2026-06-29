/// 错题猎手 - Review BLoC Events
library;

import 'package:equatable/equatable.dart';
import '../models/review_report_model.dart';

/// Review Event 基类
sealed class ReviewEvent extends Equatable {
  const ReviewEvent();

  @override
  List<Object?> get props => [];
}

/// 开始复习会话
class StartReview extends ReviewEvent {
  const StartReview({this.questionIds});

  /// 指定复习的错题ID列表，null 表示由后端推荐
  final List<String>? questionIds;

  @override
  List<Object?> get props => [questionIds];
}

/// 显示答案（翻转到背面）
class ShowAnswer extends ReviewEvent {
  const ShowAnswer();
}

/// 自评打分
class SelfEvaluate extends ReviewEvent {
  const SelfEvaluate(this.rating);

  final SelfEvalRating rating;

  @override
  List<Object?> get props => [rating];
}

/// 撤销自评
class UndoEvaluation extends ReviewEvent {
  const UndoEvaluation();
}

/// 确认提交当前评价并进入下一题
class ConfirmAndNext extends ReviewEvent {
  const ConfirmAndNext();
}

/// 回看上一题
class GoToPrevious extends ReviewEvent {
  const GoToPrevious();
}

/// 完成全部复习
class CompleteReview extends ReviewEvent {
  const CompleteReview();
}

/// 检查是否触发消灭动画
class CheckEliminate extends ReviewEvent {
  const CheckEliminate({required this.questionId});

  final String questionId;

  @override
  List<Object?> get props => [questionId];
}

/// 重置消灭动画状态
class ResetEliminateState extends ReviewEvent {
  const ResetEliminateState();
}

/// 中途退出复习：提交仍处于撤销窗口内（EvaluationPending）的评价，
/// 避免用户评了但未过 4 秒窗口就退出导致评价静默丢失。
/// 已评且已提交的题不受影响；纯导航事件，不改变复习状态机。
class ExitReview extends ReviewEvent {
  const ExitReview();
}
