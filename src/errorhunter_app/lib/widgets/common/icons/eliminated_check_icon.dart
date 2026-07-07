/// 错题猎手 - "已消灭"勾选徽标
///
/// 替代原先的 ✅ emoji：用 CustomPaint 绘制带渐变与高光的绿色徽标 + 白色圆角勾，
/// 在浅色/玻璃（深色）背景下均有立体质感。
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

class EliminatedCheckIcon extends StatelessWidget {
  const EliminatedCheckIcon({
    super.key,
    this.size = 16.0,
    this.isGlass = false,
  });

  /// 图标边长（正方形）。
  final double size;

  /// 是否处于玻璃/深色背景：true 时提亮绿色，保证暗背景上的对比与质感。
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EliminatedCheckPainter(isGlass: isGlass),
      ),
    );
  }
}

class _EliminatedCheckPainter extends CustomPainter {
  _EliminatedCheckPainter({required this.isGlass});

  final bool isGlass;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final r = w / 2;
    // 主圆略小于画布，给投影/描边留边。
    final circleR = r * 0.9;

    // 配色：浅色背景用饱和消灭绿；玻璃/深色背景提亮一档。
    final Color light = isGlass ? const Color(0xFFB6F0C4) : const Color(0xFF6CE98A);
    final Color main = isGlass ? const Color(0xFF7BE096) : AppColors.success;
    final Color dark = isGlass ? const Color(0xFF3FA85C) : AppColors.successDark;

    final circleRect =
        Rect.fromCircle(center: center, radius: circleR);

    // 1) 软投影（向下偏移），营造抬起感。
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isGlass ? 0.28 : 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10);
    canvas.drawCircle(
      center + Offset(0, w * 0.05),
      circleR,
      shadowPaint,
    );

    // 2) 主圆：左上→右下线性渐变，球体感。
    final bodyGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [light, main, dark],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      center,
      circleR,
      Paint()..shader = bodyGradient.createShader(circleRect),
    );

    // 3) 顶部高光：白色径向渐变椭圆，裁剪在主圆内，形成光泽。
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(circleRect, Radius.circular(circleR)),
    );
    final glossRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - circleR * 0.34),
      width: circleR * 1.25,
      height: circleR * 0.85,
    );
    final glossGradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 0.9,
      colors: [
        Colors.white.withOpacity(0.55),
        Colors.white.withOpacity(0.12),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    canvas.drawOval(
      glossRect,
      Paint()..shader = glossGradient.createShader(glossRect),
    );
    canvas.restore();

    // 4) 内描边：极浅深绿，强化边缘清晰度。
    canvas.drawCircle(
      center,
      circleR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = dark.withOpacity(0.35),
    );

    // 5) 白色圆角勾。
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.14;
    final path = Path()
      ..moveTo(center.dx - circleR * 0.38, center.dy + circleR * 0.02)
      ..lineTo(center.dx - circleR * 0.08, center.dy + circleR * 0.32)
      ..lineTo(center.dx + circleR * 0.42, center.dy - circleR * 0.28);
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _EliminatedCheckPainter oldDelegate) =>
      oldDelegate.isGlass != isGlass;
}
