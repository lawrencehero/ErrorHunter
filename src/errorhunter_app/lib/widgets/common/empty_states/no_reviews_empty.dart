/// 错题猎手 - 无复习空状态
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import 'empty_state.dart';

/// 无复习任务空状态
class EHNoReviewsEmpty extends StatelessWidget {
  const EHNoReviewsEmpty({
    super.key,
    this.onStartReview,
  });

  final VoidCallback? onStartReview;

  @override
  Widget build(BuildContext context) {
    return EHEmptyState(
      icon: Icons.school_outlined,
      title: '暂无待复习内容',
      description: '太棒了！所有错题都已掌握，继续保持！',
      actionText: onStartReview != null ? '开始复习' : null,
      onAction: onStartReview,
      iconColor: AppColors.success.withOpacity(0.3),
    );
  }
}
