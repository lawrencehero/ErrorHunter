/// 错题猎手 - 复习卡片背面组件
/// 答案 + 解题过程 + 错因标签 + 自评按钮
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../question/models/question_model.dart';
import '../../question/widgets/math_text.dart';
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
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.12) : AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25)) : null,
        boxShadow: isGlass
            ? null
            : [
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
          if (isReviveCheck) _buildReviveBanner(tc),
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
                    MathText(
                      question.ocrText!,
                      style: AppTypography.primary.body.copyWith(
                        color: tc.primary,
                      ),
                      mathStyle: AppTypography.primary.body.copyWith(
                        color: tc.primary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.base),
                  ],

                  // 正确答案
                  if (question.correctAnswer != null) ...[
                    _SectionLabel(label: '✅ 正确答案'),
                    SizedBox(height: AppSpacing.xs),
                    if (question.correctAnswer!.trim().isEmpty)
                      _buildEmptyAnswerHint(tc)
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.08),
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: MathText(
                          question.correctAnswer!,
                          style: AppTypography.primary.body.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                          mathStyle: AppTypography.primary.body.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.md),
                  ] else ...[
                    // correctAnswer 为 null（后端未返回该字段）也要提示，
                    // 否则用户点"显示答案"看不到任何反馈。
                    _SectionLabel(label: '✅ 正确答案'),
                    SizedBox(height: AppSpacing.xs),
                    _buildEmptyAnswerHint(tc),
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
                                      : (isGlass
                                          ? const Color(0xFFFFB74D)
                                          : AppColors.brandPrimary)
                                          .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${step.stepNumber}',
                                  style: AppTypography.primary.caption
                                      .copyWith(
                                    color: step.isErrorStep
                                        ? AppColors.danger
                                        : (isGlass
                                            ? const Color(0xFFFFB74D)
                                            : AppColors.brandPrimary),
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
                                        : tc.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    SizedBox(height: AppSpacing.md),
                  ],

                  // 你的错误答案
                  if (question.myAnswer != null &&
                      question.myAnswer!.trim().isNotEmpty) ...[
                    _SectionLabel(label: '❌ 你的答案'),
                    SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: MathText(
                        question.myAnswer!,
                        style: AppTypography.primary.body.copyWith(
                          color: AppColors.danger,
                          decoration: TextDecoration.lineThrough,
                        ),
                        mathStyle: AppTypography.primary.body.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                  ],

                  // 错因 + 知识点标签
                  _buildTags(tc, isGlass),
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

  /// 正确答案为空（null 或空串）时的弱化提示块。
  /// 用 info 图标 + tertiary 色，避免被误读为"做错了"。
  Widget _buildEmptyAnswerHint(AppTextThemeColors tc) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: tc.tertiary.withOpacity(0.06),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: tc.tertiary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text('ℹ️', style: TextStyle(fontSize: 14, color: tc.tertiary)),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '未设置正确答案',
              style: AppTypography.primary.body.copyWith(
                color: tc.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviveBanner(AppTextThemeColors tc) {
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
              color: tc.secondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(AppTextThemeColors tc, bool isGlass) {
    final kpColor = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
            color: kpColor,
          ),
        ),
        // 自定义标签
        ...question.customTags.map(
          (tag) => _TagChip(
            emoji: '#',
            label: tag,
            color: tc.secondary,
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
    final tc = context.textColors;
    return Text(
      label,
      style: AppTypography.primary.caption.copyWith(
        color: tc.secondary,
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
