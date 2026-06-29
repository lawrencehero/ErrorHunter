/// QuestionRemoteDataSource 单元测试
///
/// 守护修复：
/// 1. searchQuestions 必须用 query 参数 `keyword`（后端 ListFilter.Keyword 字段），
///    之前误用 `q`，后端取不到关键字 → 返回全部数据，搜索形同失效。
/// 2. 回收站相关方法（getRecycleBin / restoreQuestion /
///    permanentDeleteQuestion / clearRecycleBin）调用正确的 endpoint 与方法。
///
/// 用手写 FakeApiClient 喂 JSON，与 review_remote_data_source_test.dart 风格一致。
library;

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/data/remote/api_client.dart";
import "package:errorhunter_app/data/remote/api_endpoints.dart";
import "package:errorhunter_app/data/remote/question_remote_data_source.dart";

/// 记录单条请求的快照（方法 + path + query + body）。
class RecordedCall {
  const RecordedCall(this.method, this.path, {this.query, this.body});

  final String method;
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;
}

/// 可记录调用、按 path 返回预设 body 的假 ApiClient。
class FakeApiClient implements ApiClient {
  FakeApiClient(this._responses);

  /// path → 该请求应返回的 `data` 字段（外层 {"code":0,"data":...} 里的 data）。
  final Map<String, dynamic?> _responses;

  final List<RecordedCall> calls = [];

  RecordedCall? _lastCall(String method, String path) {
    for (var i = calls.length - 1; i >= 0; i--) {
      final c = calls[i];
      if (c.method == method && c.path == path) return c;
    }
    return null;
  }

  Response<T> _response<T>(String path) {
    final inner = _responses[path];
    return Response<T>(
      data: <String, dynamic>{'data': inner} as T?,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(RecordedCall('GET', path, query: queryParameters));
    return _response<T>(path);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(RecordedCall('POST', path, query: queryParameters, body: data));
    return _response<T>(path);
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(RecordedCall('PUT', path, query: queryParameters, body: data));
    return _response<T>(path);
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(RecordedCall('DELETE', path, query: queryParameters, body: data));
    return _response<T>(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      "FakeApiClient does not implement ${invocation.memberName}",
    );
  }
}

void main() {
  group("searchQuestions", () {
    test("使用后端约定的 query 参数名 `keyword`，而非 `q`", () async {
      final client = FakeApiClient({
        ApiEndpoints.questions: <String, dynamic>{
          "list": <Map<String, dynamic>>[],
        },
      });
      final ds = QuestionRemoteDataSource(client: client);

      await ds.searchQuestions("方程");

      final call = client.calls.last;
      expect(call.method, 'GET');
      expect(call.path, ApiEndpoints.questions);
      // 关键守护：必须用 keyword，否则后端 ListFilter.Keyword 取不到值
      expect(call.query?.containsKey('keyword'), isTrue,
          reason: '搜索必须用 keyword 参数；用 q 会导致后端忽略关键字返回全部');
      expect(call.query?['keyword'], '方程');
      expect(call.query?.containsKey('q'), isFalse,
          reason: '不应再使用 q 参数');
    });

    test("解析后端返回的 list 数组成 QuestionModel 列表", () async {
      final client = FakeApiClient({
        ApiEndpoints.questions: <String, dynamic>{
          "list": [
            {
              "id": 101,
              "image_url": "http://api.example.com/v1/files/q/101.png",
              "ocr_text": "3x+7=22",
              "error_category": "KNOWLEDGE",
              "status": "REVIEWING",
              "review_round": 2,
              "created_at": "2026-06-28T10:00:00+08:00",
            },
          ],
        },
      });
      final ds = QuestionRemoteDataSource(client: client);

      final result = await ds.searchQuestions("方程");

      expect(result, hasLength(1));
      expect(result.first.id, '101');
      expect(result.first.ocrText, '3x+7=22');
    });
  });

  group("回收站", () {
    test("getRecycleBin 调用 /questions/recycle-bin 并解析 list", () async {
      final client = FakeApiClient({
        ApiEndpoints.recycleBin: <String, dynamic>{
          "list": [
            {
              "id": 5,
              "image_url": "http://api.example.com/v1/files/q/5.png",
              "error_category": "SKILL",
              "status": "NOT_STARTED",
              "deleted_at": "2026-06-20T10:00:00+08:00",
              "created_at": "2026-06-01T10:00:00+08:00",
            },
          ],
        },
      });
      final ds = QuestionRemoteDataSource(client: client);

      final result = await ds.getRecycleBin(page: 2, pageSize: 10);

      final call = client.calls.last;
      expect(call.method, 'GET');
      expect(call.path, ApiEndpoints.recycleBin);
      expect(call.query?['page'], 2);
      expect(call.query?['page_size'], 10);

      expect(result, hasLength(1));
      expect(result.first.id, '5');
      // deleted_at 必须被解析，回收站页据此计算剩余保留天数
      expect(result.first.deletedAt, isNotNull);
    });

    test("restoreQuestion 调用 POST /questions/{id}/restore", () async {
      final client = FakeApiClient(const {});
      final ds = QuestionRemoteDataSource(client: client);

      await ds.restoreQuestion('77');

      final call = client.calls.last;
      expect(call.method, 'POST');
      expect(call.path, ApiEndpoints.withId(ApiEndpoints.questionRestore, '77'));
    });

    test("permanentDeleteQuestion 调用 DELETE /questions/{id}/permanent",
        () async {
      final client = FakeApiClient(const {});
      final ds = QuestionRemoteDataSource(client: client);

      await ds.permanentDeleteQuestion('77');

      final call = client.calls.last;
      expect(call.method, 'DELETE');
      expect(call.path,
          ApiEndpoints.withId(ApiEndpoints.questionPermanentDelete, '77'));
    });

    test("clearRecycleBin 发送 confirm=true 并返回 deleted_count", () async {
      final client = FakeApiClient({
        ApiEndpoints.recycleBinClear: <String, dynamic>{"deleted_count": 3},
      });
      final ds = QuestionRemoteDataSource(client: client);

      final count = await ds.clearRecycleBin();

      final call = client.calls.last;
      expect(call.method, 'DELETE');
      expect(call.path, ApiEndpoints.recycleBinClear);
      // 后端要求二次确认 confirm=true，否则返回 ERecycleBinConfirm
      expect((call.body as Map)['confirm'], isTrue);
      expect(count, 3);
    });
  });
}
