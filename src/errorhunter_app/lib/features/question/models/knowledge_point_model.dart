/// 错题猎手 - 知识点数据模型
library;

import 'package:equatable/equatable.dart';

/// 知识点模型
class KnowledgePoint extends Equatable {
  const KnowledgePoint({
    required this.id,
    required this.name,
    required this.subject,
    this.parentId,
    this.isRecommended = false,
  });

  final String id;
  final String name;
  final String subject;
  final String? parentId;

  /// AI 推荐标记
  final bool isRecommended;

  @override
  List<Object?> get props => [id, name, subject, parentId, isRecommended];

  KnowledgePoint copyWith({
    String? id,
    String? name,
    String? subject,
    String? parentId,
    bool? isRecommended,
  }) {
    return KnowledgePoint(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      parentId: parentId ?? this.parentId,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'is_recommended': isRecommended,
      if (parentId != null) 'parent_id': parentId,
    };
  }

  factory KnowledgePoint.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawParent = json['parent_id'];
    return KnowledgePoint(
      id: rawId is int ? rawId.toString() : rawId as String,
      name: json['name'] as String? ?? '',
      subject: json['subject'] as String? ?? '数学',
      parentId: rawParent == null
          ? null
          : (rawParent is int ? rawParent.toString() : rawParent as String),
      isRecommended: json['is_recommended'] as bool? ?? false,
    );
  }
}
