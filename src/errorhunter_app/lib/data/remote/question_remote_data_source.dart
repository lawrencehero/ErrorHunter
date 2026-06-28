/// 错题猎手 - Question Remote Data Source
/// 调用后端错题 API，替代 MockQuestionDataSource
library;

import 'package:dio/dio.dart';

import '../../features/question/models/question_model.dart';
import '../../features/question/models/ocr_result.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// Question 远程数据源 — 对接后端 /v1/questions/* 接口
class QuestionRemoteDataSource {
  QuestionRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 获取错题列表（支持筛选）
  Future<List<QuestionModel>> getQuestions({
    String? category,
    String? status,
    String? knowledgePointId,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      if (category != null) 'error_category': category,
      if (status != null) 'status': status,
      if (knowledgePointId != null) 'knowledge_point_id': knowledgePointId,
    };

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.questions,
      queryParameters: queryParams,
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = (data?['list'] ?? data?['items']) as List<dynamic>? ?? [];

    return items
        .map((item) =>
            QuestionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 搜索错题
  Future<List<QuestionModel>> searchQuestions(String keyword) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.questions,
      queryParameters: {'q': keyword},
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = (data?['list'] ?? data?['items']) as List<dynamic>? ?? [];

    return items
        .map((item) =>
            QuestionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 获取错题详情
  Future<QuestionModel?> getQuestionDetail(String id) async {
    try {
      final endpoint = ApiEndpoints.withId(ApiEndpoints.questionDetail, id);
      final response = await _client.get<Map<String, dynamic>>(endpoint);

      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      return QuestionModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 新增错题
  Future<QuestionModel> addQuestion(QuestionModel question) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.questions,
      data: question.toJson(),
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to create question');
    }

    return QuestionModel.fromJson(data);
  }

  /// 更新错题
  Future<void> updateQuestion(QuestionModel question) async {
    final endpoint =
        ApiEndpoints.withId(ApiEndpoints.questionDetail, question.id);
    await _client.put(endpoint, data: question.toJson());
  }

  /// 软删除错题
  Future<void> deleteQuestion(String id) async {
    final endpoint = ApiEndpoints.withId(ApiEndpoints.questionDetail, id);
    await _client.delete(endpoint);
  }

  /// OCR 识别图片（两步：先上传图片，再调 OCR）
  Future<OcrResult> ocrImage(String imagePath) async {
    // Step 1: 上传图片到 MinIO
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
    });

    final uploadResponse = await _client.upload<Map<String, dynamic>>(
      ApiEndpoints.upload,
      formData: formData,
    );

    final uploadData = uploadResponse.data?['data'] as Map<String, dynamic>?;
    final imageUrl = uploadData?['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('图片上传失败');
    }

    // Step 2: 调用 OCR 识别
    final ocrResponse = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.ocrRecognize,
      data: {'image_url': imageUrl},
    );

    final ocrData = ocrResponse.data?['data'] as Map<String, dynamic>?;
    final text = ocrData?['text'] as String? ?? '';
    final figuresRaw = ocrData?['figures'] as List<dynamic>? ?? [];
    final figures = figuresRaw
        .map((e) => OcrFigure.fromJson(e as Map<String, dynamic>))
        .where((f) => f.width > 0 && f.height > 0)
        .toList();
    // imageUrl 是上传到对象存储后的可访问 URL，保存错题时用它（而非本地临时路径）
    return OcrResult(text: text, imageUrl: imageUrl, figures: figures);
  }
}
