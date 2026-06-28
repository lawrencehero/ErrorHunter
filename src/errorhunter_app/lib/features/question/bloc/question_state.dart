/// 错题猎手 - Question BLoC States
library;

import 'package:equatable/equatable.dart';
import '../models/ocr_result.dart';
import '../models/question_model.dart';

/// Question State 基类
abstract class QuestionState extends Equatable {
  const QuestionState();

  @override
  List<Object?> get props => [];
}

// ─── List States ──────────────────────────────────────────────

/// 列表初始态
class QuestionListInitial extends QuestionState {
  const QuestionListInitial();
}

/// 列表加载中
class QuestionListLoading extends QuestionState {
  const QuestionListLoading();
}

/// 列表已加载
class QuestionListLoaded extends QuestionState {
  const QuestionListLoaded({
    required this.questions,
    this.hasMore = false,
    this.currentPage = 1,
    this.filterStatus,
    this.filterCategory,
    this.filterKnowledgePoint,
    this.searchKeyword = '',
  });

  final List<QuestionModel> questions;
  final bool hasMore;
  final int currentPage;
  final QuestionStatus? filterStatus;
  final ErrorCategory? filterCategory;
  final String? filterKnowledgePoint;
  final String searchKeyword;

  @override
  List<Object?> get props => [
        questions.length,
        hasMore,
        currentPage,
        filterStatus,
        filterCategory,
        filterKnowledgePoint,
        searchKeyword,
      ];
}

// ─── Detail States ────────────────────────────────────────────

/// 详情加载中
class QuestionDetailLoading extends QuestionState {
  const QuestionDetailLoading();
}

/// 详情已加载
class QuestionDetailLoaded extends QuestionState {
  const QuestionDetailLoaded(this.question);

  final QuestionModel question;

  @override
  List<Object?> get props => [question.id];
}

// ─── Add States ───────────────────────────────────────────────

/// 正在添加错题
class QuestionAdding extends QuestionState {
  const QuestionAdding();
}

/// 添加成功
class QuestionAdded extends QuestionState {
  const QuestionAdded(this.question);

  final QuestionModel question;

  @override
  List<Object?> get props => [question.id];
}

/// 添加失败（UI 弹出提示，不导航）
class QuestionAddFailed extends QuestionState {
  const QuestionAddFailed([this.message = '保存失败，请重试']);

  final String message;

  @override
  List<Object?> get props => [message];
}

// ─── OCR States ───────────────────────────────────────────────

/// OCR 识别中
class OcrProcessing extends QuestionState {
  const OcrProcessing();
}

/// OCR 识别完成
class OcrCompleted extends QuestionState {
  const OcrCompleted({required this.text, this.imageUrl = '', this.figures = const []});

  final String text;
  /// 上传到对象存储后的图片 URL，保存错题时用
  final String imageUrl;
  final List<OcrFigure> figures;

  @override
  List<Object?> get props => [text, imageUrl, figures];
}

/// OCR 识别失败
class OcrFailed extends QuestionState {
  const OcrFailed([this.message = '识别失败，请手动输入题目内容']);

  final String message;

  @override
  List<Object?> get props => [message];
}

// ─── Update States ─────────────────────────────────────────────

/// 更新失败（保留上次成功加载的详情，仅通知 UI 弹出提示）
class QuestionUpdateFailed extends QuestionState {
  const QuestionUpdateFailed(
    this.question, [
    this.message = '保存失败，请重试',
  ]);

  /// 更新前的错题数据，用于回退 UI 显示
  final QuestionModel question;
  final String message;

  @override
  List<Object?> get props => [question.id, message];
}

// ─── Error State ──────────────────────────────────────────────

/// 通用错误
class QuestionError extends QuestionState {
  const QuestionError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
