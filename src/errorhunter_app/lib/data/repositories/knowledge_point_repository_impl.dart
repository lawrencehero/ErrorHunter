/// 错题猎手 - KnowledgePoint Repository 实现
library;

import '../../domain/repositories/knowledge_point_repository.dart';
import '../../features/question/models/knowledge_point_model.dart';
import '../remote/knowledge_point_remote_data_source.dart';

class KnowledgePointRepositoryImpl implements KnowledgePointRepository {
  KnowledgePointRepositoryImpl({
    required KnowledgePointRemoteDataSource dataSource,
  }) : _dataSource = dataSource;

  final KnowledgePointRemoteDataSource _dataSource;

  @override
  Future<List<KnowledgePoint>> getByGrade({
    required String grade,
    String subject = '数学',
  }) {
    return _dataSource.getByGrade(grade: grade, subject: subject);
  }
}
