/// 错题猎手 - Storage Remote Data Source
/// 调用后端 /v1/storage 接口，获取当前用户在 MinIO 的错题图片总用量与图片列表
library;

import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// 云端错题图片元信息（存储管理页列表项）
class CloudImage {
  const CloudImage({
    required this.url,
    required this.size,
    required this.lastModified,
    this.key,
  });

  /// 可被 Image.network 直接加载的图片 URL（/v1/files/<key>）
  final String url;

  /// 字节数
  final int size;

  /// 最后修改时间
  final DateTime lastModified;

  /// 对象 key（便于后续管理）
  final String? key;

  factory CloudImage.fromJson(Map<String, dynamic> json) {
    return CloudImage(
      url: json['url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      lastModified: DateTime.tryParse(json['last_modified'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      key: json['key'] as String?,
    );
  }
}

/// 服务器端存储用量（MinIO 错题图片）
class StorageUsage {
  const StorageUsage({
    this.usedBytes = 0,
    this.imageCount = 0,
    this.images = const [],
    this.total = 0,
    this.hasMore = false,
  });

  /// 图片总字节数
  final int usedBytes;

  /// 图片数量
  final int imageCount;

  /// 图片对象列表（按 last_modified 倒序，最多 200 张）
  final List<CloudImage> images;

  /// 全量图片总数（images 可能截断，total 为后端实际数量）
  final int total;

  /// 是否还有更多图片未返回
  final bool hasMore;

  factory StorageUsage.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>?;
    final images = <CloudImage>[];
    if (rawImages != null) {
      for (final item in rawImages) {
        if (item is Map<String, dynamic>) {
          images.add(CloudImage.fromJson(item));
        }
      }
    }
    return StorageUsage(
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      imageCount: (json['image_count'] as num?)?.toInt() ?? 0,
      images: images,
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

/// Storage 远程数据源 — 对接后端 /v1/storage 接口
class StorageRemoteDataSource {
  StorageRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 获取当前用户在 MinIO 的错题图片总用量与图片列表
  Future<StorageUsage> getUsage() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.storage);
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) return const StorageUsage();
    return StorageUsage.fromJson(data);
  }

  /// 获取当前用户云端存储配额上限（来自 /v1/users/me 的 storage_limit）。
  /// 用于存储管理页顶部进度条的分母。失败返回 null，调用方按默认值降级。
  Future<int?> getStorageLimit() async {
    try {
      final response =
          await _client.get<Map<String, dynamic>>(ApiEndpoints.user);
      final data = response.data?['data'] as Map<String, dynamic>?;
      final limit = (data?['storage_limit'] as num?)?.toInt();
      return (limit != null && limit > 0) ? limit : null;
    } catch (_) {
      return null;
    }
  }
}
