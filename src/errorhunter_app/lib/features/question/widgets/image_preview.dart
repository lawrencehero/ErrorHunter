/// 错题猎手 - 图片放大预览组件（双指缩放）
/// 支持本地文件路径和网络 URL
library;

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';

/// 图片放大预览（支持双指缩放和拖拽）
class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  final String imageUrl;
  final String? heroTag;

  /// 显示全屏预览
  static void show(BuildContext context, String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePreview(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ImagePreview.show(context, widget.imageUrl, heroTag: widget.heroTag),
      child: Hero(
        tag: widget.heroTag ?? widget.imageUrl,
        child: _buildImage(widget.imageUrl, BoxFit.contain),
      ),
    );
  }
}

/// 根据路径类型构建 Image widget
Widget _buildImage(String path, BoxFit fit) {
  if (kIsWeb || path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(
      path,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final isGlass = context.themeExt.isDarkBackground;
        final accent =
            isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
      errorBuilder: (context, _, __) => _buildErrorPlaceholder(context),
    );
  }

  // 本地文件
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: (context, _, __) => _buildErrorPlaceholder(context),
  );
}

/// 图片加载失败的占位符（玻璃下使用半透明白底 + 提亮图标）
Widget _buildErrorPlaceholder(BuildContext context) {
  final isGlass = context.themeExt.isDarkBackground;
  final tc = context.textColors;
  return Container(
    color: isGlass ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
    child: Center(
      child: Icon(Icons.image_not_supported,
          color: tc.tertiary, size: 48),
    ),
  );
}

/// 全屏查看器
class _FullScreenImagePreview extends StatefulWidget {
  const _FullScreenImagePreview({
    required this.imageUrl,
    this.heroTag,
  });

  final String imageUrl;
  final String? heroTag;

  @override
  State<_FullScreenImagePreview> createState() => _FullScreenImagePreviewState();
}

class _FullScreenImagePreviewState extends State<_FullScreenImagePreview> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          child: Hero(
            tag: widget.heroTag ?? widget.imageUrl,
            child: _buildImage(widget.imageUrl, BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
