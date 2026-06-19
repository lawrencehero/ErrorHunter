/// 错题猎手 - 复习卡片背面组件
/// 答案 + 解题过程 + 错因标签 + 自评按钮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../question/models/question_model.dart';
import '../models/review_report_model.dart';
import 'self_eval_buttons.dart';

/// 复习卡片背面
class ReviewCardBack extends StatelessWidget {
  const ReviewCardBack({
    super.key,
    required this.question,
    required this.isReviveCheck,
    required this.daysSinceLastMastered,
    required this.onEvaluate,
    this.selectedRating,
    this.evaluationLocked = false,
  });

  final QuestionModel question;
  final bool isReviveCheck;
  final int daysSinceLastMastered;
  final ValueChanged<SelfEvalRating> onEvaluate;
  final SelfEvalRating? selectedRating;
  final bool evaluationLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 复活检测标签（如有）──────────────────────
          if (isReviveCheck) _buildReviveBanner(),
          if (isReviveCheck) SizedBox(height: AppSpacing.sm),

          // ─── 可滚动内容区 ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 题目文字
                  if (question.ocrText != null) ...[
                    _SectionLabel(label: '📝 题目'),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      question.ocrText!,
                      style: AppTypography.primary.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.base),
                  ],

                  // 正确答案
                  if (question.correctAnswer != null) ...[
                    _SectionLabel(label: '✅ 正确答案'),
                    SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Text(
                        question.correctAnswer!,
                        style: AppTypography.primary.body.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                  ],

                  // 解题过程
                  if (question.solutionSteps.isNotEmpty) ...[
                    _SectionLabel(label: '📖 解题过程'),
                    SizedBox(height: AppSpacing.xs),
                    ...question.solutionSteps.map((step) => Padding(
                          padding:
                              EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: step.isErrorStep
                                      ? AppColors.danger
                                          .withOpacity(0.15)
                                      : AppColors.brandPrimary
                                          .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${step.stepNumber}',
                                  style: AppTypography.primary.caption
                                      .copyWith(
                                    color: step.isErrorStep
                                        ? AppColors.danger
                                        : AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  step.content,
                                  style: AppTypography.primary.body
                                      .copyWith(
                                    color: step.isErrorStep
                                        ? AppColors.danger
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    SizedBox(height: AppSpacing.md),
                  ],

                  // 你的错误答案
                  if (question.myAnswer != null) ...[
                    _SectionLabel(label: '❌ 你的答案'),
                    SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Text(
                        question.myAnswer!,
                        style: AppTypography.primary.body.copyWith(
                          color: AppColors.danger,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                  ],

                  // 错因 + 知识点标签
                  _buildTags(),
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // ─── 自评按钮 ──────────────────────────────────
          SelfEvalButtons(
            onEvaluate: onEvaluate,
            selectedRating: selectedRating,
            isReviveMode: isReviveCheck,
            enabled: !evaluationLocked,
          ),
        ],
      ),
    );
  }

  Widget _buildReviveBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: AppRadius.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 16)),
              SizedBox(width: AppSpacing.xs),
              Text(
                '复习巩固',
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            '这道题消灭已经 $daysSinceLastMastered 天了，来确认一下还记不记得吧！',
            style: AppTypography.primary.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // 错因标签
        _TagChip(
          emoji: question.errorCategory.emoji,
          label: question.errorCategory.shortLabel,
          color: AppColors.errorCategoryColor(question.errorCategory.code),
        ),
        // 知识点标签
        ...question.knowledgePoints.map(
          (kp) => _TagChip(
            emoji: '🏷️',
            label: kp.name,
            color: AppColors.brandPrimary,
          ),
        ),
        // 自定义标签
        ...question.customTags.map(
          (tag) => _TagChip(
            emoji: '#',
            label: tag,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 区块标签
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.primary.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 标签 Chip
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.primary.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
