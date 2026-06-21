/// 错题猎手 - 头像组件
/// 支持网络图片 + 占位符
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/typography.dart';

/// 头像尺寸
enum EHAvatarSize { sm, md, lg, xl }

/// 头像组件
class EHAvatar extends StatelessWidget {
  const EHAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = EHAvatarSize.md,
    this.onTap,
  });

  /// 头像图片URL
  final String? imageUrl;

  /// 用户名（用于生成占位符首字母）
  final String? name;

  /// 头像尺寸
  final EHAvatarSize size;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _dimension,
        height: _dimension,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildPlaceholder();
                },
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.brandPrimary.withOpacity(0.1),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  double get _dimension {
    switch (size) {
      case EHAvatarSize.sm:
        return 32.0;
      case EHAvatarSize.md:
        return 44.0;
      case EHAvatarSize.lg:
        return 56.0;
      case EHAvatarSize.xl:
        return 80.0;
    }
  }

  double get _fontSize {
    switch (size) {
      case EHAvatarSize.sm:
        return 12.0;
      case EHAvatarSize.md:
        return 16.0;
      case EHAvatarSize.lg:
        return 20.0;
      case EHAvatarSize.xl:
        return 28.0;
    }
  }
}
