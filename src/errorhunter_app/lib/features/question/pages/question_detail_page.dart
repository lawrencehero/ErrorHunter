/// 错题猎手 - P6 错题详情页
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/chips/error_category_chip.dart';
import '../../../widgets/common/chips/filter_chip.dart';
import '../../../widgets/common/chips/status_chip.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import '../models/question_model.dart';
import '../widgets/image_preview.dart';
import '../widgets/review_history_timeline.dart';
import '../widgets/review_progress_bar.dart';
import '../widgets/solution_steps.dart';

/// 错题详情页
class QuestionDetailPage extends StatefulWidget {
  const QuestionDetailPage({super.key, required this.questionId});

  final String questionId;

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  bool _isEditMode = false;

  // Bug #28: 跟踪可折叠区块的展开状态（默认全部折叠）
  final Set<String> _expandedSections = {};

  // Edit controllers
  late TextEditingController _ocrController;
  late TextEditingController _myAnswerController;
  late TextEditingController _correctAnswerController;

  @override
  void initState() {
    super.initState();
    _ocrController = TextEditingController();
    _myAnswerController = TextEditingController();
    _correctAnswerController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuestionBloc>().add(LoadQuestionDetail(widget.questionId));
    });
  }

  @override
  void dispose() {
    _ocrController.dispose();
    _myAnswerController.dispose();
    _correctAnswerController.dispose();
    super.dispose();
  }

  void _toggleEdit(QuestionModel question) {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _ocrController.text = question.ocrText ?? '';
        _myAnswerController.text = question.myAnswer ?? '';
        _correctAnswerController.text = question.correctAnswer ?? '';
      } else {
        // Auto-save on exit edit mode
        final updated = question.copyWith(
          ocrText: _ocrController.text.isEmpty ? null : _ocrController.text,
          myAnswer: _myAnswerController.text.isEmpty ? null : _myAnswerController.text,
          correctAnswer: _correctAnswerController.text.isEmpty ? null : _correctAnswerController.text,
          updatedAt: DateTime.now(),
        );
        context.read<QuestionBloc>().add(UpdateQuestion(updated));
        EHToast.show(context, message: '已自动保存', type: EHToastType.success);
      }
    });
  }

  Future<void> _deleteQuestion(String id) async {
    final confirmed = await EHConfirmDialog.show(
      context,
      title: '删除这道错题？',
      content: '删除后将移入回收站，30天内可恢复。',
      confirmText: '删除',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (confirmed == true && mounted) {
      context.read<QuestionBloc>().add(DeleteQuestion(id));
      EHToast.show(context, message: '已移至回收站', type: EHToastType.success);
      Navigator.of(context).pop();
    }
  }

  void _showMoreMenu(QuestionModel question) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined, color: AppColors.brandPrimary),
              title: Text('导出 PDF'),
              onTap: () {
                Navigator.pop(ctx);
                EHToast.show(context, message: 'PDF 导出功能开发中...', type: EHToastType.info);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: AppColors.brandPrimary),
              title: Text('分享'),
              onTap: () {
                Navigator.pop(ctx);
                EHToast.show(context, message: '分享功能开发中...', type: EHToastType.info);
              },
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('删除', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteQuestion(question.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return BlocBuilder<QuestionBloc, QuestionState>(
      builder: (context, state) {
        if (state is QuestionDetailLoading) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
            body: const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary)),
          );
        }

        if (state is QuestionDetailLoaded) {
          return _buildDetail(state.question);
        }

        if (state is QuestionError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
            body: Center(
              child: Text(state.message, style: AppTypography.primary.body),
            ),
          );
        }

        // Trigger load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<QuestionBloc>().add(LoadQuestionDetail(widget.questionId));
        });
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
          body: const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary)),
        );
      },
    );
  }

  Widget _buildDetail(QuestionModel question) {
    final tc = context.textColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => _toggleEdit(question),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.brandPrimary),
                    SizedBox(width: 2),
                    Text(
                      _isEditMode ? '完成' : '编辑',
                      style: AppTypography.primary.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.base),
            child: GestureDetector(
              onTap: () => _showMoreMenu(question),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: Icon(Icons.more_horiz_rounded, color: tc.secondary),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: AppSpacing.pagePadding.copyWith(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Question Image ─────────────────────────────
                if (question.imageUrl.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => ImagePreview.show(context, question.imageUrl),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.radiusLg,
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: question.imageUrl.startsWith('/')
                          ? Image.file(File(question.imageUrl), fit: BoxFit.contain)
                          : _buildNetworkImage(question.imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ── OCR Text ───────────────────────────────────
                if (_isEditMode)
                  TextField(
                    controller: _ocrController,
                    maxLines: null,
                    style: AppTypography.primary.body.copyWith(color: tc.primary),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                      contentPadding: AppSpacing.cardInnerPadding,
                    ),
                  )
                else if (question.ocrText != null && question.ocrText!.isNotEmpty)
                  SelectableText(
                    question.ocrText!,
                    style: AppTypography.primary.body.copyWith(color: tc.primary),
                  ),

                SizedBox(height: AppSpacing.lg),

                // ── Review Progress ────────────────────────────
                ReviewProgressBar(
                  currentRound: question.currentReviewRound,
                  totalRounds: question.totalReviewRounds,
                  height: 6,
                ),

                SizedBox(height: AppSpacing.md),

                // ── Status + Date ──────────────────────────────
                Row(
                  children: [
                    EHStatusChip(status: question.status.code),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      '录入于 ${_formatDate(question.createdAt)}',
                      style: AppTypography.primary.caption.copyWith(color: tc.tertiary),
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.lg),

                // ── Error Category ─────────────────────────────
                Text('错因分析', style: AppTypography.primary.h3.copyWith(color: tc.primary)),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    EHErrorCategoryChip(category: question.errorCategory.code, size: EHChipSize.lg),
                    ...question.subCategories.map((sub) => Container(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: AppRadius.radiusSm,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(sub, style: AppTypography.primary.caption.copyWith(color: tc.secondary)),
                        )),
                  ],
                ),

                SizedBox(height: AppSpacing.lg),

                // ── Knowledge Points ───────────────────────────
                if (question.knowledgePoints.isNotEmpty) ...[
                  Text('知识点', style: AppTypography.primary.h3.copyWith(color: tc.primary)),
                  SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: question.knowledgePoints.map((kp) => EHFilterChip(
                          label: kp.name,
                          selected: true,
                          onChanged: (_) {},
                          allowUnselect: false,
                        )).toList(),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ── My Answer ──────────────────────────────────
                if (question.myAnswer != null || _isEditMode) ...[
                  Text('我的错误答案', style: AppTypography.primary.h3.copyWith(color: tc.primary)),
                  SizedBox(height: AppSpacing.sm),
                  if (_isEditMode)
                    TextField(
                      controller: _myAnswerController,
                      maxLines: null,
                      style: AppTypography.primary.body.copyWith(color: tc.primary),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                        contentPadding: AppSpacing.cardInnerPadding,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.05),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Text(
                        question.myAnswer!,
                        style: AppTypography.primary.body.copyWith(color: AppColors.danger),
                      ),
                    ),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ── Correct Answer ─────────────────────────────
                if (question.correctAnswer != null || _isEditMode) ...[
                  Text('正确答案', style: AppTypography.primary.h3.copyWith(color: tc.primary)),
                  SizedBox(height: AppSpacing.sm),
                  if (_isEditMode)
                    TextField(
                      controller: _correctAnswerController,
                      maxLines: null,
                      style: AppTypography.primary.body.copyWith(color: tc.primary),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                        contentPadding: AppSpacing.cardInnerPadding,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.05),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Text(
                        question.correctAnswer!,
                        style: AppTypography.primary.body.copyWith(color: AppColors.success),
                      ),
                    ),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ── Solution Steps (Collapsible) ────────────────
                if (question.solutionSteps.isNotEmpty) ...[
                  _buildCollapsibleSection(
                    sectionId: 'solution',
                    title: '解题步骤',
                    icon: Icons.lightbulb_outline,
                    child: SolutionSteps(steps: question.solutionSteps),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ── Review History (Collapsible) ────────────────
                _buildCollapsibleSection(
                  sectionId: 'history',
                  title: '复习历史',
                  icon: Icons.history_rounded,
                  child: ReviewHistoryTimeline(records: question.reviewHistory),
                ),

                SizedBox(height: AppSpacing.lg),

                // ── Custom Tags (Collapsible) ───────────────────
                if (question.customTags.isNotEmpty) ...[
                  _buildCollapsibleSection(
                    sectionId: 'tags',
                    title: '自定义标签',
                    icon: Icons.label_outline,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: question.customTags.map((tag) => Container(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withOpacity(0.1),
                              borderRadius: AppRadius.radiusFull,
                            ),
                            child: Text(tag, style: AppTypography.primary.caption.copyWith(color: AppColors.brandPrimary)),
                          )).toList(),
                    ),
                  ),
                ],

                SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),

          // ── Bottom Fixed Button ──────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: AppSpacing.pagePadding.copyWith(
                top: AppSpacing.sm,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: question.isEliminated
                  ? EHPrimaryButton(
                      text: '已消灭 ✅',
                      onPressed: null,
                      fullWidth: true,
                      size: EHButtonSize.lg,
                      enabled: false,
                    )
                  : EHPrimaryButton(
                      text: '开始复习此题',
                      onPressed: () {
                        // TODO: 单题复习功能开发中，后续接入 Routes.review
                        EHToast.show(
                          context,
                          message: '单题复习功能开发中，请使用复习模块进行复习',
                          type: EHToastType.info,
                        );
                      },
                      fullWidth: true,
                      size: EHButtonSize.lg,
                      icon: Icons.play_arrow_rounded,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bug #28: 可折叠区块组件
  Widget _buildCollapsibleSection({
    required String sectionId,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final tc = context.textColors;
    final isExpanded = _expandedSections.contains(sectionId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(sectionId);
              } else {
                _expandedSections.add(sectionId);
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.brandPrimary),
                SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style: AppTypography.primary.h3.copyWith(color: tc.primary),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: tc.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: child,
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  /// 通用网络图片组件，带 loading 和 error 状态
  Widget _buildNetworkImage(String url, {BoxFit fit = BoxFit.contain}) {
    final tc = context.textColors;
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            color: AppColors.brandPrimary,
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        height: 120,
        color: AppColors.background,
        child: Center(
          child: Icon(Icons.image_not_supported, color: tc.tertiary),
        ),
      ),
    );
  }
}
