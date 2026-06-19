/// 错题猎手 - 全局应用背景
/// 根据当前主题自动渲染：游戏化=纯色 / 玻璃拟态=渐变+光球
/// 所有页面的 Scaffold 应设 backgroundColor: Colors.transparent 并使用此组件包裹
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme_mode.dart';
import '../../theme/theme_manager.dart';

/// 全局应用背景装饰（放在最底层）
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;

    return Stack(
      children: [
        // 背景层
        if (isGlass) ...[
          // 渐变背景
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppThemeExtension.glassmorphism.backgroundGradient,
              ),
            ),
          ),
          // 光球装饰
          Positioned(
            top: -80,
            right: -60,
            child: _buildOrb(250, const Color(0xFF4F6EF7)),
          ),
          Positioned(
            bottom: 60,
            left: -60,
            child: _buildOrb(200, const Color(0xFFFF8C42)),
          ),
          Positioned(
            top: 350,
            right: -30,
            child: _buildOrb(150, const Color(0xFF34C759)),
          ),
        ] else
          Positioned.fill(
            child: Container(color: const Color(0xFFF8F9FC)),
          ),

        // 内容层
        child,
      ],
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
