/// 错题猎手 - Review Repository 抽象接口
/// 定义复习流程相关的数据访问契约
library;

import '../../features/question/models/question_model.dart';

/// 复习仓库抽象
abstract class ReviewRepository {
  /// 获取复习队列
  Future<List<QuestionModel>> getReviewQueue({List<String>? questionIds});

  /// 获取连续打卡天数
  Future<int> getStreakDays();

  /// 提交单题复习结果到后端。
  ///
  /// [selfRating] 为已映射到后端的字符串（MASTERED/PARTIAL/FAILED），
  /// 映射逻辑放在 ReviewBloc._mapToBackendRating，repository 透传。
  /// 提交失败由调用方 try/catch 容错，不阻断复习流程。
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
    bool isReviveCheck = false,
  });
}
