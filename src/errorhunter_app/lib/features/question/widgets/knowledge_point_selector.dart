/// 错题猎手 - 知识点选择器组件
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../models/knowledge_point_model.dart';

/// 知识点选择器
class KnowledgePointSelector extends StatefulWidget {
  const KnowledgePointSelector({
    super.key,
    required this.selectedPoints,
    required this.onChanged,
    this.recommendedPoints = const [],
    this.availablePoints = const [],
  });

  /// 已选知识点
  final List<KnowledgePoint> selectedPoints;

  /// 变更回调
  final ValueChanged<List<KnowledgePoint>> onChanged;

  /// AI 推荐知识点
  final List<KnowledgePoint> recommendedPoints;

  /// 可选知识点列表
  final List<KnowledgePoint> availablePoints;

  @override
  State<KnowledgePointSelector> createState() => _KnowledgePointSelectorState();
}

class _KnowledgePointSelectorState extends State<KnowledgePointSelector> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool _isSelected(KnowledgePoint kp) {
    return widget.selectedPoints.any((s) => s.id == kp.id);
  }

  void _toggle(KnowledgePoint kp) {
    final list = List<KnowledgePoint>.from(widget.selectedPoints);
    if (_isSelected(kp)) {
      list.removeWhere((s) => s.id == kp.id);
    } else {
      list.add(kp);
    }
    widget.onChanged(list);
  }

  void _addCustom(String name) {
    if (name.trim().isEmpty) return;
    final kp = KnowledgePoint(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      subject: '自定义',
    );
    widget.onChanged([...widget.selectedPoints, kp]);
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Merge all points
    final allPoints = <KnowledgePoint>[
      ...widget.recommendedPoints,
      ...widget.availablePoints.where(
        (p) => !widget.recommendedPoints.any((r) => r.id == p.id),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '知识点',
              style: AppTypography.primary.h3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              '(至少选1个)',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),

        // Selected + Available chips
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            // AI Recommended
            ...widget.recommendedPoints.map((kp) => _buildChip(kp)),
            // Others
            ...widget.availablePoints
                .where((p) => !widget.recommendedPoints.any((r) => r.id == p.id))
                .map((kp) => _buildChip(kp)),
          ],
        ),

        SizedBox(height: AppSpacing.md),

        // Custom add
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _customController,
                  style: AppTypography.primary.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '添加自定义知识点...',
                    hintStyle: AppTypography.primary.body.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _addCustom,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () => _addCustom(_customController.text),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),

        // Validation hint
        if (widget.selectedPoints.isEmpty) ...[
          SizedBox(height: AppSpacing.xs),
          Text(
            '请至少选择1个知识点',
            style: AppTypography.primary.caption.copyWith(
              color: AppColors.danger,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChip(KnowledgePoint kp) {
    final isSelected = _isSelected(kp);
    final isRecommended = kp.isRecommended;

    return GestureDetector(
      onTap: () => _toggle(kp),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecommended) ...[
              const Text('✨', style: TextStyle(fontSize: 12)),
              SizedBox(width: AppSpacing.xs),
            ],
            Text(
              kp.name,
              style: AppTypography.primary.caption.copyWith(
                color: isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.brandPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
