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
}
