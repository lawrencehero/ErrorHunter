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

    // 后端返回 review_items（普通复习题）+ revive_items（复活检测题），
    // 两者均为完整 Question 形状，合并后交给 ReviewBloc。
    // 复活检测题 status=MASTERED，ReviewBloc._isReviveCheck 据此识别。
    final reviewItems = data?['review_items'] as List<dynamic>? ?? [];
    final reviveItems = data?['revive_items'] as List<dynamic>? ?? [];

    final all = <QuestionModel>[];
    for (final item in reviewItems) {
      all.add(QuestionModel.fromJson(item as Map<String, dynamic>));
    }
    for (final item in reviveItems) {
      all.add(QuestionModel.fromJson(item as Map<String, dynamic>));
    }
    return all;
  }

  /// 提交复习结果
  ///
  /// [selfRating] 为已映射到后端的字符串（MASTERED/PARTIAL/FAILED），
  /// 映射逻辑由调用方（ReviewBloc._mapToBackendRating）负责。
  /// [reviveResult] 仅复活检测题需要（REMEMBERED/FORGOTTEN）：
  /// 后端 handleReviveCheck 强制校验该字段，缺失返回 EReviveResultRequired，
  /// 因此复活检测题必须传入，否则提交必然 400。
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
    bool isReviveCheck = false,
    String? reviveResult,
  }) async {
    await _client.post(
      ApiEndpoints.reviewResult,
      data: {
        'question_id': int.tryParse(questionId) ?? 0,
        'self_rating': selfRating,
        if (reviewDurationSec != null)
          'review_duration_sec': reviewDurationSec,
        'is_revive_check': isReviveCheck,
        // 复活检测题必须带 revive_result，后端据此分支处理；
        // 普通复习题不带，避免无意义字段。
        if (isReviveCheck && reviveResult != null)
          'revive_result': reviveResult,
      },
    );
  }

  /// 获取今日复习汇总（首页"查看复习"用，展示今日真实结果数据）
  Future<Map<String, dynamic>> getTodaySummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.reviewTodaySummary,
    );
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
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
