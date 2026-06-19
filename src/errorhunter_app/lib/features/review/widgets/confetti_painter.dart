/// 错题猎手 - 撒花粒子 CustomPainter
/// 60-80粒子随机方向爆发 + 自然下落
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 单个粒子
class _Particle {
  _Particle(this.random)
      : x = 0.5,
        y = 0.4,
        vx = (random.nextDouble() - 0.5) * 0.03,
        vy = -(random.nextDouble() * 0.02 + 0.01),
        size = random.nextDouble() * 6 + 3,
        color = _colors[random.nextInt(_colors.length)],
        rotation = random.nextDouble() * math.pi * 2,
        rotationSpeed = (random.nextDouble() - 0.5) * 0.2,
        shape = random.nextInt(3); // 0=circle, 1=rect, 2=star

  final math.Random random;
  double x;
  double y;
  double vx;
  double vy;
  final double size;
  final Color color;
  double rotation;
  final double rotationSpeed;
  final int shape;

  static const List<Color> _colors = [
    Color(0xFF34C759), // Success green
    Color(0xFFFFB830), // Warning yellow
    Color(0xFF4F6EF7), // Brand blue
    Color(0xFFFF8C42), // Brand orange
    Color(0xFFE17055), // Coral
    Color(0xFF6C5CE7), // Purple
    Color(0xFFFF6B6B), // Red
    Color(0xFF48DBFB), // Light blue
  ];

  void update(double progress) {
    x += vx;
    y += vy;
    vy += 0.0008; // 重力
    vx *= 0.99; // 空气阻力
    rotation += rotationSpeed;
  }
}

/// 撒花粒子 Painter
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({
    required this.progress,
    int particleCount = 70,
  }) : _particles = [] {
    final random = math.Random(42); // 固定种子保证一致性
    for (int i = 0; i < particleCount; i++) {
      _particles.add(_Particle(random));
    }
  }

  final double progress; // 0.0 ~ 1.0
  final List<_Particle> _particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    for (final p in _particles) {
      // 更新位置（基于 progress 模拟时间）
      final simProgress = progress.clamp(0.0, 1.0);
      final px = (p.x + p.vx * simProgress * 60) * size.width;
      final py = (p.y + p.vy * simProgress * 60 +
              0.5 * 0.0008 * simProgress * simProgress * 3600) *
          size.height;

      // 透明度随进度衰减
      final opacity = (1.0 - simProgress * 0.8).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * simProgress * 60);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      switch (p.shape) {
        case 0: // 圆形
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        case 1: // 矩形
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            paint,
          );
        case 2: // 三角形
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
