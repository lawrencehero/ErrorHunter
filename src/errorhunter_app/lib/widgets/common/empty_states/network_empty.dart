/// 错题猎手 - 网络错误空状态
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import 'empty_state.dart';

/// 网络错误空状态
class EHNetworkEmpty extends StatelessWidget {
  const EHNetworkEmpty({
    super.key,
    this.onRetry,
  });

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EHEmptyState(
      icon: Icons.wifi_off_rounded,
      title: '网络连接失败',
      description: '请检查网络设置后重试',
      actionText: onRetry != null ? '重新加载' : null,
      onAction: onRetry,
      iconColor: AppColors.danger.withOpacity(0.3),
    );
  }
}
