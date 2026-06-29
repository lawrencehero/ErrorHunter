/// 错题猎手 - 存储管理页
///
/// 展示用户在云端的错题图片用量与图片列表（为未来按云端用量收费做准备）。
/// - 顶部进度卡：云端用量 used_bytes / storage_limit（来自 /v1/users/me）。
/// - 图片列表区：云端图片缩略图（来自 /v1/storage 的 images），按时间倒序。
/// - 点击缩略图：弹出全屏查看器查看原图（支持 pinch 缩放）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../data/remote/storage_remote_data_source.dart';
import '../../../di/injection.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../router/app_router.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../widgets/storage_progress_bar.dart';

/// 云端存储配额兜底值（5GB，与后端默认 storage_limit 一致）。
/// 仅在 /v1/users/me 取配额失败时使用，确保进度条仍可展示。
const int _kFallbackStorageLimit = 5 * 1024 * 1024 * 1024; // 5 GB

/// 存储管理页
class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  bool _isLoading = true;
  String? _loadError;

  /// 云端图片列表
  List<CloudImage> _images = const [];

  /// 云端已用字节（/v1/storage 的 used_bytes）
  int _usedBytes = 0;

  /// 云端图片总数（含未返回部分）
  int _totalCount = 0;

  /// 是否有更多未返回的图片
  bool _hasMore = false;

  /// 云端配额上限（/v1/users/me 的 storage_limit）
  int _storageLimit = _kFallbackStorageLimit;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 并行拉取云端用量与配额上限。
  /// 任一失败均不阻塞页面：用量失败显示错误态，配额失败用兜底值。
  Future<void> _loadData() async {
    try {
      // Future.wait 真正并行：原实现两次串行 await 等于顺序请求，违背注释意图。
      final results = await Future.wait([
        sl<StorageRemoteDataSource>().getUsage(),
        sl<StorageRemoteDataSource>().getStorageLimit(),
      ]);
      final usage = results[0] as StorageUsage;
      final limit = results[1] as int?;

      if (!mounted) return;
      setState(() {
        _usedBytes = usage.usedBytes;
        _images = usage.images;
        _totalCount = usage.total > 0 ? usage.total : usage.imageCount;
        _hasMore = usage.hasMore;
        if (limit != null && limit > 0) _storageLimit = limit;
        _isLoading = false;
        _loadError = null;
      });
    } catch (_) {
      // 友好降级：云端列表加载失败显示错误提示，不阻塞页面其它操作
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '云端图片加载失败，请检查网络后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    // 玻璃拟态：背景为深色渐变，蓝色 brandPrimary / 深灰中性色对比度不足，
    // 改用暖琥珀强调色 + 主题感知文字色（与 reminder_settings_page.dart 保持一致）。
    final isGlass = context.themeExt.isDarkBackground;
    final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
          // ─── 云端用量概览 ────────────────────────────────
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
                totalBytes: _storageLimit,
                label: '云端用量',
                warningHint: '云端存储空间即将用完，建议清理错题图片',
              ),
            ),
          ),

          // ─── 列表标题栏 ──────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingHorizontal,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_outlined, size: 18, color: accent),
                const SizedBox(width: 6),
                Text(
                  '云端图片 ($_totalCount 张${_hasMore ? '，仅展示最近 $_kDisplayCap 张' : ''})',
                  style: AppTypography.primary.body.copyWith(
                    color: tc.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ─── 云端图片列表 ────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 2,
                    ),
                  )
                : _loadError != null
                    ? _buildErrorState(accent)
                    : _images.isEmpty
                        ? _buildEmptyState(tc)
                        : RefreshIndicator(
                            color: accent,
                            onRefresh: _loadData,
                            child: GridView.builder(
                              padding: AppSpacing.pagePadding,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _images.length,
                              itemBuilder: (context, index) =>
                                  _buildImageTile(_images[index]),
                            ),
                          ),
          ),

          // ─── 底部操作（非破坏性） ───────────────────────
          // 云端图片是真实错题数据，删除会导致错题不可用。本页核心是"展示"，
          // 故不提供删除入口；改为"管理错题"跳转到错题本，避免误删数据。
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.sm,
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.base,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(Routes.questions),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('管理错题'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor:
                        isGlass ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMd,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(tc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 64, color: tc.tertiary),
          SizedBox(height: AppSpacing.sm),
          Text(
            '暂无云端图片',
            style: AppTypography.primary.body.copyWith(
              color: tc.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color accent) {
    final tc = context.textColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: tc.tertiary),
          SizedBox(height: AppSpacing.sm),
          Text(
            _loadError!,
            style: AppTypography.primary.body.copyWith(
              color: tc.secondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.base),
          TextButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            icon: Icon(Icons.refresh_rounded, size: 18, color: accent),
            label: Text(
              '重试',
              style: AppTypography.primary.body.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }

  /// 单张云端图片缩略图。点击放大查看原图。
  Widget _buildImageTile(CloudImage img) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    // 玻璃下不可用近白 AppColors.background 作图块底色（会刺眼），改用半透明白。
    final tileFallbackBg =
        isGlass ? Colors.white.withOpacity(0.08) : AppColors.background;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showFullScreenViewer(img);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isGlass ? Colors.white.withOpacity(0.25) : AppColors.border,
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 留白中性底色：contain 缩放后图片四周的空白用统一中性背景填充，
            // 类似 Windows 资源管理器"大图标"视图（图居中、四周留白）。
            Container(color: tileFallbackBg),
            // 云端缩略图（Image.network 加载，带 loading/error 占位）
            Image.network(
              img.url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: tileFallbackBg,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: tileFallbackBg,
                child: Icon(Icons.image_outlined,
                    size: 32, color: tc.tertiary),
              ),
            ),
            // 底部信息：日期 · 大小
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
                  '${img.lastModified.month}/${img.lastModified.day} · ${_formatBytes(img.size)}',
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
    );
  }

  /// 全屏查看器：显示原图，支持 pinch 缩放。
  void _showFullScreenViewer(CloudImage img) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenImageViewer(image: img),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 列表展示上限（与后端 cloudImageListMax 对齐，用于"仅展示最近 N 张"提示）。
const int _kDisplayCap = 200;

/// 全屏图片查看器：支持 pinch 缩放与点击关闭。
class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.image});

  final CloudImage image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 原图 + 双指缩放
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  image.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    );
                  },
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.white70),
                      SizedBox(height: 8),
                      Text('图片加载失败',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            // 顶部信息条
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${image.lastModified.year}-${image.lastModified.month.toString().padLeft(2, '0')}-${image.lastModified.day.toString().padLeft(2, '0')} · ${_viewerFormatBytes(image.size)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _viewerFormatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
