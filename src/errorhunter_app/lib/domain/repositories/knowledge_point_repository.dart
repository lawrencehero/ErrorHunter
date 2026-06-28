/// 错题猎手 - KnowledgePoint Repository 抽象接口
library;

import '../../features/question/models/knowledge_point_model.dart';

/// 知识点仓库抽象
abstract class KnowledgePointRepository {
  /// 按年级 + 学科获取知识点
  Future<List<KnowledgePoint>> getByGrade({
    required String grade,
    String subject = '数学',
  });
}
