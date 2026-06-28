/// StorageRemoteDataSource 单元测试
///
/// 守护修复3：存储管理云端化。
/// - getUsage() 解析 /v1/storage 返回的 used_bytes/image_count/images/
///   total/has_more，映射成 CloudImage 列表与 StorageUsage。
/// - getStorageLimit() 解析 /v1/users/me 的 storage_limit（>0 返回，否则 null）。
///
/// 用手写 FakeApiClient 喂 JSON，与 review_remote_data_source_test.dart 风格一致。
library;

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/data/remote/api_client.dart";
import "package:errorhunter_app/data/remote/storage_remote_data_source.dart";

/// 可记录调用、按 path 返回预设 body 的假 ApiClient。
class FakeApiClient implements ApiClient {
  FakeApiClient(this._responses);

  /// path → 该请求应返回的 `data` 字段（外层 {"code":0,"data":...} 里的 data）。
  /// 值为 null 表示返回 null data。
  final Map<String, dynamic?> _responses;

  final List<String> calls = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(path);
    final inner = _responses[path];
    // 产品代码读取 response.data['data']（外层 {"code":0,"data":...} 信封），
    // 故 fake 用 {"data": inner} 包一层；inner 为 null 时 data['data'] 亦为 null。
    return Response<T>(
      data: <String, dynamic>{'data': inner} as T?,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      "FakeApiClient does not implement ${invocation.memberName}",
    );
  }
}

void main() {
  group("getUsage", () {
    test("解析 used_bytes/image_count/images/total/has_more 与 CloudImage 字段映射",
        () async {
      final client = FakeApiClient({
        "/storage": <String, dynamic>{
          "used_bytes": 1048576,
          "image_count": 2,
          "total": 42,
          "has_more": true,
          "images": [
            {
              "url": "https://cdn.example.com/files/img1.png",
              "size": 512000,
              "last_modified": "2026-06-20T08:30:00.000Z",
              "key": "users/u1/img1.png",
            },
            {
              "url": "https://cdn.example.com/files/img2.png",
              "size": 536576,
              "last_modified": "2026-06-21T09:00:00.000Z",
              "key": "users/u1/img2.png",
            },
          ],
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();

      expect(client.calls, ["/storage"]);
      expect(usage.usedBytes, 1048576);
      expect(usage.imageCount, 2);
      expect(usage.total, 42);
      expect(usage.hasMore, isTrue);
      expect(usage.images.length, 2);

      final img1 = usage.images[0];
      expect(img1.url, "https://cdn.example.com/files/img1.png");
      expect(img1.size, 512000);
      expect(img1.key, "users/u1/img1.png");
      expect(img1.lastModified, DateTime.parse("2026-06-20T08:30:00.000Z"));

      final img2 = usage.images[1];
      expect(img2.url, "https://cdn.example.com/files/img2.png");
      expect(img2.key, "users/u1/img2.png");
    });

    test("images 缺失 → 空列表不崩，其余字段按默认", () async {
      final client = FakeApiClient({
        "/storage": <String, dynamic>{
          "used_bytes": 0,
          "image_count": 0,
          // 不含 images / total / has_more
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();

      expect(usage.images, isEmpty);
      expect(usage.usedBytes, 0);
      expect(usage.imageCount, 0);
      expect(usage.total, 0); // 缺省 0
      expect(usage.hasMore, isFalse); // 缺省 false
    });

    test("images 为空数组 → 空列表不崩", () async {
      final client = FakeApiClient({
        "/storage": <String, dynamic>{
          "used_bytes": 0,
          "image_count": 0,
          "images": <dynamic>[],
          "total": 0,
          "has_more": false,
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();
      expect(usage.images, isEmpty);
    });

    test("data 为 null → 返回默认 StorageUsage（不崩）", () async {
      final client = FakeApiClient({
        "/storage": null,
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();
      expect(usage.usedBytes, 0);
      expect(usage.imageCount, 0);
      expect(usage.images, isEmpty);
      expect(usage.total, 0);
      expect(usage.hasMore, isFalse);
    });

    test("images 元素字段缺失 → CloudImage 走默认（url='', size=0, key=null）",
        () async {
      final client = FakeApiClient({
        "/storage": <String, dynamic>{
          "used_bytes": 100,
          "image_count": 1,
          "images": [
            // 只给一个空对象，模拟后端字段不全
            <String, dynamic>{},
          ],
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();
      expect(usage.images.length, 1);
      final img = usage.images.single;
      expect(img.url, "");
      expect(img.size, 0);
      expect(img.key, isNull);
      // last_modified 解析失败 → epoch
      expect(img.lastModified,
          DateTime.fromMillisecondsSinceEpoch(0));
    });

    test("images 含非 Map 元素被安全跳过（不崩）", () async {
      final client = FakeApiClient({
        "/storage": <String, dynamic>{
          "used_bytes": 100,
          "image_count": 2,
          "images": [
            "not-a-map", // 异常元素
            {
              "url": "https://cdn.example.com/ok.png",
              "size": 100,
              "last_modified": "2026-06-22T00:00:00.000Z",
            },
          ],
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();
      // 非 Map 被跳过，只保留 1 个有效项
      expect(usage.images.length, 1);
      expect(usage.images.single.url, "https://cdn.example.com/ok.png");
    });

    test("has_more 缺省为 false，total 缺省为 0", () async {
      final client = FakeApiClient({
        "/storage": <String, dynamic>{
          "used_bytes": 200,
          "image_count": 1,
          "images": [
            {
              "url": "https://cdn.example.com/a.png",
              "size": 200,
              "last_modified": "2026-06-22T00:00:00.000Z",
            },
          ],
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final usage = await ds.getUsage();
      expect(usage.hasMore, isFalse);
      expect(usage.total, 0);
    });
  });

  group("getStorageLimit", () {
    test("解析 /users/me 的 storage_limit（>0 返回）", () async {
      final client = FakeApiClient({
        "/users/me": <String, dynamic>{
          "id": "u1",
          "storage_limit": 524288000, // 500MB
          "streak_days": 7,
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      final limit = await ds.getStorageLimit();

      expect(client.calls, ["/users/me"]);
      expect(limit, 524288000);
    });

    test("storage_limit = 0 → 返回 null（调用方按默认降级）", () async {
      final client = FakeApiClient({
        "/users/me": <String, dynamic>{
          "storage_limit": 0,
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      expect(await ds.getStorageLimit(), isNull);
    });

    test("storage_limit 缺失 → 返回 null", () async {
      final client = FakeApiClient({
        "/users/me": <String, dynamic>{
          "id": "u1",
          // 不含 storage_limit
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      expect(await ds.getStorageLimit(), isNull);
    });

    test("storage_limit 为负数 → 返回 null", () async {
      final client = FakeApiClient({
        "/users/me": <String, dynamic>{
          "storage_limit": -1,
        },
      });
      final ds = StorageRemoteDataSource(client: client);

      expect(await ds.getStorageLimit(), isNull);
    });

    test("data 为 null → 返回 null（不崩）", () async {
      final client = FakeApiClient({
        "/users/me": null,
      });
      final ds = StorageRemoteDataSource(client: client);

      expect(await ds.getStorageLimit(), isNull);
    });
  });

  // ─── 测试D（边界）：StorageUsage 模型本身 ───
  group("StorageUsage 模型", () {
    test("默认构造全为 0/false/空", () {
      const usage = StorageUsage();
      expect(usage.usedBytes, 0);
      expect(usage.imageCount, 0);
      expect(usage.images, isEmpty);
      expect(usage.total, 0);
      expect(usage.hasMore, isFalse);
    });

    test("CloudImage.fromJson 缺 last_modified → epoch，不抛", () {
      final img = CloudImage.fromJson({"url": "u", "size": 1});
      expect(img.lastModified, DateTime.fromMillisecondsSinceEpoch(0));
      expect(img.url, "u");
      expect(img.size, 1);
    });

    test("CloudImage 缺 url → 空串，缺 size → 0", () {
      final img = CloudImage.fromJson({"last_modified": "2026-06-22T00:00:00.000Z"});
      expect(img.url, "");
      expect(img.size, 0);
    });
  });
}
