/// 错题猎手 - Review Repository 真实实现
/// 调用 ReviewRemoteDataSource 对接后端 API
library;

import '../../domain/repositories/review_repository.dart';
import '../../features/question/models/question_model.dart';
import '../../features/review/models/review_report_model.dart';
import '../remote/review_remote_data_source.dart';

/// Review Repository 的真实实现
class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl({required ReviewRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final ReviewRemoteDataSource _dataSource;

  @override
  Future<List<QuestionModel>> getReviewQueue({
    List<String>? questionIds,
  }) =>
      _dataSource.getReviewQueue(questionIds: questionIds);

  @override
  Future<ReviewReportModel> getTodaySummary() async {
    final json = await _dataSource.getTodaySummary();
    return ReviewReportModel.fromTodaySummary(json);
  }

  @override
  Future<int> getStreakDays() => _dataSource.getStreakDays();

  @override
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
    bool isReviveCheck = false,
    String? reviveResult,
  }) =>
      _dataSource.submitReviewResult(
        questionId: questionId,
        selfRating: selfRating,
        reviewDurationSec: reviewDurationSec,
        isReviveCheck: isReviveCheck,
        reviveResult: reviveResult,
      );
}
