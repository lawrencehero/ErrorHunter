/// 错题猎手 - Question Repository Mock 实现
/// 使用 MockQuestionDataSource 提供数据，后端就绪后替换为 Remote 实现
library;

import '../../domain/repositories/question_repository.dart';
import '../../features/question/models/question_model.dart';
import '../../features/question/models/ocr_result.dart';
import '../mock/mock_question_data_source.dart';

/// Question Repository 的 Mock 实现
class QuestionRepositoryMock implements QuestionRepository {
  QuestionRepositoryMock({MockQuestionDataSource? dataSource})
      : _dataSource = dataSource ?? MockQuestionDataSource();

  final MockQuestionDataSource _dataSource;

  @override
  Future<List<QuestionModel>> getQuestions({
    ErrorCategory? category,
    QuestionStatus? status,
    String? knowledgePointId,
    String? tag,
    int page = 1,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    var questions = _dataSource.getQuestions();

    if (status != null) {
      questions = questions.where((q) => q.status == status).toList();
    }
    if (category != null) {
      questions =
          questions.where((q) => q.errorCategory == category).toList();
    }
    if (knowledgePointId != null) {
      questions = questions
          .where((q) =>
              q.knowledgePoints.any((kp) => kp.id == knowledgePointId))
          .toList();
    }
    if (tag != null) {
      questions = questions.where((q) => q.customTags.contains(tag)).toList();
    }

    return questions;
  }

  @override
  Future<List<String>> getTags() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = _dataSource.getQuestions();
    final tags = <String>{};
    for (final q in all) {
      tags.addAll(q.customTags);
    }
    return tags.toList()..sort();
  }

  @override
  Future<List<QuestionModel>> searchQuestions(String keyword) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final allQuestions = _dataSource.getQuestions();
    if (keyword.isEmpty) return allQuestions;

    return allQuestions
        .where((q) =>
            (q.ocrText?.contains(keyword) ?? false) ||
            q.subject.contains(keyword))
        .toList();
  }

  @override
  Future<QuestionModel?> getQuestionDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final allQuestions = _dataSource.getQuestions();
    return allQuestions.where((q) => q.id == id).firstOrNull;
  }

  @override
  Future<QuestionModel> addQuestion(QuestionModel question) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return question;
  }

  @override
  Future<void> updateQuestion(QuestionModel question) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> deleteQuestion(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<List<QuestionModel>> getRecycleBin({
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  @override
  Future<void> restoreQuestion(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> permanentDeleteQuestion(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<int> clearRecycleBin() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 0;
  }

  @override
  Future<OcrResult> ocrImage(String imagePath) async {
    await Future.delayed(const Duration(seconds: 2));
    return OcrResult(text: _dataSource.getMockOcrResult());
  }
}
