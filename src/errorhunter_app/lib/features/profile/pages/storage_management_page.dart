/// 错题猎手 - 存储管理页
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/danger_button.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../widgets/storage_progress_bar.dart';

/// Mock 图片缓存项
class _CachedImageItem {
  const _CachedImageItem({
    required this.id,
    required this.thumbnailUrl,
    required this.date,
    required this.sizeBytes,
  });

  final String id;
  final String thumbnailUrl;
  final DateTime date;
  final int sizeBytes;
}

/// 存储管理页
class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  // TODO: 替换为真实存储数据
  final int _usedBytes = 482 * 1024 * 1024; // 482 MB
  final int _totalBytes = 512 * 1024 * 1024; // 512 MB

  late List<_CachedImageItem> _cachedImages;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _cachedImages = _generateMockImages();
  }

  List<_CachedImageItem> _generateMockImages() {
    final now = DateTime.now();
    return List.generate(20, (i) {
      return _CachedImageItem(
        id: 'img_$i',
        thumbnailUrl: '',
        date: now.subtract(Duration(days: i * 2)),
        sizeBytes: (1024 * 1024 * (0.5 + (i % 5) * 0.3)).toInt(),
      );
    });
  }

  int get _selectedTotalBytes {
    return _cachedImages
        .where((img) => _selectedIds.contains(img.id))
        .fold<int>(0, (sum, img) => sum + img.sizeBytes);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '存储管理',
          style: AppTypography.primary.h3.copyWith(
            color: tc.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── 存储概览 ────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingHorizontal,
              AppSpacing.base,
              AppSpacing.pagePaddingHorizontal,
              AppSpacing.sm,
            ),
            child: EHBaseCard(
              child: StorageProgressBar(
                usedBytes: _usedBytes,
                totalBytes: _totalBytes,
              ),
            ),
          ),

          // ─── 选择操作栏 ──────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingHorizontal,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '图片缓存 (${_cachedImages.length})',
                  style: AppTypography.primary.body.copyWith(
                    color: tc.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: Text(
                    _selectedIds.length == _cachedImages.length
                        ? '取消全选'
                        : '全选',
                    style: AppTypography.primary.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 图片列表 ────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: AppSpacing.pagePadding,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _cachedImages.length,
              itemBuilder: (context, index) {
                final img = _cachedImages[index];
                final isSelected = _selectedIds.contains(img.id);
                return _buildImageTile(img, isSelected);
              },
            ),
          ),

          // ─── 底部清理按钮 ────────────────────────────
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.sm,
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.base,
              ),
              child: EHDangerButton(
                text: _selectedIds.isEmpty
                    ? '请选择要清理的图片'
                    : '清理选中图片 (${_formatBytes(_selectedTotalBytes)})',
                onPressed: _selectedIds.isEmpty ? null : _handleCleanUp,
                fullWidth: true,
                enabled: _selectedIds.isNotEmpty,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(_CachedImageItem img, bool isSelected) {
    final tc = context.textColors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (isSelected) {
            _selectedIds.remove(img.id);
          } else {
            _selectedIds.add(img.id);
          }
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isSelected ? AppColors.brandPrimary : AppColors.border,
              width: isSelected ? 2 : 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 缩略图
              Image.network(
                img.thumbnailUrl,
                fit: BoxFit.cover,
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
                  color: AppColors.background,
                  child: Icon(Icons.image_outlined,
                      size: 32, color: tc.tertiary),
                ),
              ),
              // 选中遮罩
              if (isSelected)
                Container(
                  color: AppColors.brandPrimary.withOpacity(0.3),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 22, color: Colors.white),
                ),
              // 底部信息
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Text(
                    '${img.date.month}/${img.date.day} · ${_formatBytes(img.sizeBytes)}',
                    style: AppTypography.primary.caption.copyWith(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _cachedImages.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_cachedImages.map((img) => img.id));
      }
    });
  }

  void _handleCleanUp() {
    EHConfirmDialog.show(
      context,
      title: '确认清理？',
      content: '将删除${_selectedIds.length}张图片缓存，释放${_formatBytes(_selectedTotalBytes)}空间',
      confirmText: '清理',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _cachedImages
              .removeWhere((img) => _selectedIds.contains(img.id));
          _selectedIds.clear();
        });
        EHToast.show(context,
            message: '清理成功！', type: EHToastType.success);
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
