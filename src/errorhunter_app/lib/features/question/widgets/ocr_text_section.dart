/// 错题猎手 - OCR 文字区域组件
/// 含加载中骨架屏、失败状态、空结果状态
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

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
    switch (status) {
      case OcrStatus.loading:
        return _buildLoadingState();
      case OcrStatus.success:
        return _buildSuccessState();
      case OcrStatus.failed:
        return _buildFailedState();
      case OcrStatus.empty:
        return _buildEmptyState();
    }
  }

  Widget _buildLoadingState() {
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
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              '正在识别...',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.textSecondary,
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
                  color: AppColors.border.withOpacity(0.3),
                  borderRadius: AppRadius.radiusSm,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '识别结果（可编辑）',
          style: AppTypography.primary.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            maxLines: 6,
            style: AppTypography.primary.body.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '输入题目内容...',
              hintStyle: AppTypography.primary.body.copyWith(
                color: AppColors.textTertiary,
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

  Widget _buildFailedState() {
    return _buildErrorContainer(
      icon: Icons.error_outline,
      iconColor: AppColors.danger,
      message: '识别失败，请手动输入题目内容',
      showRetry: true,
    );
  }

  Widget _buildEmptyState() {
    return _buildErrorContainer(
      icon: Icons.search_off_outlined,
      iconColor: AppColors.warning,
      message: '未识别到文字内容，请手动输入或重新拍摄 📸',
      showRetry: true,
    );
  }

  Widget _buildErrorContainer({
    required IconData icon,
    required Color iconColor,
    required String message,
    bool showRetry = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.05),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: iconColor.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: iconColor),
              SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (showRetry && onRetry != null) ...[
                SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    '点击重试',
                    style: AppTypography.primary.caption.copyWith(
                      color: AppColors.brandPrimary,
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
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            maxLines: 6,
            style: AppTypography.primary.body.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '在此输入题目内容...',
              hintStyle: AppTypography.primary.body.copyWith(
                color: AppColors.textTertiary,
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
