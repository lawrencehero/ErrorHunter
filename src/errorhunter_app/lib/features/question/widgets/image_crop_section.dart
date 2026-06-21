/// 错题猎手 - 拍照裁剪区域组件 V2.0
/// 支持 Web 环境下的 Mock 预览
library;

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// 拍照裁剪区域
class ImageCropSection extends StatefulWidget {
  const ImageCropSection({
    super.key,
    this.imagePath,
    this.onTakePhoto,
    this.onPickFromGallery,
    this.onCropConfirm,
  });

  /// 已选图片路径
  final String? imagePath;

  /// 拍照回调
  final VoidCallback? onTakePhoto;

  /// 从相册选择回调
  final VoidCallback? onPickFromGallery;

  /// 裁剪确认回调
  final ValueChanged<String>? onCropConfirm;

  @override
  State<ImageCropSection> createState() => _ImageCropSectionState();
}

class _ImageCropSectionState extends State<ImageCropSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 图片预览区域（限制高度，防止按钮被挤出屏幕）
        Flexible(
          flex: 3,
          child: Container(
            margin: AppSpacing.pagePadding,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: widget.imagePath != null
                ? _buildImagePreview()
                : _buildCameraPlaceholder(),
          ),
        ),

        SizedBox(height: AppSpacing.md),

        // 提示文字
        Padding(
          padding: AppSpacing.pagePadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: AppColors.brandSecondary),
              SizedBox(width: AppSpacing.xs),
              Text(
                '对准题目拍摄，系统自动识别',
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: AppSpacing.md),

        // 底部操作按钮
        Padding(
          padding: AppSpacing.pagePadding,
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: '拍照',
                  onTap: widget.onTakePhoto,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionButton(
                  icon: Icons.photo_library_outlined,
                  label: '从相册选择',
                  onTap: widget.onPickFromGallery,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    // Web 环境下的 Mock 图片预览
    if (kIsWeb || widget.imagePath == 'demo_question.jpg') {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.background,
                  AppColors.brandPrimaryPale,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: AppRadius.radiusLg,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.brandGlow,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    '✅ 示例图片已就绪',
                    style: AppTypography.primary.h3.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    '点击右上角「下一步」继续',
                    style: AppTypography.primary.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _CropFramePainter()),
          ),
        ],
      );
    }

    // 原生环境：真实图片预览
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: AppRadius.radiusLg,
          child: Image.file(
            File(widget.imagePath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildCameraPlaceholder(),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _CropFramePainter()),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '点击下方按钮拍照或选择图片',
            style: AppTypography.primary.body.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.brandPrimary),
            SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.primary.button.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 裁剪框绘制
class _CropFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandPrimary.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLength = 24.0;
    final rect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.8,
    );

    final path = Path();
    // Top-left
    path.moveTo(rect.left, rect.top + cornerLength);
    path.lineTo(rect.left, rect.top);
    path.lineTo(rect.left + cornerLength, rect.top);
    // Top-right
    path.moveTo(rect.right - cornerLength, rect.top);
    path.lineTo(rect.right, rect.top);
    path.lineTo(rect.right, rect.top + cornerLength);
    // Bottom-right
    path.moveTo(rect.right, rect.bottom - cornerLength);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.right - cornerLength, rect.bottom);
    // Bottom-left
    path.moveTo(rect.left + cornerLength, rect.bottom);
    path.lineTo(rect.left, rect.bottom);
    path.lineTo(rect.left, rect.bottom - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
