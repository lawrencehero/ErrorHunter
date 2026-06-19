/// 错题猎手 - 复习卡片正面组件
/// 题目展示 + 答案遮挡（毛玻璃效果）+ 显示答案按钮
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/buttons/secondary_button.dart';
import '../../question/models/question_model.dart';

/// 复习卡片正面
class ReviewCardFront extends StatelessWidget {
  const ReviewCardFront({
    super.key,
    required this.question,
    required this.onShowAnswer,
  });

  final QuestionModel question;
  final VoidCallback onShowAnswer;

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
          // ─── 题目展示区 ────────────────────────────────
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: _buildQuestionContent(),
              ),
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // ─── 答案遮挡区（毛玻璃效果）─────────────────
          _buildBlurredAnswerArea(),

          SizedBox(height: AppSpacing.lg),

          // ─── 显示答案按钮 ──────────────────────────────
          Center(
            child: EHSecondaryButton(
              text: '👁️ 显示答案',
              onPressed: onShowAnswer,
              size: EHButtonSize.lg,
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // ─── 底部提示 ──────────────────────────────────
          Center(
            child: Text(
              '💡 请在纸上重做，然后对照答案',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    // 如果有图片URL则显示图片，否则显示OCR文字
    if (question.imageUrl.isNotEmpty &&
        !question.imageUrl.startsWith('mock')) {
      return ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: Image.network(
          question.imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildTextFallback(),
        ),
      );
    }
    return _buildTextFallback();
  }

  Widget _buildTextFallback() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        question.ocrText ?? '暂无题目内容',
        style: AppTypography.primary.h3.copyWith(
          color: AppColors.textPrimary,
          height: 1.8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBlurredAnswerArea() {
    return ClipRRect(
      borderRadius: AppRadius.radiusMd,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.7),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: AppColors.border.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '▓▓▓ ',
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '答案已隐藏',
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ' ▓▓▓',
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
