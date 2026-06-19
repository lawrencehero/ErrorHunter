/// 错题猎手 - 骨架屏基础块
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import 'shimmer_effect.dart';

/// 骨架屏基础块
class EHSkeletonBox extends StatelessWidget {
  const EHSkeletonBox({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius = AppRadius.radiusSm,
    this.useShimmer = true,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final bool useShimmer;

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.3),
        borderRadius: borderRadius,
      ),
    );

    if (useShimmer) {
      box = EHShimmerEffect(child: box);
    }

    return box;
  }
}
