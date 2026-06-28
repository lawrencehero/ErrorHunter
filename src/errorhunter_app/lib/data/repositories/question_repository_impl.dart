/// 错题猎手 - Question Repository 真实实现
/// 调用 QuestionRemoteDataSource 对接后端 API
library;

import '../../domain/repositories/question_repository.dart';
import '../../features/question/models/question_model.dart';
import '../../features/question/models/ocr_result.dart';
import '../remote/question_remote_data_source.dart';

/// Question Repository 的真实实现
class QuestionRepositoryImpl implements QuestionRepository {
  QuestionRepositoryImpl({required QuestionRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final QuestionRemoteDataSource _dataSource;

  @override
  Future<List<QuestionModel>> getQuestions({
    ErrorCategory? category,
    QuestionStatus? status,
    String? knowledgePointId,
    int page = 1,
  }) {
    return _dataSource.getQuestions(
      category: category?.code,
      status: status?.code,
      knowledgePointId: knowledgePointId,
      page: page,
    );
  }

  @override
  Future<List<QuestionModel>> searchQuestions(String keyword) =>
      _dataSource.searchQuestions(keyword);

  @override
  Future<QuestionModel?> getQuestionDetail(String id) =>
      _dataSource.getQuestionDetail(id);

  @override
  Future<QuestionModel> addQuestion(QuestionModel question) =>
      _dataSource.addQuestion(question);

  @override
  Future<void> updateQuestion(QuestionModel question) =>
      _dataSource.updateQuestion(question);

  @override
  Future<void> deleteQuestion(String id) =>
      _dataSource.deleteQuestion(id);

  @override
  Future<OcrResult> ocrImage(String imagePath) =>
      _dataSource.ocrImage(imagePath);
}
