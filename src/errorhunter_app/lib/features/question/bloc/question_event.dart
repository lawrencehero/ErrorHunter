/// 错题猎手 - Question BLoC Events
library;

import 'package:equatable/equatable.dart';
import '../models/question_model.dart';
import '../models/knowledge_point_model.dart';

/// Question Event 基类
abstract class QuestionEvent extends Equatable {
  const QuestionEvent();

  @override
  List<Object?> get props => [];
}

/// 加载错题列表
class LoadQuestions extends QuestionEvent {
  const LoadQuestions({
    this.status,
    this.category,
    this.knowledgePointId,
    this.tag,
    this.page = 1,
    this.pageSize = 20,
    this.refresh = false,
  });

  final QuestionStatus? status;
  final ErrorCategory? category;
  final String? knowledgePointId;
  final String? tag;
  final int page;
  final int pageSize;
  final bool refresh;

  @override
  List<Object?> get props =>
      [status, category, knowledgePointId, tag, page, pageSize, refresh];
}

/// 搜索错题
class SearchQuestions extends QuestionEvent {
  const SearchQuestions(this.keyword);

  final String keyword;

  @override
  List<Object?> get props => [keyword];
}

/// 按状态筛选
class FilterByStatus extends QuestionEvent {
  const FilterByStatus(this.status);

  final QuestionStatus? status;

  @override
  List<Object?> get props => [status];
}

/// 按错因筛选
class FilterByCategory extends QuestionEvent {
  const FilterByCategory(this.category);

  final ErrorCategory? category;

  @override
  List<Object?> get props => [category];
}

/// 按知识点筛选
class FilterByKnowledgePoint extends QuestionEvent {
  const FilterByKnowledgePoint(this.knowledgePointId);

  final String? knowledgePointId;

  @override
  List<Object?> get props => [knowledgePointId];
}

/// 按自定义标签筛选
class FilterByTag extends QuestionEvent {
  const FilterByTag(this.tag);

  final String? tag;

  @override
  List<Object?> get props => [tag];
}

/// 加载错题详情
class LoadQuestionDetail extends QuestionEvent {
  const LoadQuestionDetail(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// 新增错题
class AddQuestion extends QuestionEvent {
  const AddQuestion({
    required this.imageUrl,
    this.ocrText,
    this.myAnswer,
    this.correctAnswer,
    required this.errorCategory,
    this.subCategories = const [],
    required this.knowledgePoints,
    this.customTags = const [],
  });

  final String imageUrl;
  final String? ocrText;
  final String? myAnswer;
  final String? correctAnswer;
  final ErrorCategory errorCategory;
  final List<String> subCategories;
  final List<KnowledgePoint> knowledgePoints;
  final List<String> customTags;

  @override
  List<Object?> get props => [
        imageUrl,
        ocrText,
        myAnswer,
        correctAnswer,
        errorCategory,
        subCategories,
        knowledgePoints,
        customTags,
      ];
}

/// 更新错题
class UpdateQuestion extends QuestionEvent {
  const UpdateQuestion(this.question);

  final QuestionModel question;

  @override
  List<Object?> get props => [question];
}

/// 删除错题（软删除）
class DeleteQuestion extends QuestionEvent {
  const DeleteQuestion(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// OCR 识别图片
class OcrImage extends QuestionEvent {
  const OcrImage(this.imagePath);

  final String imagePath;

  @override
  List<Object?> get props => [imagePath];
}
