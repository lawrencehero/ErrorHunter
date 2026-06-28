/// 错题猎手 - 复习卡片正面组件
/// 题目展示 + 答案遮挡（毛玻璃效果）+ 显示答案按钮
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../utils/image_url_helper.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/buttons/secondary_button.dart';
import '../../question/models/question_model.dart';
import '../../question/widgets/math_text.dart';

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
          // ─── 题目展示区 ────────────────────────────────
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: _buildQuestionContent(tc, isGlass),
              ),
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // ─── 答案遮挡区（毛玻璃效果）─────────────────
          _buildBlurredAnswerArea(tc, isGlass),

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
                color: tc.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(AppTextThemeColors tc, bool isGlass) {
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // 如果有图片URL则显示图片，否则显示OCR文字
    if (question.imageUrl.isNotEmpty &&
        !question.imageUrl.startsWith('mock')) {
      final normalizedUrl = normalizeImageUrl(question.imageUrl);
      return ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: Image.network(
          normalizedUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: accent,
              ),
            );
          },
          // 图片加载失败时回退到 OCR 文本（用 MathText 渲染 LaTeX 公式），
          // 不再让用户看到几十秒的转圈 + 原始 \frac{} 文本。
          errorBuilder: (_, __, ___) => _buildTextFallback(tc),
        ),
      );
    }
    return _buildTextFallback(tc);
  }

  Widget _buildTextFallback(AppTextThemeColors tc) {
    final textStyle = AppTypography.primary.h3.copyWith(
      color: tc.primary,
      height: 1.8,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      // OCR 文本可能含 LaTeX（如 \frac{3}{4}、\angle），用 MathText 内联渲染，
      // 解析失败的公式段会回退纯文本。MathText 支持 textAlign 仅作用于纯文本行。
      child: MathText(
        question.ocrText ?? '暂无题目内容',
        style: textStyle,
        mathStyle: textStyle,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBlurredAnswerArea(AppTextThemeColors tc, bool isGlass) {
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
            // 玻璃下用半透明白叠毛玻璃；游戏化沿用近白底色。
            color: isGlass
                ? Colors.white.withOpacity(0.18)
                : AppColors.background.withOpacity(0.7),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isGlass
                  ? Colors.white.withOpacity(0.3)
                  : AppColors.border.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '▓▓▓ ',
                style: AppTypography.primary.body.copyWith(
                  color: tc.tertiary,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '答案已隐藏',
                style: AppTypography.primary.body.copyWith(
                  color: tc.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ' ▓▓▓',
                style: AppTypography.primary.body.copyWith(
                  color: tc.tertiary,
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
