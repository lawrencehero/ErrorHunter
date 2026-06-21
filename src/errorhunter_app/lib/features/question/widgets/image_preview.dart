/// 错题猎手 - 图片放大预览组件（双指缩放）
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

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
        child: Image.network(
          widget.imageUrl,
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
                color: AppColors.brandPrimary,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade100,
            child: Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 48),
            ),
          ),
        ),
      ),
    );
  }
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
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
