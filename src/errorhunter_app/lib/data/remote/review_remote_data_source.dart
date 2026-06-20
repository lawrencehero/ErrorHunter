/// 错题猎手 - Review Remote Data Source
/// 调用后端复习 API，替代 MockReviewDataSource
library;

import '../../features/question/models/question_model.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// Review 远程数据源 — 对接后端 /v1/reviews/* 接口
class ReviewRemoteDataSource {
  ReviewRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 获取复习队列
  Future<List<QuestionModel>> getReviewQueue({
    List<String>? questionIds,
  }) async {
    final queryParams = <String, dynamic>{
      if (questionIds != null && questionIds.isNotEmpty)
        'question_ids': questionIds.join(','),
    };

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.reviewQueue,
      queryParameters: queryParams,
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? [];

    return items
        .map((item) =>
            QuestionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 提交复习结果
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
  }) async {
    await _client.post(
      ApiEndpoints.reviewResult,
      data: {
        'question_id': int.tryParse(questionId) ?? 0,
        'self_rating': selfRating,
        if (reviewDurationSec != null)
          'review_duration_sec': reviewDurationSec,
      },
    );
  }

  /// 获取连续打卡天数
  Future<int> getStreakDays() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.user,
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      return data?['streak_days'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
