/// 错题猎手 - 薄弱知识点列表 V3.0 (游戏化)
/// 圆形排名 + 渐变进度条 + chunky卡片
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

class WeakKnowledgeItem {
  final String name;
  final int errorCount;
  final Color color;
  const WeakKnowledgeItem({required this.name, required this.errorCount, required this.color});
}

class WeakKnowledgeList extends StatelessWidget {
  const WeakKnowledgeList({super.key, required this.items});
  final List<WeakKnowledgeItem> items;

  @override
  Widget build(BuildContext context) {
    final isGlass = context.themeExt.isDarkBackground;
    final tc = context.textColors;
    // 玻璃下 warning 提亮为暖琥珀
    final warningColor = isGlass ? const Color(0xFFFFB74D) : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // 玻璃下：半透明白底 + 白描边，去掉 chunky 底影
        color: isGlass ? Colors.white.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.25), width: 1) : null,
        boxShadow: isGlass
            ? null
            : [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                BoxShadow(color: AppColors.border, offset: const Offset(0, 3), blurRadius: 0),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  // 玻璃下用半透明白，避免浅橙底叠渐变背景
                  color: isGlass ? Colors.white.withOpacity(0.15) : const Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, size: 16, color: warningColor),
              ),
              const SizedBox(width: 8),
              Text('薄弱知识点',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tc.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((e) => _buildItem(isGlass, tc, e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildItem(bool isGlass, AppTextThemeColors tc, int index, WeakKnowledgeItem item) {
    final maxError = items.fold<int>(0, (m, i) => i.errorCount > m ? i.errorCount : m);
    final ratio = maxError > 0 ? item.errorCount / maxError : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: index < items.length - 1 ? 12 : 0),
      child: Row(
        children: [
          // 排名圆形
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          // 名称 + 进度条
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.primary),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    // 玻璃下轨道用半透明白，避免浅色叠渐变
                    backgroundColor: isGlass
                        ? Colors.white.withOpacity(0.15)
                        : item.color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(item.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 错题数
          Text('${item.errorCount}题',
            style: TextStyle(color: item.color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
