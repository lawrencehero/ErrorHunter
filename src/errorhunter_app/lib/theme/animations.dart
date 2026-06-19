/// 错题猎手 - 动效系统
/// 来源：DESIGN.md V2.0 §8
/// Duration、Easing Curves、关键动画参数
library;

import 'package:flutter/animation.dart';

/// Design Token: 动效参数
class AppAnimations {
  AppAnimations._();

  // ─── Duration Scale ───────────────────────────────────────

  /// 120ms — 按钮按压、Chip 切换
  static const Duration micro = Duration(milliseconds: 120);

  /// 200ms — 卡片 hover、状态切换
  static const Duration short = Duration(milliseconds: 200);

  /// 320ms — 页面过渡、进度条填充
  static const Duration medium = Duration(milliseconds: 320);

  /// 480ms — 消灭动画、弹窗出现
  static const Duration long = Duration(milliseconds: 480);

  /// 1600ms — 打卡火焰脉动、活跃节点呼吸
  static const Duration pulse = Duration(milliseconds: 1600);

  // ─── Easing Curves ────────────────────────────────────────

  /// 通用过渡: Cubic(0.4, 0.0, 0.2, 1.0)
  static const Curve standard = Cubic(0.4, 0.0, 0.2, 1.0);

  /// 元素进入: Cubic(0.0, 0.0, 0.2, 1.0)
  static const Curve decelerate = Cubic(0.0, 0.0, 0.2, 1.0);

  /// 元素退出: Cubic(0.4, 0.0, 1.0, 1.0)
  static const Curve accelerate = Cubic(0.4, 0.0, 1.0, 1.0);

  /// 弹跳/成就解锁: Cubic(0.34, 1.56, 0.64, 1.0) — overshoot
  static const Curve overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

  /// 弹性: 比 overshoot 更柔和的弹跳
  static const Curve bounce = Cubic(0.68, -0.55, 0.265, 1.55);

  // ─── Specific Animation Presets ───────────────────────────

  /// 按钮按压: translateY(3px), 120ms, standard
  static const double buttonPressOffset = 3.0;

  /// 卡片浮起: translateY(-2px), 200ms, decelerate
  static const double cardLiftOffset = -2.0;

  /// 进度条填充: 480ms, overshoot
  static const Duration progressFill = Duration(milliseconds: 480);

  /// 消灭动画: scale 1→1.2→0 + confetti, 480ms
  static const Duration eliminateAnimation = Duration(milliseconds: 480);

  /// 页面滑动: slide + fade, 320ms
  static const Duration pageTransition = Duration(milliseconds: 320);

  /// 脉动循环: opacity 0.8→1.0, 1600ms
  static const Duration pulseCycle = Duration(milliseconds: 1600);

  /// 打卡火焰: scale 1.0→1.1→1.0, 1600ms
  static const Duration streakFireCycle = Duration(milliseconds: 1600);
}
