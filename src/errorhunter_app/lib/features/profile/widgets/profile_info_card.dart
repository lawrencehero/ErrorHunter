/// 错题猎手 - 个人信息卡片组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/avatar.dart';
import '../../../widgets/common/cards/base_card.dart';

/// 个人信息卡片
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    this.avatarUrl,
    required this.nickname,
    required this.grade,
    required this.eliminatedCount,
  });

  final String? avatarUrl;
  final String nickname;
  final String grade;
  final int eliminatedCount;

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    // 玻璃拟态：深色渐变背景上 brandPrimary 蓝对比度不足，
    // 改用暖琥珀强调色 + success 提亮（与 profile_page.dart 一致）。
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    final successColor =
        isGlass ? const Color(0xFF81C784) : AppColors.success;
    return EHBaseCard(
      child: Row(
        children: [
          EHAvatar(
            imageUrl: avatarUrl,
            name: nickname,
            size: EHAvatarSize.xl,
          ),
          SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: AppTypography.primary.h2.copyWith(
                    color: tc.primary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(isGlass ? 0.22 : 0.1),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    _gradeLabel(grade),
                    style: AppTypography.primary.caption.copyWith(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  '已消灭 $eliminatedCount 道 🎯',
                  style: AppTypography.primary.body.copyWith(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _gradeLabel(String grade) {
    switch (grade) {
      case '31': return '三年级上';
      case '32': return '三年级下';
      case '41': return '四年级上';
      case '42': return '四年级下';
      case '51': return '五年级上';
      case '52': return '五年级下';
      case '61': return '六年级上';
      case '62': return '六年级下';
      case '71': return '七年级上';
      case '72': return '七年级下';
      case '81': return '八年级上';
      case '82': return '八年级下';
      case '91': return '九年级上';
      default: return grade;
    }
  }
}
