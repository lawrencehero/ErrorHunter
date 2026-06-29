/// 错题猎手 - 回收站页面 (P-RecycleBin)
/// 展示已删除错题列表，支持左滑恢复/永久删除，30天自动清理提示
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/question_repository.dart';
import '../models/question_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';
import '../../../widgets/common/dialogs/snackbar.dart';
import '../../../widgets/common/dialogs/toast.dart';

/// 回收站页面
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<QuestionModel> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await sl<QuestionRepository>().getRecycleBin();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败，请下拉重试';
        _isLoading = false;
      });
    }
  }

  /// 恢复错题（乐观更新 + 失败回滚）
  Future<void> _restoreItem(QuestionModel item) async {
    final previous = List<QuestionModel>.from(_items);
    setState(() => _items = _items.where((q) => q.id != item.id).toList());

    try {
      await sl<QuestionRepository>().restoreQuestion(item.id);
      if (!mounted) return;
      EHSnackbar.show(context, message: '已恢复到错题本', icon: Icons.restore);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      EHToast.show(context, message: '恢复失败，请重试', type: EHToastType.error);
    }
  }

  /// 永久删除单条
  Future<void> _permanentDelete(QuestionModel item) async {
    final confirmed = await EHConfirmDialog.show(
      context,
      title: '永久删除',
      content: '确定要永久删除这道错题吗？此操作不可撤销。',
      confirmText: '删除',
      isDestructive: true,
      icon: Icons.delete_forever,
    );

    if (confirmed != true || !mounted) return;

    final previous = List<QuestionModel>.from(_items);
    setState(() => _items = _items.where((q) => q.id != item.id).toList());

    try {
      await sl<QuestionRepository>().permanentDeleteQuestion(item.id);
      if (!mounted) return;
      EHSnackbar.show(context, message: '已永久删除', icon: Icons.delete_outline);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      EHToast.show(context, message: '删除失败，请重试', type: EHToastType.error);
    }
  }

  /// 清空回收站
  Future<void> _clearAll() async {
    if (_items.isEmpty) return;

    final confirmed = await EHConfirmDialog.show(
      context,
      title: '清空回收站',
      content: '确定要清空回收站中的所有 ${_items.length} 道错题吗？此操作不可撤销。',
      confirmText: '全部清空',
      isDestructive: true,
      icon: Icons.delete_sweep,
    );

    if (confirmed != true || !mounted) return;

    final previous = List<QuestionModel>.from(_items);
    setState(() => _items = const []);

    try {
      final count = await sl<QuestionRepository>().clearRecycleBin();
      if (!mounted) return;
      EHSnackbar.show(
        context,
        message: count > 0 ? '已清空 $count 道错题' : '回收站已清空',
        icon: Icons.delete_sweep,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      EHToast.show(context, message: '清空失败，请重试', type: EHToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '回收站',
          style: AppTypography.primary.h2.copyWith(color: tc.primary),
        ),
        centerTitle: true,
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_sweep,
                  size: 18,
                  color: isGlass ? const Color(0xFFFF8A80) : AppColors.danger),
              label: Text(
                '清空',
                style: TextStyle(
                    color: isGlass ? const Color(0xFFFF8A80) : AppColors.danger,
                    fontSize: 14),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    // 错误态：提供重试
    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            SizedBox(height: AppSpacing.sm),
            Text(_errorMessage!,
                style: AppTypography.primary.body
                    .copyWith(color: context.textColors.primary)),
            SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: _loadData,
              child: Text('点击重试',
                  style: AppTypography.primary.button
                      .copyWith(color: accentColor)),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // 30天自动清理提示
        _buildRetentionBanner(),
        // 列表
        Expanded(
          child: RefreshIndicator(
            color: accentColor,
            onRefresh: _loadData,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingHorizontal,
                vertical: AppSpacing.sm,
              ),
              itemCount: _items.length,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _buildDismissibleItem(_items[index]),
            ),
          ),
        ),
      ],
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Center(
      child: EHBaseCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        margin: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass
                    ? Colors.white.withOpacity(0.12)
                    : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                size: 48,
                color: isGlass ? accentColor : AppColors.textTertiary,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            Text(
              '回收站为空',
              style: AppTypography.primary.h3.copyWith(
                color: tc.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '删除的错题会在这里保留30天',
              style: AppTypography.primary.caption.copyWith(
                color: tc.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 30天自动清理提示横幅
  Widget _buildRetentionBanner() {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingHorizontal,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isGlass
            ? accentColor.withOpacity(0.18)
            : const Color(0xFFFFF8E1),
        border: Border(
          bottom: BorderSide(
            color: isGlass
                ? Colors.white.withOpacity(0.25)
                : const Color(0xFFFFE082),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16,
              color: isGlass ? accentColor : const Color(0xFFF9A825)),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '删除的错题将在30天后自动永久清除',
              style: AppTypography.primary.caption.copyWith(
                color: isGlass ? tc.primary : const Color(0xFF795548),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 可滑动删除/恢复的列表项
  Widget _buildDismissibleItem(QuestionModel item) {
    final isGlass = context.themeExt.isDarkBackground;
    final successColor =
        isGlass ? const Color(0xFF81C784) : AppColors.success;
    final dangerColor =
        isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.horizontal,
      dragStartBehavior: DragStartBehavior.down,
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.restore,
        label: '恢复',
        color: successColor,
        isGlass: isGlass,
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_forever,
        label: '永久删除',
        color: dangerColor,
        isGlass: isGlass,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 左滑 → 恢复
          await _restoreItem(item);
          return false; // 手动管理列表移除
        } else {
          // 右滑 → 永久删除
          await _permanentDelete(item);
          return false;
        }
      },
      child: _buildItemCard(item),
    );
  }

  /// 滑动背景
  Widget _buildSwipeBackground({
    required Alignment alignment,
    required IconData icon,
    required String label,
    required Color color,
    required bool isGlass,
  }) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withOpacity(isGlass ? 0.28 : 0.15),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.primary.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 列表项卡片
  Widget _buildItemCard(QuestionModel item) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    // deletedAt 缺失时回退 updatedAt，再回退 createdAt，保证展示有值
    final deletedAt = item.deletedAt ?? item.updatedAt ?? item.createdAt;
    return EHBaseCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          // 科目图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.errorCategoryColor(item.errorCategory.code)
                  .withOpacity(isGlass ? 0.22 : 0.12),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Center(
              child: Text(
                _subjectEmoji(item.subject),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // 文本内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ocrText?.isNotEmpty == true
                      ? item.ocrText!
                      : '无文字内容',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.primary.body.copyWith(
                    color: tc.primary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _buildTag(item.subject),
                    SizedBox(width: AppSpacing.xs),
                    _buildTag(_formatDeletedDate(deletedAt)),
                    SizedBox(width: AppSpacing.xs),
                    _buildRemainingDaysTag(_remainingDays(deletedAt)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 距离被永久删除还剩多少天（按 30 天保留期）
  int _remainingDays(DateTime deletedAt) {
    const retentionPeriod = Duration(days: 30);
    final expiresAt = deletedAt.add(retentionPeriod);
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// 格式化删除日期
  String _formatDeletedDate(DateTime deletedAt) {
    final now = DateTime.now();
    final diff = now.difference(deletedAt);
    if (diff.inDays == 0) return '今天删除';
    if (diff.inDays == 1) return '昨天删除';
    if (diff.inDays < 7) return '${diff.inDays}天前删除';
    return '${deletedAt.month}月${deletedAt.day}日删除';
  }

  /// 小标签
  Widget _buildTag(String text) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.12) : AppColors.background,
        borderRadius: AppRadius.radiusSm,
      ),
      child: Text(
        text,
        style: AppTypography.primary.caption.copyWith(
          fontSize: 11,
          color: tc.secondary,
        ),
      ),
    );
  }

  /// 剩余天数标签（紧急时变红）
  Widget _buildRemainingDaysTag(int days) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final isUrgent = days <= 3;
    final dangerColor =
        isGlass ? const Color(0xFFFF8A80) : AppColors.danger;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isUrgent
            ? dangerColor.withOpacity(isGlass ? 0.2 : 0.1)
            : (isGlass ? Colors.white.withOpacity(0.12) : AppColors.background),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Text(
        '剩余${days}天',
        style: AppTypography.primary.caption.copyWith(
          fontSize: 11,
          color: isUrgent ? dangerColor : tc.tertiary,
          fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  /// 科目对应 emoji
  String _subjectEmoji(String subject) {
    switch (subject) {
      case '数学':
        return '📐';
      case '语文':
        return '📝';
      case '英语':
        return '🔤';
      case '科学':
        return '🔬';
      default:
        return '📖';
    }
  }
}
