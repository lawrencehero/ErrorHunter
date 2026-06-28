/// 错题猎手 - OCR 文字区域组件
/// 含加载中骨架屏、失败状态、空结果状态
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import 'math_text.dart';

/// OCR 状态枚举
enum OcrStatus { loading, success, failed, empty }

/// OCR 文字区域
class OcrTextSection extends StatelessWidget {
  const OcrTextSection({
    super.key,
    required this.status,
    this.text,
    this.controller,
    this.onTextChanged,
    this.onRetry,
  });

  final OcrStatus status;
  final String? text;
  final TextEditingController? controller;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // 语义色玻璃下提亮
    final dangerGlass = isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    final warningGlass = isGlass ? const Color(0xFFFFB74D) : AppColors.warning;
    switch (status) {
      case OcrStatus.loading:
        return _buildLoadingState(tc: tc, isGlass: isGlass, accent: accent);
      case OcrStatus.success:
        return _buildSuccessState(tc: tc, isGlass: isGlass, accent: accent);
      case OcrStatus.failed:
        return _buildErrorContainer(
          tc: tc,
          isGlass: isGlass,
          icon: Icons.error_outline,
          iconColor: dangerGlass,
          message: '识别失败，请手动输入题目内容',
          showRetry: true,
          accent: accent,
        );
      case OcrStatus.empty:
        return _buildErrorContainer(
          tc: tc,
          isGlass: isGlass,
          icon: Icons.search_off_outlined,
          iconColor: warningGlass,
          message: '未识别到文字内容，请手动输入或重新拍摄 📸',
          showRetry: true,
          accent: accent,
        );
    }
  }

  Widget _buildLoadingState({
    required AppTextThemeColors tc,
    required bool isGlass,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              '正在识别...',
              style: AppTypography.primary.caption.copyWith(
                color: tc.secondary,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        // 骨架屏
        ...List.generate(4, (i) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isGlass
                      ? Colors.white.withOpacity(0.12)
                      : AppColors.border.withOpacity(0.3),
                  borderRadius: AppRadius.radiusSm,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSuccessState({
    required AppTextThemeColors tc,
    required bool isGlass,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '识别结果（可编辑）',
          style: AppTypography.primary.caption.copyWith(
            color: tc.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        // 公式预览：渲染 LaTeX，随编辑实时更新
        if (controller != null) ...[
          Container(
            width: double.infinity,
            padding: AppSpacing.cardInnerPadding,
            decoration: BoxDecoration(
              color: isGlass
                  ? Colors.white.withOpacity(0.12)
                  : AppColors.brandPrimaryPale.withOpacity(0.3),
              borderRadius: AppRadius.radiusMd,
              border: Border.all(
                color: isGlass
                    ? Colors.white.withOpacity(0.25)
                    : AppColors.brandPrimary.withOpacity(0.2),
              ),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (_, value, __) {
                final text = value.text;
                if (text.trim().isEmpty) {
                  return Text(
                    '识别内容将在此渲染公式预览',
                    style: AppTypography.primary.caption.copyWith(
                      color: tc.tertiary,
                    ),
                  );
                }
                return MathText(
                  text,
                  style: AppTypography.primary.body.copyWith(
                    color: tc.primary,
                  ),
                  mathStyle: AppTypography.primary.body.copyWith(
                    color: tc.primary,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '原始文本（可编辑纠错）',
            style: AppTypography.primary.caption.copyWith(
              color: tc.tertiary,
              fontSize: 11,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
        ],
        Container(
          decoration: BoxDecoration(
            color: isGlass ? Colors.white.withOpacity(0.12) : Colors.white,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isGlass
                  ? Colors.white.withOpacity(0.25)
                  : AppColors.border,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 6,
            style: AppTypography.primary.body.copyWith(
              color: tc.primary,
            ),
            decoration: InputDecoration(
              hintText: '输入题目内容...',
              hintStyle: AppTypography.primary.body.copyWith(
                color: tc.tertiary,
              ),
              contentPadding: AppSpacing.cardInnerPadding,
              border: InputBorder.none,
            ),
            onChanged: onTextChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContainer({
    required AppTextThemeColors tc,
    required bool isGlass,
    required IconData icon,
    required Color iconColor,
    required String message,
    bool showRetry = false,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: isGlass
                ? Colors.white.withOpacity(0.08)
                : iconColor.withOpacity(0.05),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isGlass
                  ? Colors.white.withOpacity(0.2)
                  : iconColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: iconColor),
              SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.primary.caption.copyWith(
                  color: tc.secondary,
                ),
              ),
              if (showRetry && onRetry != null) ...[
                SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    '点击重试',
                    style: AppTypography.primary.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        // 即使失败也提供手动输入框
        Text(
          '手动输入',
          style: AppTypography.primary.caption.copyWith(
            color: tc.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: isGlass ? Colors.white.withOpacity(0.12) : Colors.white,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isGlass
                  ? Colors.white.withOpacity(0.25)
                  : AppColors.border,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 6,
            style: AppTypography.primary.body.copyWith(
              color: tc.primary,
            ),
            decoration: InputDecoration(
              hintText: '在此输入题目内容...',
              hintStyle: AppTypography.primary.body.copyWith(
                color: tc.tertiary,
              ),
              contentPadding: AppSpacing.cardInnerPadding,
              border: InputBorder.none,
            ),
            onChanged: onTextChanged,
          ),
        ),
      ],
    );
  }
}
