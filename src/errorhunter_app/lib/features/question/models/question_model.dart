/// 错题猎手 - 错题数据模型
library;

import 'package:equatable/equatable.dart';
import 'knowledge_point_model.dart';
import '../../../utils/image_url_helper.dart';

/// 错因分类枚举
enum ErrorCategory {
  knowledge('KNOWLEDGE', '不会做', '知识性错误', '🧠'),
  skill('SKILL', '算错了', '技能性错误', '✏️'),
  psychology('PSYCHOLOGY', '粗心了', '心理性错误', '😰'),
  habit('HABIT', '看错了', '习惯性错误', '📖'),
  unknown('UNKNOWN', '不确定', '不确定', '🤷');

  const ErrorCategory(this.code, this.shortLabel, this.label, this.emoji);

  final String code;
  final String shortLabel;
  final String label;
  final String emoji;

  static ErrorCategory fromCode(String code) {
    return ErrorCategory.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ErrorCategory.unknown,
    );
  }
}

/// 错题状态枚举
enum QuestionStatus {
  notStarted('NOT_STARTED', '未掌握'),
  reviewing('REVIEWING', '复习中'),
  mastered('MASTERED', '已消灭'),
  permanentlyMastered('PERMANENTLY_MASTERED', '永久消灭');

  const QuestionStatus(this.code, this.label);

  final String code;
  final String label;

  static QuestionStatus fromCode(String code) {
    return QuestionStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => QuestionStatus.notStarted,
    );
  }
}

/// 解题步骤
class SolutionStep extends Equatable {
  const SolutionStep({
    required this.stepNumber,
    required this.content,
    this.isErrorStep = false,
  });

  final int stepNumber;
  final String content;
  final bool isErrorStep;

  @override
  List<Object?> get props => [stepNumber, content, isErrorStep];
}

/// 复习记录
class ReviewRecord extends Equatable {
  const ReviewRecord({
    required this.id,
    required this.reviewRound,
    required this.reviewDate,
    required this.result,
    this.note,
    this.reviewDurationSec,
  });

  final String id;
  final int reviewRound;
  final DateTime reviewDate;

  /// 自评结果，对齐后端 SelfRating 枚举：MASTERED / PARTIAL / FAILED。
  /// 历史值 CORRECT/WRONG/PARTIAL 已弃用（与后端不一致），timeline 组件
  /// _resultColor/_resultLabel 同时兼容旧值以防本地缓存残留。
  final String result;
  final String? note;

  /// 复习用时（秒），后端 review_duration_sec，可空。
  final int? reviewDurationSec;

  @override
  List<Object?> get props => [id, reviewRound, reviewDate, result, note, reviewDurationSec];

  factory ReviewRecord.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return ReviewRecord(
      id: rawId is int ? rawId.toString() : rawId as String,
      reviewRound: (json['review_round'] as num?)?.toInt() ?? 0,
      reviewDate: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : DateTime.now(),
      // 后端 SelfRating：MASTERED / PARTIAL / FAILED
      result: json['self_rating'] as String? ??
          json['result'] as String? ??
          'FAILED',
      reviewDurationSec: (json['review_duration_sec'] as num?)?.toInt(),
    );
  }
}

/// 错题模型
class QuestionModel extends Equatable {
  const QuestionModel({
    required this.id,
    required this.imageUrl,
    this.ocrText,
    this.myAnswer,
    this.correctAnswer,
    required this.errorCategory,
    this.subCategories = const [],
    required this.status,
    required this.knowledgePoints,
    this.customTags = const [],
    this.solutionSteps = const [],
    this.reviewHistory = const [],
    this.currentReviewRound = 0,
    this.totalReviewRounds = 5,
    this.masterCount = 0,
    this.masteredAt,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.subject = '数学',
    this.grade,
  });

  final String id;
  final String imageUrl;
  final String? ocrText;
  final String? myAnswer;
  final String? correctAnswer;
  final ErrorCategory errorCategory;
  final List<String> subCategories;
  final QuestionStatus status;
  final List<KnowledgePoint> knowledgePoints;
  final List<String> customTags;
  final List<SolutionStep> solutionSteps;
  final List<ReviewRecord> reviewHistory;
  final int currentReviewRound;
  final int totalReviewRounds;

  /// 消灭计数（后端 master_count）：连续自评"掌握"累计，达 3 触发消灭。
  /// 后端 model.Question.MasterCount 已在 JSON 输出；前端原未解析，导致
  /// ReviewBloc._checkShouldEliminate 只能用 currentReviewRound 近似，与后端
  /// 真实状态错位（round=3 但 master_count=0 的题会被误判为可消灭）。
  final int masterCount;

  /// 消灭时间（后端 mastered_at）：用于计算复活检测"已消灭 N 天"。
  /// 可空：未消灭题为 null。
  final DateTime? masteredAt;

  final DateTime createdAt;
  final DateTime? updatedAt;

  /// 软删除时间（后端 deleted_at）：回收站列表用它计算"剩余保留天数"
  /// 与"删除时间"展示。非回收站场景为 null。
  final DateTime? deletedAt;

  final String subject;
  final String? grade;

  double get reviewProgress =>
      totalReviewRounds > 0 ? currentReviewRound / totalReviewRounds : 0.0;

  /// 错步骤的 0-based 索引（后端 error_step_index）；无错步骤返回 -1（toJson 不输出）。
  int get _errorStepIndex {
    final i = solutionSteps.indexWhere((s) => s.isErrorStep);
    return i;
  }

  bool get isEliminated =>
      status == QuestionStatus.mastered ||
      status == QuestionStatus.permanentlyMastered;

  @override
  List<Object?> get props => [
        id,
        imageUrl,
        ocrText,
        myAnswer,
        correctAnswer,
        errorCategory,
        subCategories,
        status,
        knowledgePoints,
        customTags,
        solutionSteps,
        currentReviewRound,
        totalReviewRounds,
        masterCount,
        masteredAt,
        createdAt,
        updatedAt,
        deletedAt,
      ];

  QuestionModel copyWith({
    String? id,
    String? imageUrl,
    String? ocrText,
    String? myAnswer,
    String? correctAnswer,
    ErrorCategory? errorCategory,
    List<String>? subCategories,
    QuestionStatus? status,
    List<KnowledgePoint>? knowledgePoints,
    List<String>? customTags,
    List<SolutionStep>? solutionSteps,
    List<ReviewRecord>? reviewHistory,
    int? currentReviewRound,
    int? totalReviewRounds,
    int? masterCount,
    DateTime? masteredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? subject,
    String? grade,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      ocrText: ocrText ?? this.ocrText,
      myAnswer: myAnswer ?? this.myAnswer,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      errorCategory: errorCategory ?? this.errorCategory,
      subCategories: subCategories ?? this.subCategories,
      status: status ?? this.status,
      knowledgePoints: knowledgePoints ?? this.knowledgePoints,
      customTags: customTags ?? this.customTags,
      solutionSteps: solutionSteps ?? this.solutionSteps,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      currentReviewRound: currentReviewRound ?? this.currentReviewRound,
      totalReviewRounds: totalReviewRounds ?? this.totalReviewRounds,
      masterCount: masterCount ?? this.masterCount,
      masteredAt: masteredAt ?? this.masteredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      if (ocrText != null) 'ocr_text': ocrText,
      if (myAnswer != null) 'my_answer': myAnswer,
      if (correctAnswer != null) 'correct_answer': correctAnswer,
      'error_category': errorCategory.code,
      'sub_categories': subCategories,
      'status': status.code,
      'knowledge_points': knowledgePoints.map((k) => k.toJson()).toList(),
      'custom_tags': customTags,
      'solution_steps': solutionSteps.map((s) => s.content).toList(),
      if (_errorStepIndex >= 0) 'error_step_index': _errorStepIndex,
      'review_round': currentReviewRound,
      'total_review_rounds': totalReviewRounds,
      'master_count': masterCount,
      if (masteredAt != null) 'mastered_at': masteredAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      'subject': subject,
      if (grade != null) 'grade': grade,
    };
  }

  /// 把后端 solution_steps（[]string）转成 List<SolutionStep>。
  /// errorStepIndex 为后端 0-based 错步骤索引，转成 1-based stepNumber 匹配。
  static List<SolutionStep> _parseSolutionSteps(
    Object? raw,
    int? errorStepIndex,
  ) {
    if (raw is! List) return const <SolutionStep>[];
    return raw.asMap().entries.map((entry) {
      final idx = entry.key;
      final content = entry.value?.toString() ?? '';
      return SolutionStep(
        stepNumber: idx + 1,
        content: content,
        isErrorStep: errorStepIndex != null && errorStepIndex == idx,
      );
    }).toList();
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return QuestionModel(
      id: rawId is int ? rawId.toString() : rawId as String,
      // 后端存的 image_url 可能是录入时的旧 host（如内网 IP），在 web/不同环境不可达。
      // 解析时统一归一化到当前后端 host，列表/详情/预览/复习卡所有展示点自动生效。
      imageUrl: normalizeImageUrl(json['image_url'] as String),
      ocrText: json['ocr_text'] as String?,
      myAnswer: json['my_answer'] as String?,
      correctAnswer: json['correct_answer'] as String?,
      errorCategory: ErrorCategory.fromCode(json['error_category'] as String),
      subCategories: List<String>.from(json['sub_categories'] ?? []),
      status: QuestionStatus.fromCode(json['status'] as String),
      knowledgePoints: (json['knowledge_points'] as List<dynamic>?)
              ?.map((k) =>
                  KnowledgePoint.fromJson(k as Map<String, dynamic>))
              .toList() ??
          [],
      customTags: List<String>.from(json['custom_tags'] ?? []),
      // 后端 solution_steps 是 []string（JSONB 字符串数组），前端模型用 List<SolutionStep>。
      // 这里把字符串列表转成 SolutionStep（stepNumber 从 1 起）。
      // error_step_index 标记错步骤（后端 0-based 索引，前端按 1-based stepNumber 匹配）。
      solutionSteps: _parseSolutionSteps(
        json['solution_steps'],
        json['error_step_index'] as int?,
      ),
      // 后端 json tag 为 "review_round"（model.Question.ReviewRound）。
      // 保留对旧 key "current_review_round" 的 fallback，防御缓存的旧 JSON / 本地序列化。
      currentReviewRound:
          (json['review_round'] ?? json['current_review_round']) as int? ?? 0,
      totalReviewRounds: json['total_review_rounds'] as int? ?? 5,
      // 后端 model.Question.MasterCount（json:"master_count"），默认 0。
      // 复习模块据此判定消灭（>=3），原前端未解析致与后端状态错位。
      masterCount: (json['master_count'] as num?)?.toInt() ?? 0,
      // 后端 model.Question.MasteredAt（json:"mastered_at,omitempty"），
      // 未消灭题为 null；复习模块据此计算复活检测"已消灭 N 天"。
      masteredAt: json['mastered_at'] != null
          ? DateTime.parse(json['mastered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // 后端 model.Question.DeletedAt（json:"deleted_at,omitempty"）：
      // 回收站列表用此字段计算"剩余保留天数"与"删除时间"展示；常规列表为 null。
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      subject: json['subject'] as String? ?? '数学',
      grade: json['grade'] as String?,
      // 后端 GetByID 详情返回 review_records（倒序限 20 条，含
      // id/review_round/reviewed_at/self_rating/review_duration_sec）。
      // 列表/复习队列不返回此字段 → 回退空复习历史。
      // 历史上详情接口不返回 review_records，详情页"复习历史"恒空。
      reviewHistory: (json['review_records'] as List<dynamic>?)
              ?.map((r) => ReviewRecord.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const <ReviewRecord>[],
    );
  }
}
