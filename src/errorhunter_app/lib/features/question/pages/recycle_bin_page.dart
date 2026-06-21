/// 错题猎手 - 回收站页面 (P-RecycleBin)
/// 展示已删除错题列表，支持左滑恢复/永久删除，30天自动清理提示
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';
import '../../../widgets/common/dialogs/snackbar.dart';

/// 回收站中的错题条目（本地数据模型）
class _RecycleBinItem {
  const _RecycleBinItem({
    required this.id,
    required this.ocrText,
    required this.subject,
    required this.errorCategory,
    required this.deletedAt,
  });

  final String id;
  final String ocrText;
  final String subject;
  final String errorCategory;
  final DateTime deletedAt;

  /// 距离被永久删除还剩多少天
  int get remainingDays {
    const retentionPeriod = Duration(days: 30);
    final expiresAt = deletedAt.add(retentionPeriod);
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// 格式化删除日期
  String get formattedDeletedDate {
    final now = DateTime.now();
    final diff = now.difference(deletedAt);
    if (diff.inDays == 0) return '今天删除';
    if (diff.inDays == 1) return '昨天删除';
    if (diff.inDays < 7) return '${diff.inDays}天前删除';
    return '${deletedAt.month}月${deletedAt.day}日删除';
  }
}

/// 回收站页面
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  // TODO: 替换为真实数据源（DatabaseHelper / Repository）
  List<_RecycleBinItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // TODO: 从 DatabaseHelper.getRecycleBinQuestions() 加载真实数据
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      _items = _generateMockItems();
      _isLoading = false;
    });
  }

  /// Mock 数据生成器（开发阶段使用）
  static List<_RecycleBinItem> _generateMockItems() {
    return [
      _RecycleBinItem(
        id: 'rb_1',
        ocrText: '计算 24 × 15 的结果',
        subject: '数学',
        errorCategory: 'SKILL',
        deletedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      _RecycleBinItem(
        id: 'rb_2',
        ocrText: '解方程 3x + 7 = 22',
        subject: '数学',
        errorCategory: 'KNOWLEDGE',
        deletedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      _RecycleBinItem(
        id: 'rb_3',
        ocrText: 'The boy ___ (go) to school every day.',
        subject: '英语',
        errorCategory: 'HABIT',
        deletedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      _RecycleBinItem(
        id: 'rb_4',
        ocrText: '写出"春风又绿江南岸"的下一句',
        subject: '语文',
        errorCategory: 'PSYCHOLOGY',
        deletedAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      _RecycleBinItem(
        id: 'rb_5',
        ocrText: '一个圆的半径为3cm，求面积（π取3.14）',
        subject: '数学',
        errorCategory: 'SKILL',
        deletedAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
    ];
  }

  /// 恢复错题
  Future<void> _restoreItem(_RecycleBinItem item) async {
    // TODO: 调用 DatabaseHelper.restoreQuestion(item.id)
    setState(() => _items.remove(item));

    if (!mounted) return;
    EHSnackbar.show(context, message: '已恢复到错题本', icon: Icons.restore);
  }

  /// 永久删除单条
  Future<void> _permanentDelete(_RecycleBinItem item) async {
    final confirmed = await EHConfirmDialog.show(
      context,
      title: '永久删除',
      content: '确定要永久删除这道错题吗？此操作不可撤销。',
      confirmText: '删除',
      isDestructive: true,
      icon: Icons.delete_forever,
    );

    if (confirmed != true || !mounted) return;

    // TODO: 调用 DatabaseHelper.permanentlyDeleteQuestion(item.id)
    setState(() => _items.remove(item));

    if (!mounted) return;
    EHSnackbar.show(context, message: '已永久删除', icon: Icons.delete_outline);
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

    // TODO: 调用 DatabaseHelper.clearRecycleBin()
    setState(() => _items.clear());

    if (!mounted) return;
    EHSnackbar.show(context, message: '回收站已清空', icon: Icons.delete_sweep);
  }

  @override
  Widget build(BuildContext context) {
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
          style: AppTypography.primary.h2.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, size: 18, color: AppColors.danger),
              label: const Text(
                '清空',
                style: TextStyle(color: AppColors.danger, fontSize: 14),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary));
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
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingHorizontal,
              vertical: AppSpacing.sm,
            ),
            itemCount: _items.length,
            separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _buildDismissibleItem(_items[index]),
          ),
        ),
      ],
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
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
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 48,
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            Text(
              '回收站为空',
              style: AppTypography.primary.h3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '删除的错题会在这里保留30天',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 30天自动清理提示横幅
  Widget _buildRetentionBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingHorizontal,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8E1),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFE082), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFF9A825)),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '删除的错题将在30天后自动永久清除',
              style: AppTypography.primary.caption.copyWith(
                color: const Color(0xFF795548),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 可滑动删除/恢复的列表项
  Widget _buildDismissibleItem(_RecycleBinItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.horizontal,
      dragStartBehavior: DragStartBehavior.down,
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.restore,
        label: '恢复',
        color: AppColors.success,
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_forever,
        label: '永久删除',
        color: AppColors.danger,
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
  }) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
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
  Widget _buildItemCard(_RecycleBinItem item) {
    return EHBaseCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          // 科目图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.errorCategoryColor(item.errorCategory).withOpacity(0.12),
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
                  item.ocrText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.primary.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _buildTag(item.subject),
                    SizedBox(width: AppSpacing.xs),
                    _buildTag(item.formattedDeletedDate),
                    SizedBox(width: AppSpacing.xs),
                    _buildRemainingDaysTag(item.remainingDays),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 小标签
  Widget _buildTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.radiusSm,
      ),
      child: Text(
        text,
        style: AppTypography.primary.caption.copyWith(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// 剩余天数标签（紧急时变红）
  Widget _buildRemainingDaysTag(int days) {
    final isUrgent = days <= 3;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.danger.withOpacity(0.1)
            : AppColors.background,
        borderRadius: AppRadius.radiusSm,
      ),
      child: Text(
        '剩余${days}天',
        style: AppTypography.primary.caption.copyWith(
          fontSize: 11,
          color: isUrgent ? AppColors.danger : AppColors.textTertiary,
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
