/// 错题猎手 - 交互式图片裁剪框
/// 纯 Flutter 实现，无第三方依赖
/// 支持：拖拽移动、四角/四边缩放、最小尺寸约束、井字网格
///
/// 关键设计：onCropChanged 返回的 Rect 是**图片坐标**（0.0~1.0，相对于图片实际显示区域）
/// 解决了 Bug #2：图片用 BoxFit.contain 显示时，容器坐标与图片坐标不一致
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// 交互式裁剪框，覆盖在图片上方
class InteractiveCropFrame extends StatefulWidget {
  const InteractiveCropFrame({
    super.key,
    required this.child,
    this.onCropChanged,
    this.showGrid = true,
    /// 图片真实宽高（用于 BoxFit.contain 计算）
    /// null 表示假设图片填满容器（不常用）
    this.imageSize,
    /// 玻璃拟态主题下角标/手柄边框使用 accent 色而非品牌蓝
    this.isGlass = false,
    /// 自定义强调色（默认品牌蓝；玻璃下传暖琥珀）
    this.accentColor,
  });

  /// 底层图片 Widget
  final Widget child;

  /// 裁剪区域变化回调（相对于图片的比例坐标 0.0~1.0）
  final ValueChanged<Rect>? onCropChanged;

  /// 是否显示井字网格
  final bool showGrid;

  /// 图片真实宽高（可选，传入后坐标转换更精确）
  final Size? imageSize;

  /// 是否处于玻璃拟态主题（影响角标/手柄配色）
  final bool isGlass;

  /// 强调色（玻璃下应为暖琥珀，默认品牌蓝）
  final Color? accentColor;

  @override
  State<InteractiveCropFrame> createState() => _InteractiveCropFrameState();
}

class _InteractiveCropFrameState extends State<InteractiveCropFrame> {
  /// 裁剪框在图片坐标中的比例矩形（0.0~1.0）
  late Rect _cropRect;

  /// 拖拽类型
  _DragMode _dragMode = _DragMode.none;

  /// 拖拽起始时的裁剪框
  Rect _dragStartRect = Rect.zero;

  /// 最小裁剪框比例（相对于图片）
  static const double _minWidthRatio = 0.15;
  static const double _minHeightRatio = 0.1;

  /// 手柄尺寸
  static const double _handleSize = 14.0;
  static const double _handleHitArea = 32.0;

  /// 角标线条长度
  static const double _cornerLength = 24.0;

  @override
  void initState() {
    super.initState();
    // 默认为图片 90% 区域，居中
    _cropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifyCropChanged();
  }

  void _notifyCropChanged() {
    widget.onCropChanged?.call(_cropRect);
  }

  /// 计算图片在容器中按 BoxFit.contain 显示的实际区域
  Rect _calcDisplayRect(Size containerSize) {
    if (widget.imageSize == null) {
      // 不知道图片尺寸，假设填满
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }
    final imageW = widget.imageSize!.width;
    final imageH = widget.imageSize!.height;
    final containerW = containerSize.width;
    final containerH = containerSize.height;
    final imageAspect = imageW / imageH;
    final containerAspect = containerW / containerH;

    if (imageAspect > containerAspect) {
      // 图片更宽，宽度撑满
      final displayH = containerW / imageAspect;
      return Rect.fromLTWH(
        0,
        (containerH - displayH) / 2,
        containerW,
        displayH,
      );
    } else {
      // 图片更高，高度撑满
      final displayW = containerH * imageAspect;
      return Rect.fromLTWH(
        (containerW - displayW) / 2,
        0,
        displayW,
        containerH,
      );
    }
  }

  /// 容器坐标 → 图片坐标（0.0~1.0）
  Rect _containerToImage(Rect containerRect, Size containerSize) {
    final display = _calcDisplayRect(containerSize);
    if (display.width <= 0 || display.height <= 0) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    return Rect.fromLTRB(
      ((containerRect.left - display.left) / display.width).clamp(0.0, 1.0),
      ((containerRect.top - display.top) / display.height).clamp(0.0, 1.0),
      ((containerRect.right - display.left) / display.width).clamp(0.0, 1.0),
      ((containerRect.bottom - display.top) / display.height).clamp(0.0, 1.0),
    );
  }

  /// 图片坐标（0.0~1.0）→ 容器坐标
  Rect _imageToContainer(Rect imageRect, Size containerSize) {
    final display = _calcDisplayRect(containerSize);
    return Rect.fromLTRB(
      display.left + imageRect.left * display.width,
      display.top + imageRect.top * display.height,
      display.left + imageRect.right * display.width,
      display.top + imageRect.bottom * display.height,
    );
  }

  // ─── 拖拽处理 ─────────────────────────────────────────

  /// 判断点击位置对应的拖拽模式（基于图片坐标）
  _DragMode _hitTest(Offset localPos, Size containerSize) {
    final containerCropRect = _imageToContainer(_cropRect, containerSize);
    final left = containerCropRect.left;
    final top = containerCropRect.top;
    final right = containerCropRect.right;
    final bottom = containerCropRect.bottom;
    final half = _handleHitArea / 2;

    // 四角检测
    if ((localPos.dx - left).abs() < half && (localPos.dy - top).abs() < half) return _DragMode.topLeft;
    if ((localPos.dx - right).abs() < half && (localPos.dy - top).abs() < half) return _DragMode.topRight;
    if ((localPos.dx - left).abs() < half && (localPos.dy - bottom).abs() < half) return _DragMode.bottomLeft;
    if ((localPos.dx - right).abs() < half && (localPos.dy - bottom).abs() < half) return _DragMode.bottomRight;

    // 四边中点检测
    final midX = (left + right) / 2;
    final midY = (top + bottom) / 2;
    if ((localPos.dx - midX).abs() < half && (localPos.dy - top).abs() < half) return _DragMode.top;
    if ((localPos.dx - midX).abs() < half && (localPos.dy - bottom).abs() < half) return _DragMode.bottom;
    if ((localPos.dy - midY).abs() < half && (localPos.dx - left).abs() < half) return _DragMode.left;
    if ((localPos.dy - midY).abs() < half && (localPos.dx - right).abs() < half) return _DragMode.right;

    // 框内 → 移动
    if (containerCropRect.contains(localPos)) {
      return _DragMode.move;
    }

    return _DragMode.none;
  }

  void _onPanStart(DragStartDetails details, Size containerSize) {
    _dragMode = _hitTest(details.localPosition, containerSize);
    _dragStartRect = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails details, Size containerSize) {
    if (_dragMode == _DragMode.none) return;

    final display = _calcDisplayRect(containerSize);
    if (display.width <= 0 || display.height <= 0) return;

    // 把像素位移转换为图片坐标位移
    final dx = details.delta.dx / display.width;
    final dy = details.delta.dy / display.height;

    setState(() {
      double l = _cropRect.left;
      double t = _cropRect.top;
      double r = _cropRect.right;
      double b = _cropRect.bottom;

      switch (_dragMode) {
        case _DragMode.move:
          l += dx;
          t += dy;
          r += dx;
          b += dy;
          break;
        case _DragMode.topLeft:
          l += dx;
          t += dy;
          break;
        case _DragMode.topRight:
          r += dx;
          t += dy;
          break;
        case _DragMode.bottomLeft:
          l += dx;
          b += dy;
          break;
        case _DragMode.bottomRight:
          r += dx;
          b += dy;
          break;
        case _DragMode.top:
          t += dy;
          break;
        case _DragMode.bottom:
          b += dy;
          break;
        case _DragMode.left:
          l += dx;
          break;
        case _DragMode.right:
          r += dx;
          break;
        default:
          break;
      }

      // 约束：不超出边界（图片坐标 0~1）
      l = l.clamp(0.0, 1.0);
      t = t.clamp(0.0, 1.0);
      r = r.clamp(0.0, 1.0);
      b = b.clamp(0.0, 1.0);

      // 约束：最小尺寸
      final minW = _minWidthRatio;
      final minH = _minHeightRatio;
      if (r - l < minW) {
        if (_dragMode == _DragMode.left || _dragMode == _DragMode.topLeft || _dragMode == _DragMode.bottomLeft) {
          l = r - minW;
        } else {
          r = l + minW;
        }
      }
      if (b - t < minH) {
        if (_dragMode == _DragMode.top || _dragMode == _DragMode.topLeft || _dragMode == _DragMode.topRight) {
          t = b - minH;
        } else {
          b = t + minH;
        }
      }

      // 再次约束不超出
      if (l < 0) { r -= l; l = 0; }
      if (t < 0) { b -= t; t = 0; }
      if (r > 1) { l -= (r - 1); r = 1; }
      if (b > 1) { t -= (b - 1); b = 1; }

      _cropRect = Rect.fromLTRB(
        l.clamp(0.0, 1.0),
        t.clamp(0.0, 1.0),
        r.clamp(0.0, 1.0),
        b.clamp(0.0, 1.0),
      );
    });

    _notifyCropChanged();
  }

  void _onPanEnd(DragEndDetails details) {
    _dragMode = _DragMode.none;
  }

  // ─── 鼠标指针样式 ─────────────────────────────────────

  MouseCursor _cursorForDragMode(_DragMode mode) {
    switch (mode) {
      case _DragMode.move:
        return SystemMouseCursors.move;
      case _DragMode.topLeft:
      case _DragMode.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _DragMode.topRight:
      case _DragMode.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case _DragMode.top:
      case _DragMode.bottom:
        return SystemMouseCursors.resizeUpDown;
      case _DragMode.left:
      case _DragMode.right:
        return SystemMouseCursors.resizeLeftRight;
      default:
        return SystemMouseCursors.basic;
    }
  }

  // ─── 构建 ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final displayRect = _calcDisplayRect(containerSize);
        // 把图片坐标转换为容器坐标用于绘制
        final containerCropRect = _imageToContainer(_cropRect, containerSize);

        return Stack(
          children: [
            // 底层图片
            Positioned.fill(child: widget.child),

            // 手势检测 + 裁剪框绘制
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _onPanStart(d, containerSize),
                onPanUpdate: (d) => _onPanUpdate(d, containerSize),
                onPanEnd: _onPanEnd,
                child: MouseRegion(
                  cursor: _cursorForDragMode(_dragMode),
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      cropRect: containerCropRect,  // 用容器坐标绘制
                      displayRect: displayRect,
                      showGrid: widget.showGrid,
                      cornerLength: _cornerLength,
                      handleSize: _handleSize,
                      accentColor: widget.accentColor ?? AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 拖拽模式
enum _DragMode {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

/// 裁剪框绘制器
class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.cropRect,
    required this.displayRect,
    required this.showGrid,
    required this.cornerLength,
    required this.handleSize,
    this.accentColor = AppColors.brandPrimary,
  });

  /// 容器坐标中的裁剪框
  final Rect cropRect;

  /// 图片在容器中的实际显示区域
  final Rect displayRect;

  final bool showGrid;
  final double cornerLength;
  final double handleSize;

  /// 四角 L 形与手柄边框色（玻璃下应为暖琥珀，默认品牌蓝）
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 半透明遮罩（容器外区域 + 裁剪框外）
    final maskPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(maskPath, maskPaint);

    // 2. 裁剪框边框
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    // 3. 井字网格线
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;

      final w = cropRect.width;
      final h = cropRect.height;
      // 垂直线
      for (int i = 1; i <= 2; i++) {
        final x = cropRect.left + w * i / 3;
        canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      }
      // 水平线
      for (int i = 1; i <= 2; i++) {
        final y = cropRect.top + h * i / 3;
        canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
      }
    }

    // 4. 四角 L 形标记（强调色）
    final cornerPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cl = cornerLength;
    // 左上
    _drawCorner(canvas, cropRect.left, cropRect.top, cl, 1, 1, cornerPaint);
    // 右上
    _drawCorner(canvas, cropRect.right, cropRect.top, cl, -1, 1, cornerPaint);
    // 左下
    _drawCorner(canvas, cropRect.left, cropRect.bottom, cl, 1, -1, cornerPaint);
    // 右下
    _drawCorner(canvas, cropRect.right, cropRect.bottom, cl, -1, -1, cornerPaint);

    // 5. 四角拖拽手柄（白色圆点）
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final half = handleSize / 2;
    for (final point in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      final center = Offset(point.dx, point.dy);
      canvas.drawCircle(center, half, handlePaint);
      canvas.drawCircle(center, half, handleBorder);
    }

    // 6. 四边中点手柄（小白色矩形）
    final midHandlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final midHandleBorder = Paint()
      ..color = accentColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final midPoints = [
      Offset((cropRect.left + cropRect.right) / 2, cropRect.top),    // 上
      Offset((cropRect.left + cropRect.right) / 2, cropRect.bottom), // 下
      Offset(cropRect.left, (cropRect.top + cropRect.bottom) / 2),   // 左
      Offset(cropRect.right, (cropRect.top + cropRect.bottom) / 2),  // 右
    ];
    for (final mp in midPoints) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mp, width: 10, height: 10),
        const Radius.circular(2),
      );
      canvas.drawRRect(r, midHandlePaint);
      canvas.drawRRect(r, midHandleBorder);
    }
  }

  void _drawCorner(Canvas canvas, double x, double y, double len, int dx, int dy, Paint paint) {
    canvas.drawLine(
      Offset(x, y),
      Offset(x + len * dx, y),
      paint,
    );
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + len * dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.displayRect != displayRect ||
        oldDelegate.showGrid != showGrid;
  }
}
