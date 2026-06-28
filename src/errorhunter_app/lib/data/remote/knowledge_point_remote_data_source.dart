/// 错题猎手 - Knowledge Point Remote Data Source
/// 调用后端 /v1/knowledge-points 接口获取知识点
library;

import '../../features/question/models/knowledge_point_model.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// KnowledgePoint 远程数据源
class KnowledgePointRemoteDataSource {
  KnowledgePointRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 按年级 + 学科获取知识点
  Future<List<KnowledgePoint>> getByGrade({
    required String grade,
    String subject = '数学',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.knowledgePoints,
      queryParameters: {'grade': grade, 'subject': subject},
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? [];

    return items
        .map((item) => KnowledgePoint.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
