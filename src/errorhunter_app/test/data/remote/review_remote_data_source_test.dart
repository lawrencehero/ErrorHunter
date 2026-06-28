/// ReviewRemoteDataSource 单元测试
///
/// 守护修复1：getReviewQueue 必须读取后端返回的 `review_items` +
/// `revive_items` 并合并。原 bug 误读不存在的 `data['items']`，
/// 导致队列恒空、ReviewCompleted 全 0。
///
/// 这里用手写 FakeApiClient（与 review_bloc_test.dart 风格一致）喂 JSON，
/// 不依赖真实网络 / Dio 拦截器。
library;

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/data/remote/api_client.dart";
import "package:errorhunter_app/data/remote/review_remote_data_source.dart";
import "package:errorhunter_app/features/question/models/question_model.dart";
import "package:errorhunter_app/utils/image_url_helper.dart";

/// 可记录调用、按 path 返回预设 body 的假 ApiClient。
///
/// 只实现 get<T>（ReviewRemoteDataSource 当前只用到它）。
/// 其它方法直接抛 UnimplementedError，避免被静默误用。
class FakeApiClient implements ApiClient {
  FakeApiClient(this._responses);

  /// path → 该请求应返回的 `data` 字段（即外层 {"code":0,"data":...} 里的 data）。
  /// 若值为 null，则返回 null data。
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

  // ─── 以下方法 ReviewRemoteDataSource 不应调用，命中即说明测试用例错了 ───
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      "FakeApiClient does not implement ${invocation.memberName}",
    );
  }
}

void main() {
  group("getReviewQueue", () {
    test("合并 review_items + revive_items，review 在前 revive 在后", () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{
          "review_items": [
            {
              "id": "r1",
              "image_url": "https://cdn.example.com/r1.png",
              "ocr_text": "2+2=?",
              "error_category": "KNOWLEDGE",
              "status": "REVIEWING",
              "knowledge_points": [
                {"id": "kp1", "name": "加法", "subject": "数学"},
              ],
              "review_round": 2,
              "total_review_rounds": 5,
              "created_at": "2026-06-01T10:00:00.000Z",
            },
            {
              "id": "r2",
              "image_url": "https://cdn.example.com/r2.png",
              "ocr_text": "3*3=?",
              "error_category": "SKILL",
              "status": "NOT_STARTED",
              "knowledge_points": [
                {"id": "kp2", "name": "乘法", "subject": "数学"},
              ],
              "review_round": 1,
              "total_review_rounds": 5,
              "created_at": "2026-06-02T10:00:00.000Z",
            },
          ],
          "revive_items": [
            {
              "id": "v1",
              "image_url": "https://cdn.example.com/v1.png",
              "ocr_text": "旧题：x+1=2",
              "error_category": "KNOWLEDGE",
              "status": "MASTERED",
              "knowledge_points": [
                {"id": "kp3", "name": "方程", "subject": "数学"},
              ],
              "review_round": 5,
              "total_review_rounds": 5,
              "created_at": "2026-05-01T10:00:00.000Z",
            },
          ],
        },
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();

      expect(queue.length, 3);
      // 顺序：review 在前 revive 在后
      expect(queue[0].id, "r1");
      expect(queue[1].id, "r2");
      expect(queue[2].id, "v1");
      // 命中正确的端点
      expect(client.calls, ["/reviews/queue"]);
    });

    test("字段正确映射成 QuestionModel（imageUrl/ocrText/status/knowledgePoints）",
        () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{
          "review_items": [
            {
              "id": 42, // 后端可能返回 int id
              "image_url": "https://cdn.example.com/42.png",
              "ocr_text": "解方程 x+1=2",
              "my_answer": "x=3",
              "correct_answer": "x=1",
              "error_category": "KNOWLEDGE",
              "sub_categories": ["代数"],
              "status": "MASTERED",
              "knowledge_points": [
                {
                  "id": "kp9",
                  "name": "一元一次方程",
                  "subject": "数学",
                  "parent_id": "kp0",
                  "is_recommended": true,
                },
              ],
              "custom_tags": ["期中", "易错"],
              "review_round": 4,
              "total_review_rounds": 5,
              "created_at": "2026-06-10T08:30:00.000Z",
              "updated_at": "2026-06-20T09:00:00.000Z",
              "subject": "数学",
              "grade": "六年级",
            },
          ],
          "revive_items": <dynamic>[],
        },
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();
      expect(queue.length, 1);
      final q = queue.single;

      expect(q.id, "42"); // int → String
      // imageUrl 经 fromJson 归一化（host 替换为当前后端 host），path 保留
      expect(q.imageUrl, normalizeImageUrl("https://cdn.example.com/42.png"));
      expect(q.ocrText, "解方程 x+1=2");
      expect(q.myAnswer, "x=3");
      expect(q.correctAnswer, "x=1");
      expect(q.errorCategory, ErrorCategory.knowledge);
      expect(q.subCategories, ["代数"]);
      expect(q.status, QuestionStatus.mastered);
      expect(q.knowledgePoints.length, 1);
      expect(q.knowledgePoints.single.id, "kp9");
      expect(q.knowledgePoints.single.name, "一元一次方程");
      expect(q.knowledgePoints.single.isRecommended, true);
      expect(q.customTags, ["期中", "易错"]);
      expect(q.currentReviewRound, 4);
      expect(q.totalReviewRounds, 5);
      expect(q.grade, "六年级");
      expect(q.isEliminated, true); // mastered → 已消灭
    });

    // ─── 回归守护：误改回读 `items` 致空 ───
    test("只有 review_items 的 body 解析出非空（守护：不可回退到读 data['items']）",
        () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{
          // 故意不放 revive_items，也不放旧的 items 字段
          "review_items": [
            {
              "id": "only1",
              "image_url": "https://cdn.example.com/only1.png",
              "ocr_text": "1+1",
              "error_category": "HABIT",
              "status": "NOT_STARTED",
              "knowledge_points": <dynamic>[],
              "created_at": "2026-06-03T10:00:00.000Z",
            },
          ],
        },
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();

      // 若有人把代码回退成读 data['items']，这里会拿到 [] → 失败
      expect(queue, isNotEmpty);
      expect(queue.single.id, "only1");
    });

    test("只有 revive_items 的 body 也能解析出非空", () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{
          "revive_items": [
            {
              "id": "revive_only",
              "image_url": "https://cdn.example.com/revive.png",
              "ocr_text": "复活题",
              "error_category": "PSYCHOLOGY",
              "status": "MASTERED",
              "knowledge_points": <dynamic>[],
              "created_at": "2026-05-10T10:00:00.000Z",
            },
          ],
        },
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();
      expect(queue, isNotEmpty);
      expect(queue.single.id, "revive_only");
      expect(queue.single.status, QuestionStatus.mastered);
    });

    test("空 body（data 为空对象）返回空列表且不抛异常", () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{},
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();
      expect(queue, isEmpty);
    });

    test("data 为 null 也不抛异常，返回空列表", () async {
      final client = FakeApiClient({
        "/reviews/queue": null,
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();
      expect(queue, isEmpty);
    });

    test("字段缺失（如缺 ocr_text）不崩、对应字段为 null/默认", () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{
          "review_items": [
            {
              "id": "sparse",
              "image_url": "https://cdn.example.com/sparse.png",
              // 缺 ocr_text / my_answer / correct_answer / knowledge_points
              "error_category": "UNKNOWN",
              "status": "REVIEWING",
              "created_at": "2026-06-04T10:00:00.000Z",
            },
          ],
          "revive_items": <dynamic>[],
        },
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();
      expect(queue.length, 1);
      final q = queue.single;
      expect(q.id, "sparse");
      expect(q.ocrText, isNull);
      expect(q.myAnswer, isNull);
      expect(q.correctAnswer, isNull);
      expect(q.knowledgePoints, isEmpty);
      // total_review_rounds 缺省 5（见 fromJson）
      expect(q.totalReviewRounds, 5);
      expect(q.currentReviewRound, 0);
    });

    // ─── fallback 守护：旧 key current_review_round 仍可解析 ───
    // 后端 json tag 是 review_round；但本地可能缓存了旧版本序列化的
    // current_review_round。fromJson 必须对旧 key 兼容，否则旧缓存题的
    // currentReviewRound 会恒为 0，消灭动画无法触发。
    test("旧 key current_review_round 也能解析出 currentReviewRound（向后兼容）",
        () async {
      final client = FakeApiClient({
        "/reviews/queue": <String, dynamic>{
          "review_items": [
            {
              "id": "legacy1",
              "image_url": "https://cdn.example.com/legacy1.png",
              "ocr_text": "旧缓存题",
              "error_category": "KNOWLEDGE",
              "status": "REVIEWING",
              "knowledge_points": <dynamic>[],
              // 故意只用旧 key，不放 review_round
              "current_review_round": 3,
              "total_review_rounds": 5,
              "created_at": "2026-06-05T10:00:00.000Z",
            },
          ],
          "revive_items": <dynamic>[],
        },
      });
      final ds = ReviewRemoteDataSource(client: client);

      final queue = await ds.getReviewQueue();
      expect(queue.length, 1);
      expect(queue.single.id, "legacy1");
      expect(queue.single.currentReviewRound, 3);
    });

    test("questionIds 透传到 queryParameters（不进入 body）", () async {
      // 用一个能拦截 queryParameters 的变体客户端
      final captured = <Map<String, dynamic>>[];
      final base = _QueryCapturingClient({
        "/reviews/queue": <String, dynamic>{
          "review_items": <dynamic>[],
          "revive_items": <dynamic>[],
        },
      }, captured);

      final ds = ReviewRemoteDataSource(client: base);
      await ds.getReviewQueue(questionIds: ["11", "22"]);

      expect(captured, [
        {
          "path": "/reviews/queue",
          "query": {"question_ids": "11,22"},
        },
      ]);
    });
  });
}

/// 同时捕获 queryParameters 的辅助客户端，用于断言 questionIds 透传。
class _QueryCapturingClient implements ApiClient {
  _QueryCapturingClient(this._responses, this._captured);

  final Map<String, dynamic?> _responses;
  final List<Map<String, dynamic>> _captured;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _captured.add({"path": path, "query": queryParameters});
    return Response<T>(
      data: _responses[path] as T?,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      "_QueryCapturingClient does not implement ${invocation.memberName}",
    );
  }
}
