/// 错题猎手 - P6 错题详情页
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/chips/error_category_chip.dart';
import '../../../widgets/common/chips/filter_chip.dart';
import '../../../widgets/common/chips/status_chip.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../../../widgets/common/icons/eliminated_check_icon.dart';
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
  bool _isSaving = false;

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
    // 防抖：保存中不允许再次点击
    if (_isSaving) return;

    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _ocrController.text = question.ocrText ?? '';
        _myAnswerController.text = question.myAnswer ?? '';
        _correctAnswerController.text = question.correctAnswer ?? '';
      } else {
        // Auto-save on exit edit mode (with debounce + error handling)
        _saveEdits(question);
      }
    });
  }

  Future<void> _saveEdits(QuestionModel question) async {
    if (_isSaving) return;

    final newOcr = _ocrController.text.isEmpty ? null : _ocrController.text;
    final newMyAnswer =
        _myAnswerController.text.isEmpty ? null : _myAnswerController.text;
    final newCorrectAnswer = _correctAnswerController.text.isEmpty
        ? null
        : _correctAnswerController.text;

    // 内容无变化时不发请求，避免无谓网络开销，也避免"内容相同→state 不变→
    // listener 不触发→_isSaving 卡住"的边界。
    if (newOcr == question.ocrText &&
        newMyAnswer == question.myAnswer &&
        newCorrectAnswer == question.correctAnswer) {
      return;
    }

    setState(() => _isSaving = true);
    final updated = question.copyWith(
      ocrText: newOcr,
      myAnswer: newMyAnswer,
      correctAnswer: newCorrectAnswer,
      updatedAt: DateTime.now(),
    );
    // 派发更新事件；真正的成功/失败由 bloc emit 的状态驱动（见 _onStateChanged）。
    // 之前在这里 try/catch 包 add()，但 add 同步派发不抛异常，导致"已自动保存"
    // 总是先弹，即便后端保存失败也提示成功。
    context.read<QuestionBloc>().add(UpdateQuestion(updated));
  }

  /// 监听 bloc 状态：保存成功 → 提示；失败 → 提示并回退编辑态。
  void _onStateChanged(BuildContext context, QuestionState state) {
    if (state is QuestionDetailLoaded && _isSaving) {
      // UpdateQuestion 成功后 bloc emit QuestionDetailLoaded(updated)，
      // 此时 state.question 已是最新数据。
      setState(() => _isSaving = false);
      EHToast.show(context, message: '已自动保存', type: EHToastType.success);
    } else if (state is QuestionUpdateFailed && _isSaving) {
      setState(() => _isSaving = false);
      EHToast.show(context, message: state.message, type: EHToastType.error);
    }
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
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return BlocConsumer<QuestionBloc, QuestionState>(
      listener: _onStateChanged,
      builder: (context, state) {
        if (state is QuestionDetailLoading) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(
                child: CircularProgressIndicator(color: accentColor)),
          );
        }

        if (state is QuestionDetailLoaded) {
          return _buildDetail(state.question);
        }

        if (state is QuestionError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(
              child: Text(state.message,
                  style:
                      AppTypography.primary.body.copyWith(color: tc.primary)),
            ),
          );
        }

        // 其它状态（如初始）：显示加载中，initState 已派发 LoadQuestionDetail
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
              child: CircularProgressIndicator(color: accentColor)),
        );
      },
    );
  }

  Widget _buildDetail(QuestionModel question) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // 玻璃下红/绿语义色对比度不足，提亮以保证可读
    final dangerColor =
        isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    final successColor =
        isGlass ? const Color(0xFF81C784) : AppColors.success;
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
              onTap: _isSaving ? null : () => _toggleEdit(question),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                      )
                    else
                      Icon(Icons.edit_outlined, size: 18, color: accentColor),
                    SizedBox(width: 2),
                    Text(
                      _isEditMode ? '完成' : '编辑',
                      style: AppTypography.primary.caption.copyWith(
                        color: _isSaving ? accentColor.withOpacity(0.5) : accentColor,
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
                        border: Border.all(
                            color: isGlass
                                ? Colors.white.withOpacity(0.25)
                                : AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: question.imageUrl.startsWith('/')
                          ? Image.file(File(question.imageUrl), fit: BoxFit.contain)
                          : _buildNetworkImage(question.imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ── OCR Text (仅编辑态) ──────────────────────
                // 非编辑态不再展示识别文字：原图已包含题目内容，重复显示无意义。
                // 编辑态保留输入框，便于订正 OCR 文本（仍用于搜索）。
                if (_isEditMode)
                  TextField(
                    controller: _ocrController,
                    maxLines: null,
                    style: AppTypography.primary.body.copyWith(color: tc.primary),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                      contentPadding: AppSpacing.cardInnerPadding,
                    ),
                  ),

                SizedBox(height: AppSpacing.lg),

                // ── Review Progress ────────────────────────────
                ReviewProgressBar(
                  masterCount: question.masterCount,
                  isEliminated: question.isEliminated,
                  height: 6,
                  nextReviewDate: question.nextReviewDate,
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
                            color: isGlass
                                ? Colors.white.withOpacity(0.12)
                                : AppColors.background,
                            borderRadius: AppRadius.radiusSm,
                            border: Border.all(
                                color: isGlass
                                    ? Colors.white.withOpacity(0.25)
                                    : AppColors.border),
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
                        color: dangerColor.withOpacity(isGlass ? 0.16 : 0.05),
                        borderRadius: AppRadius.radiusMd,
                        border: isGlass
                            ? Border.all(color: dangerColor.withOpacity(0.4))
                            : null,
                      ),
                      child: Text(
                        question.myAnswer!,
                        style: AppTypography.primary.body.copyWith(color: dangerColor),
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
                        color: successColor.withOpacity(isGlass ? 0.16 : 0.05),
                        borderRadius: AppRadius.radiusMd,
                        border: isGlass
                            ? Border.all(color: successColor.withOpacity(0.4))
                            : null,
                      ),
                      child: Text(
                        question.correctAnswer!,
                        style: AppTypography.primary.body.copyWith(color: successColor),
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
                  // 折叠态下也可见总轮次；展开后由时间线直接列各轮记录，不重复标题。
                  trailing: _reviewRoundBadge(question),
                  child: ReviewHistoryTimeline(
                    records: question.reviewHistory,
                    totalReviewCount: question.reviewCount,
                  ),
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
                              color: accentColor.withOpacity(isGlass ? 0.2 : 0.1),
                              borderRadius: AppRadius.radiusFull,
                              border: isGlass
                                  ? Border.all(color: accentColor.withOpacity(0.5))
                                  : null,
                            ),
                            child: Text(tag, style: AppTypography.primary.caption.copyWith(color: accentColor)),
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
                color: isGlass
                    ? Colors.white.withOpacity(0.18)
                    : AppColors.surface,
                border: isGlass
                    ? Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.25)),
                      )
                    : null,
                boxShadow: isGlass
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
              ),
              child: question.isEliminated
                  ? _buildEliminatedButton(isGlass)
                  : EHPrimaryButton(
                      text: '开始复习此题',
                      onPressed: () {
                        // 单题复习：进入仅含该题的复习流程，复用正常复习提交，
                        // 自评后推进艾宾浩斯计划、更新复习统计（不影响其他题）。
                        context.go(Routes.review, extra: {
                          'questionIds': [question.id],
                        });
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
  ///
  /// [trailing] 标题行尾部、折叠箭手左侧的附加内容（如复习历史"共 N 轮"），
  /// 在折叠态下也可见，便于不展开即可看汇总。
  Widget _buildCollapsibleSection({
    required String sectionId,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
                Icon(icon, size: 18, color: accentColor),
                SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style: AppTypography.primary.h3.copyWith(color: tc.primary),
                ),
                if (trailing != null) ...[
                  SizedBox(width: AppSpacing.sm),
                  trailing,
                ],
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
    // created_at 带时区偏移，DateTime.parse 得到 UTC DateTime；先转本地再取日期，
    // 避免凌晨前后的题目录入日期跨天错位（如本地 6/28 00:30 显示成 6/27）。
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  /// 已消灭态底部按钮：success 渐变 + chunky 底影（与主按钮同款），配带质感的
  /// 勾选徽标，呈现"完成"的庆祝感，替代原先禁用淡蓝按钮 + ✅ emoji。
  Widget _buildEliminatedButton(bool isGlass) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.success,
        borderRadius: AppRadius.radiusLg,
        boxShadow: [
          BoxShadow(
            color: AppGradients.successDark,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EliminatedCheckIcon(size: 24, isGlass: isGlass),
          SizedBox(width: AppSpacing.xs),
          Text(
            '已消灭',
            style: AppTypography.primary.button.copyWith(
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 复习历史标题行的"共 N 轮"徽标。
  /// 取累计复习次数（后端 review_count）；为 0（mock/旧缓存）时回退记录条数。
  /// 无任何复习记录时返回 null，不展示徽标。
  Widget? _reviewRoundBadge(QuestionModel question) {
    final count = question.reviewCount > 0
        ? question.reviewCount
        : question.reviewHistory.length;
    if (count == 0) return null;
    final tc = context.textColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: tc.tertiary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '共 $count 轮',
        style: AppTypography.primary.caption.copyWith(
          color: tc.secondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 通用网络图片组件，带 loading 和 error 状态
  Widget _buildNetworkImage(String url, {BoxFit fit = BoxFit.contain}) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
            color: accentColor,
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        height: 120,
        color: isGlass ? Colors.white.withOpacity(0.12) : AppColors.background,
        child: Center(
          child: Icon(Icons.image_not_supported, color: tc.tertiary),
        ),
      ),
    );
  }
}
