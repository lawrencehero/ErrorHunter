/// 错题猎手 - 骨架屏列表
library;

import 'package:flutter/material.dart';
import '../../../theme/spacing.dart';
import 'skeleton_card.dart';

/// 骨架屏列表
class EHSkeletonList extends StatelessWidget {
  const EHSkeletonList({
    super.key,
    this.itemCount = 5,
    this.useShimmer = true,
  });

  final int itemCount;
  final bool useShimmer;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.pagePadding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => EHSkeletonCard(useShimmer: useShimmer),
    );
  }
}
