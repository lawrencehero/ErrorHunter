/// 错题猎手 - 底部导航栏 V5.0
/// 5项布局：[首页] [错题本] [FAB录入] [周报] [我的]
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/app_theme_mode.dart';

class EHBottomNavItem {
  const EHBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class EHBottomNavBar extends StatelessWidget {
  const EHBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onFabPressed,
    this.fabIcon = Icons.add_rounded,
  }) : assert(items.length == 4, 'EHBottomNavBar 需要4个导航项（FAB自动插入中间）');

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<EHBottomNavItem> items;
  final VoidCallback? onFabPressed;
  final IconData fabIcon;

  @override
  Widget build(BuildContext context) {
    final ext = context.themeExt;
    final isGlass = ext.headerStyle == HeaderStyle.transparent;
    final inactiveColor = isGlass ? Colors.white.withOpacity(0.5) : AppColors.textTertiary;
    final activeColor = isGlass ? Colors.white : AppColors.brandPrimary;
    // 玻璃下选中态强调色提亮为暖琥珀（避免蓝色叠渐变背景）
    final activeAccent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.08) : Colors.white,
        border: isGlass
            ? Border(top: BorderSide(color: Colors.white.withOpacity(0.15), width: 1))
            : null,
        boxShadow: isGlass
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 5个位置：[0] [1] [FAB占位] [2] [3]
              Row(
                children: [
                  _buildTab(0, isGlass, inactiveColor, activeColor, activeAccent),
                  _buildTab(1, isGlass, inactiveColor, activeColor, activeAccent),
                  const SizedBox(width: 60), // FAB 占位
                  _buildTab(2, isGlass, inactiveColor, activeColor, activeAccent),
                  _buildTab(3, isGlass, inactiveColor, activeColor, activeAccent),
                ],
              ),
              // 居中浮动按钮
              Positioned.fill(
                child: Center(
                  child: GestureDetector(
                    onTap: onFabPressed,
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.brandGlow,
                        border: Border.all(
                          color: isGlass ? Colors.white.withOpacity(0.2) : Colors.white,
                          width: 3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(fabIcon, size: 28, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, bool isGlass, Color inactiveColor, Color activeColor, Color activeAccent) {
    final item = items[index];
    // 映射：item 0→tab 0, item 1→tab 1, item 2→tab 3(周报), item 3→tab 4(我的)
    // currentIndex 映射：0=首页, 1=错题本, 2=周报, 3=我的
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? (isGlass ? activeAccent.withOpacity(0.28) : AppColors.brandPrimaryPale)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
