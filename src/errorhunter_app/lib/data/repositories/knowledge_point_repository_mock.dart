/// 错题猎手 - KnowledgePoint Repository Mock（useMock 模式用）
library;

import '../../domain/repositories/knowledge_point_repository.dart';
import '../../features/question/models/knowledge_point_model.dart';

class KnowledgePointRepositoryMock implements KnowledgePointRepository {
  @override
  Future<List<KnowledgePoint>> getByGrade({
    required String grade,
    String subject = '数学',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const <KnowledgePoint>[
      KnowledgePoint(
        id: 'mock_1',
        name: '四则运算',
        subject: '数学',
        parentId: 'num',
        isRecommended: true,
      ),
      KnowledgePoint(
        id: 'mock_2',
        name: '分数运算',
        subject: '数学',
        parentId: 'num',
        isRecommended: true,
      ),
      KnowledgePoint(
        id: 'mock_3',
        name: '几何图形',
        subject: '数学',
        parentId: 'geo',
      ),
      KnowledgePoint(
        id: 'mock_4',
        name: '统计图表',
        subject: '数学',
        parentId: 'stat',
      ),
    ];
  }
}
