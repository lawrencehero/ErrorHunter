/// 错题猎手 - 拍照裁剪区域组件 V3.0
/// 支持交互式裁剪框 + Web 环境 Mock 预览
library;

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import 'interactive_crop_frame.dart';

/// 拍照裁剪区域
class ImageCropSection extends StatefulWidget {
  const ImageCropSection({
    super.key,
    this.imagePath,
    this.onTakePhoto,
    this.onPickFromGallery,
    this.onCropChanged,
    this.imageSize,
  });

  /// 已选图片路径
  final String? imagePath;

  /// 拍照回调
  final VoidCallback? onTakePhoto;

  /// 从相册选择回调
  final VoidCallback? onPickFromGallery;

  /// 裁剪区域变化回调（比例坐标 0.0~1.0，相对于图片实际显示区域）
  final ValueChanged<Rect>? onCropChanged;

  /// 图片真实宽高（用于 BoxFit.contain 计算）
  final Size? imageSize;

  @override
  State<ImageCropSection> createState() => _ImageCropSectionState();
}

class _ImageCropSectionState extends State<ImageCropSection> {
  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // 图片预览区域（限制最大高度，防止按钮被挤出屏幕）
          Expanded(
            child: Container(
              margin: AppSpacing.pagePadding,
              decoration: BoxDecoration(
                color: isGlass
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: isGlass
                      ? Colors.white.withOpacity(0.25)
                      : AppColors.border,
                ),
              ),
              child: widget.imagePath != null
                  ? _buildImagePreview(isGlass: isGlass, accent: accent)
                  : _buildCameraPlaceholder(isGlass: isGlass),
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // 提示文字
          Padding(
            padding: AppSpacing.pagePadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.crop_free_rounded, size: 16, color: accent),
                SizedBox(width: AppSpacing.xs),
                Text(
                  widget.imagePath != null
                      ? '拖动边框调整截取区域'
                      : '对准题目拍摄，系统自动识别',
                  style: AppTypography.primary.caption.copyWith(
                    color: tc.secondary,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // 底部操作按钮
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.base,
              0,
              AppSpacing.base,
              AppSpacing.base,
            ),
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
      ),
    );
  }

  Widget _buildImagePreview({required bool isGlass, required Color accent}) {
    final tc = context.textColors;
    // Web 环境下的 Mock 图片预览
    if (kIsWeb || widget.imagePath == 'demo_question.jpg') {
      return InteractiveCropFrame(
        onCropChanged: widget.onCropChanged,
        imageSize: widget.imageSize,
        isGlass: isGlass,
        accentColor: accent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isGlass
                  ? [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.04),
                    ]
                  : [
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
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: isGlass ? null : AppShadows.brandGlow,
                  ),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 32),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  '✅ 示例图片已就绪',
                  style: AppTypography.primary.h3.copyWith(
                    color: isGlass ? tc.primary : accent,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '拖动边框调整截取区域',
                  style: AppTypography.primary.caption.copyWith(
                    color: tc.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 原生环境：真实图片 + 交互式裁剪框
    return InteractiveCropFrame(
      onCropChanged: widget.onCropChanged,
      imageSize: widget.imageSize,
      isGlass: isGlass,
      accentColor: accent,
      child: ClipRRect(
        borderRadius: AppRadius.radiusLg,
        child: Image.file(
          File(widget.imagePath!),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              _buildCameraPlaceholder(isGlass: isGlass),
        ),
      ),
    );
  }

  Widget _buildCameraPlaceholder({required bool isGlass}) {
    final tc = context.textColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: tc.tertiary,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '点击下方按钮拍照或选择图片',
            style: AppTypography.primary.body.copyWith(
              color: tc.tertiary,
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
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isGlass
              ? Colors.white.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isGlass
                ? Colors.white.withOpacity(0.25)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accent),
            SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.primary.button.copyWith(
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

