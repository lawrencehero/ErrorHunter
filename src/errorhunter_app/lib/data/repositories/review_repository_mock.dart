/// 错题猎手 - Review Repository Mock 实现
/// 使用 MockReviewDataSource 提供数据，后端就绪后替换为 Remote 实现
library;

import '../../domain/repositories/review_repository.dart';
import '../../features/question/models/question_model.dart';
import '../mock/mock_review_data_source.dart';

/// Review Repository 的 Mock 实现
class ReviewRepositoryMock implements ReviewRepository {
  ReviewRepositoryMock({MockReviewDataSource? dataSource})
      : _dataSource = dataSource ?? MockReviewDataSource();

  final MockReviewDataSource _dataSource;

  @override
  Future<List<QuestionModel>> getReviewQueue({
    List<String>? questionIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _dataSource.getReviewQueue();
  }

  @override
  Future<int> getStreakDays() async {
    return _dataSource.getStreakDays();
  }

  /// Mock 模式无后端，提交记为空操作（不抛错，保证复习流程可跑通）。
  @override
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
    bool isReviveCheck = false,
    String? reviveResult,
  }) async {
    // no-op
  }
}
