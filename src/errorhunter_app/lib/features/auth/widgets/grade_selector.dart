/// 错题猎手 - 年级选择器组件
/// EHBottomSheet 弹窗，分组显示小学3-6年级 / 初中7-9年级
library;

import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/dialogs/bottom_sheet.dart';

/// 年级选项
class GradeOption {
  final String code; // "31"-"34", "71"-"73"
  final String label; // "三年级" ... "九年级"

  const GradeOption({required this.code, required this.label});
}

const _primaryGrades = [
  GradeOption(code: '31', label: '三年级'),
  GradeOption(code: '32', label: '四年级'),
  GradeOption(code: '33', label: '五年级'),
  GradeOption(code: '34', label: '六年级'),
];

const _middleGrades = [
  GradeOption(code: '71', label: '七年级'),
  GradeOption(code: '72', label: '八年级'),
  GradeOption(code: '73', label: '九年级'),
];

/// 年级选择器
class GradeSelector extends StatelessWidget {
  const GradeSelector({super.key});

  /// 显示年级选择 Bottom Sheet，返回选中的 grade code
  static Future<String?> show(BuildContext context) {
    return EHBottomSheet.show<String>(
      context,
      title: '选择年级',
      child: const GradeSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 小学组
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            '小学',
            style: AppTypography.primary.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _primaryGrades.map((g) => _GradeChip(option: g)).toList(),
        ),
        SizedBox(height: AppSpacing.lg),
        // 初中组
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            '初中',
            style: AppTypography.primary.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _middleGrades.map((g) => _GradeChip(option: g)).toList(),
        ),
        SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

class _GradeChip extends StatelessWidget {
  final GradeOption option;

  const _GradeChip({required this.option});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(option.code),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary.withOpacity(0.08),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: AppColors.brandPrimary.withOpacity(0.2),
          ),
        ),
        child: Text(
          option.label,
          style: AppTypography.primary.body.copyWith(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
