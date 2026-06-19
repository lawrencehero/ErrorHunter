/// 错题猎手 - 搜索无结果空状态
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import 'empty_state.dart';

/// 搜索无结果空状态
class EHSearchEmpty extends StatelessWidget {
  const EHSearchEmpty({
    super.key,
    this.keyword,
    this.onClearSearch,
  });

  final String? keyword;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    return EHEmptyState(
      icon: Icons.search_off_rounded,
      title: keyword != null ? '未找到"$keyword"相关错题' : '未找到相关结果',
      description: '试试换个关键词，或清除筛选条件',
      actionText: onClearSearch != null ? '清除搜索' : null,
      onAction: onClearSearch,
      iconColor: AppColors.textTertiary.withOpacity(0.3),
    );
  }
}
