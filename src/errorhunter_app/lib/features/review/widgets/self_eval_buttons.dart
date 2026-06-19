/// 错题猎手 - 自评按钮组组件 V2.0
/// 渐变背景 + chunky 底影 + 按压动画
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/animations.dart';
import '../models/review_report_model.dart';

/// 自评按钮组 V2.0
class SelfEvalButtons extends StatelessWidget {
  const SelfEvalButtons({
    super.key,
    required this.onEvaluate,
    this.selectedRating,
    this.isReviveMode = false,
    this.enabled = true,
  });

  final ValueChanged<SelfEvalRating> onEvaluate;
  final SelfEvalRating? selectedRating;
  final bool isReviveMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (isReviveMode) {
      return _buildReviveButtons();
    }
    return _buildStandardButtons();
  }

  /// 标准三按钮
  Widget _buildStandardButtons() {
    return Row(
      children: [
        Expanded(
          child: _EvalButton(
            emoji: '😄',
            label: '完全掌握',
            color: AppColors.success,
            gradient: AppGradients.success,
            chunkyColor: AppColors.successDark,
            isSelected: selectedRating == SelfEvalRating.mastered,
            enabled: enabled,
            onTap: () => onEvaluate(SelfEvalRating.mastered),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _EvalButton(
            emoji: '🤔',
            label: '部分记得',
            color: AppColors.warning,
            gradient: LinearGradient(
              colors: [AppColors.warning, const Color(0xFFFFCC80)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            chunkyColor: AppColors.warningDark,
            isSelected: selectedRating == SelfEvalRating.partial,
            enabled: enabled,
            onTap: () => onEvaluate(SelfEvalRating.partial),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _EvalButton(
            emoji: '😵',
            label: '完全不会',
            color: AppColors.danger,
            gradient: LinearGradient(
              colors: [AppColors.danger, const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            chunkyColor: AppColors.dangerDark,
            isSelected: selectedRating == SelfEvalRating.forgot,
            enabled: enabled,
            onTap: () => onEvaluate(SelfEvalRating.forgot),
          ),
        ),
      ],
    );
  }

  /// 复活检测双按钮
  Widget _buildReviveButtons() {
    return Row(
      children: [
        Expanded(
          child: _EvalButton(
            emoji: '😊',
            label: '还记得',
            color: AppColors.success,
            gradient: AppGradients.success,
            chunkyColor: AppColors.successDark,
            isSelected: selectedRating == SelfEvalRating.remembered,
            enabled: enabled,
            onTap: () => onEvaluate(SelfEvalRating.remembered),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _EvalButton(
            emoji: '😅',
            label: '忘记了',
            color: AppColors.danger,
            gradient: LinearGradient(
              colors: [AppColors.danger, const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            chunkyColor: AppColors.dangerDark,
            isSelected: selectedRating == SelfEvalRating.forgotten,
            enabled: enabled,
            onTap: () => onEvaluate(SelfEvalRating.forgotten),
          ),
        ),
      ],
    );
  }
}

/// 单个自评按钮 V2.0
class _EvalButton extends StatefulWidget {
  const _EvalButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.gradient,
    required this.chunkyColor,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final LinearGradient gradient;
  final Color chunkyColor;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_EvalButton> createState() => _EvalButtonState();
}

class _EvalButtonState extends State<_EvalButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isColored = widget.isSelected || (_isPressed && widget.enabled);

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: AppAnimations.micro,
        curve: AppAnimations.standard,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        transform: _isPressed
            ? (Matrix4.identity()..translate(0.0, AppAnimations.buttonPressOffset))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: isColored ? widget.gradient : null,
          color: isColored ? null : AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          border: isColored
              ? null
              : Border.all(color: AppColors.border, width: 1.5),
          boxShadow: isColored && !_isPressed
              ? [
                  BoxShadow(
                    color: widget.chunkyColor,
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              widget.label,
              style: AppTypography.primary.caption.copyWith(
                color: isColored ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
