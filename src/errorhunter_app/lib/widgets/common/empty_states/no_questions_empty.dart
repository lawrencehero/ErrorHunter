/// 错题猎手 - 无错题空状态
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import 'empty_state.dart';

/// 无错题空状态
class EHNoQuestionsEmpty extends StatelessWidget {
  const EHNoQuestionsEmpty({
    super.key,
    this.onAddQuestion,
  });

  final VoidCallback? onAddQuestion;

  @override
  Widget build(BuildContext context) {
    return EHEmptyState(
      icon: Icons.assignment_outlined,
      title: '还没有错题记录',
      description: '拍照或手动录入你的第一道错题吧！',
      actionText: onAddQuestion != null ? '录入错题' : null,
      onAction: onAddQuestion,
      iconColor: AppColors.brandPrimary.withOpacity(0.3),
    );
  }
}
