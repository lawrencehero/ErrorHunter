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
  });

  final String id;
  final int reviewRound;
  final DateTime reviewDate;
  final String result; // CORRECT / WRONG / PARTIAL
  final String? note;

  @override
  List<Object?> get props => [id, reviewRound, reviewDate, result, note];
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
    required this.createdAt,
    this.updatedAt,
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
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String subject;
  final String? grade;

  double get reviewProgress =>
      totalReviewRounds > 0 ? currentReviewRound / totalReviewRounds : 0.0;

  bool get isEliminated =>
      status == QuestionStatus.mastered ||
      status == QuestionStatus.permanentlyMastered;

  @override
  List<Object?> get props => [
        id,
        imageUrl,
        ocrText,
        errorCategory,
        status,
        currentReviewRound,
        createdAt,
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'review_round': currentReviewRound,
      'total_review_rounds': totalReviewRounds,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'subject': subject,
      if (grade != null) 'grade': grade,
    };
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
      // 后端 json tag 为 "review_round"（model.Question.ReviewRound）。
      // 保留对旧 key "current_review_round" 的 fallback，防御缓存的旧 JSON / 本地序列化。
      currentReviewRound:
          (json['review_round'] ?? json['current_review_round']) as int? ?? 0,
      totalReviewRounds: json['total_review_rounds'] as int? ?? 5,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      subject: json['subject'] as String? ?? '数学',
      grade: json['grade'] as String?,
    );
  }
}
