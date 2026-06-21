/// 错题猎手 - 错因单选卡片组组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../models/question_model.dart';

/// 错因选择数据
class ErrorCategoryOption {
  const ErrorCategoryOption({
    required this.category,
    required this.emoji,
    required this.shortLabel,
    required this.fullLabel,
    this.isRecommended = false,
  });

  final ErrorCategory category;
  final String emoji;
  final String shortLabel;
  final String fullLabel;
  final bool isRecommended;
}

/// 错因单选卡片组
class ErrorCategorySelector extends StatelessWidget {
  const ErrorCategorySelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.recommendedCategory,
    this.showUnknown = false,
    this.subCategories = const [],
    this.selectedSubCategories = const [],
    this.onSubCategoryChanged,
  });

  /// 当前选中的错因
  final ErrorCategory? selected;

  /// 选中回调
  final ValueChanged<ErrorCategory> onSelected;

  /// AI 推荐的错因
  final ErrorCategory? recommendedCategory;

  /// 是否显示"不确定"选项（仅小学生）
  final bool showUnknown;

  /// 可选的细分分类
  final List<String> subCategories;

  /// 已选的细分分类
  final List<String> selectedSubCategories;

  /// 细分分类变更回调
  final ValueChanged<List<String>>? onSubCategoryChanged;

  static const _options = [
    ErrorCategoryOption(
      category: ErrorCategory.knowledge,
      emoji: '🧠',
      shortLabel: '不会做',
      fullLabel: '没学会',
    ),
    ErrorCategoryOption(
      category: ErrorCategory.skill,
      emoji: '✏️',
      shortLabel: '算错了',
      fullLabel: '手误了',
    ),
    ErrorCategoryOption(
      category: ErrorCategory.psychology,
      emoji: '😰',
      shortLabel: '粗心了',
      fullLabel: '太紧张了',
    ),
    ErrorCategoryOption(
      category: ErrorCategory.habit,
      emoji: '📖',
      shortLabel: '看错了',
      fullLabel: '没仔细看',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final options = [
      ..._options,
      if (showUnknown)
        const ErrorCategoryOption(
          category: ErrorCategory.unknown,
          emoji: '🤷',
          shortLabel: '不确定',
          fullLabel: '不确定',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '这道题为什么错了？',
          style: AppTypography.primary.h3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        ...options.map((option) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CategoryCard(
                option: option,
                isSelected: selected == option.category,
                isRecommended: recommendedCategory == option.category,
                onTap: () => onSelected(option.category),
              ),
            )),

        // 细分 Chips
        if (selected != null && subCategories.isNotEmpty) ...[
          SizedBox(height: AppSpacing.md),
          Text(
            '细分原因（最多选2个）',
            style: AppTypography.primary.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: subCategories.map((sub) {
              final isSelected = selectedSubCategories.contains(sub);
              return GestureDetector(
                onTap: () {
                  if (onSubCategoryChanged == null) return;
                  if (isSelected) {
                    onSubCategoryChanged!(
                      selectedSubCategories.where((s) => s != sub).toList(),
                    );
                  } else if (selectedSubCategories.length < 2) {
                    onSubCategoryChanged!([...selectedSubCategories, sub]);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brandPrimary.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: isSelected ? AppColors.brandPrimary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    sub,
                    style: AppTypography.primary.caption.copyWith(
                      color: isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// 单个错因卡片
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.option,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  final ErrorCategoryOption option;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppColors.errorCategoryColor(option.category.code);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withOpacity(0.05)
              : AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Text(
              option.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            SizedBox(width: AppSpacing.md),
            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.shortLabel,
                        style: AppTypography.primary.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isRecommended) ...[
                        SizedBox(width: AppSpacing.xs),
                        const Text('✨', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  Text(
                    option.fullLabel,
                    style: AppTypography.primary.caption.copyWith(
                      color: categoryColor,
                    ),
                  ),
                ],
              ),
            ),
            // Check mark
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
