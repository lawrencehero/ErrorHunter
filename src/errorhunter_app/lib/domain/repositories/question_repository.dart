/// 错题猎手 - Question Repository 抽象接口
/// 定义错题管理相关的数据访问契约
library;

import '../../features/question/models/question_model.dart';
import '../../features/question/models/ocr_result.dart';

/// 错题仓库抽象
abstract class QuestionRepository {
  /// 获取错题列表（支持筛选）
  Future<List<QuestionModel>> getQuestions({
    ErrorCategory? category,
    QuestionStatus? status,
    String? knowledgePointId,
    String? tag,
    int page = 1,
  });

  /// 获取当前用户错题的去重自定义标签列表
  Future<List<String>> getTags();

  /// 搜索错题
  Future<List<QuestionModel>> searchQuestions(String keyword);

  /// 获取错题详情
  Future<QuestionModel?> getQuestionDetail(String id);

  /// 新增错题
  Future<QuestionModel> addQuestion(QuestionModel question);

  /// 更新错题
  Future<void> updateQuestion(QuestionModel question);

  /// 软删除错题
  Future<void> deleteQuestion(String id);

  /// 回收站列表（已软删除的错题）
  Future<List<QuestionModel>> getRecycleBin({
    int page = 1,
    int pageSize = 20,
  });

  /// 恢复错题（从回收站还原）
  Future<void> restoreQuestion(String id);

  /// 永久删除错题（不可恢复）
  Future<void> permanentDeleteQuestion(String id);

  /// 清空回收站，返回删除条数
  Future<int> clearRecycleBin();

  /// OCR 识别图片
  Future<OcrResult> ocrImage(String imagePath);
}
