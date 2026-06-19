/// 错题猎手 - 角标/徽章组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/typography.dart';

/// 徽章尺寸
enum EHBadgeSize { sm, md }

/// 角标/徽章
class EHBadge extends StatelessWidget {
  const EHBadge({
    super.key,
    this.child,
    this.count,
    this.dot = false,
    this.color,
    this.textColor = Colors.white,
    this.size = EHBadgeSize.md,
    this.offset,
    this.show = true,
  });

  /// 子组件（被标记的Widget）
  final Widget? child;

  /// 数字（null时只显示圆点）
  final int? count;

  /// 是否仅显示圆点模式
  final bool dot;

  /// 背景色
  final Color? color;

  /// 文字颜色
  final Color textColor;

  /// 尺寸
  final EHBadgeSize size;

  /// 偏移量
  final Offset? offset;

  /// 是否显示
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return _buildBadge();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        if (show)
          Positioned(
            right: (offset?.dx ?? 0) - 4,
            top: (offset?.dy ?? 0) - 4,
            child: _buildBadge(),
          ),
      ],
    );
  }

  Widget _buildBadge() {
    if (!show) return const SizedBox.shrink();

    if (dot || count == null) {
      return Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: color ?? AppColors.danger,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }

    final displayText = count! > 99 ? '99+' : '$count';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: 1,
      ),
      constraints: BoxConstraints(minWidth: _minWidth, minHeight: _height),
      decoration: BoxDecoration(
        color: color ?? AppColors.danger,
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.2,
        ),
      ),
    );
  }

  double get _dotSize => size == EHBadgeSize.sm ? 8.0 : 10.0;
  double get _height => size == EHBadgeSize.sm ? 16.0 : 20.0;
  double get _minWidth => size == EHBadgeSize.sm ? 16.0 : 20.0;
  double get _horizontalPadding => size == EHBadgeSize.sm ? 4.0 : 6.0;
  double get _fontSize => size == EHBadgeSize.sm ? 9.0 : 11.0;
}
