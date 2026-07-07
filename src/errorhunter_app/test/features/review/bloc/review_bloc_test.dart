/// Review BLoC Unit Tests
import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/features/review/bloc/review_bloc.dart";
import "package:errorhunter_app/features/review/bloc/review_event.dart";
import "package:errorhunter_app/features/review/bloc/review_state.dart";
import "package:errorhunter_app/features/review/models/review_report_model.dart";
import "package:errorhunter_app/features/question/models/question_model.dart";
import "package:errorhunter_app/features/question/models/knowledge_point_model.dart";
import "package:errorhunter_app/domain/repositories/review_repository.dart";

class MockReviewRepository implements ReviewRepository {
  List<QuestionModel> mockQueue = [];
  int mockStreakDays = 7;

  /// 记录被提交的复习结果，供测试断言 submit 链路是否触发。
  List<Map<String, dynamic>> submitted = [];

  @override
  Future<List<QuestionModel>> getReviewQueue({List<String>? questionIds}) async {
    return mockQueue;
  }

  @override
  Future<int> getStreakDays() async => mockStreakDays;

  @override
  Future<ReviewReportModel> getTodaySummary() async =>
      ReviewReportModel.empty();

  @override
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
    bool isReviveCheck = false,
    String? reviveResult,
  }) async {
    submitted.add({
      'question_id': questionId,
      'self_rating': selfRating,
      'is_revive_check': isReviveCheck,
      if (reviewDurationSec != null) 'review_duration_sec': reviewDurationSec,
      if (reviveResult != null) 'revive_result': reviveResult,
    });
  }
}

QuestionModel createReviewQuestion({
  String id = "rq001",
  QuestionStatus status = QuestionStatus.notStarted,
  int round = 1,
  int masterCount = 0,
  DateTime? masteredAt,
}) {
  return QuestionModel(
    id: id,
    imageUrl: "https://example.com/img/" + id + ".jpg",
    ocrText: "Solve x+1=2",
    errorCategory: ErrorCategory.knowledge,
    status: status,
    knowledgePoints: const [
      KnowledgePoint(id: "kp1", name: "Equations", subject: "Math"),
    ],
    currentReviewRound: round,
    totalReviewRounds: 5,
    masterCount: masterCount,
    masteredAt: masteredAt,
    createdAt: DateTime(2026, 6, 1),
  );
}

void main() {
  late ReviewBloc bloc;
  late MockReviewRepository mockRepo;

  setUp(() {
    mockRepo = MockReviewRepository();
    bloc = ReviewBloc(mockRepo);
  });

  tearDown(() async {
    await bloc.close();
  });

  group("StartReview", () {
    test("empty queue emits ReviewCompleted with empty report", () async {
      mockRepo.mockQueue = [];
      bloc.add(const StartReview());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReviewLoading>(),
          isA<ReviewCompleted>(),
        ]),
      );
      final state = bloc.state as ReviewCompleted;
      expect(state.report.totalCount, 0);
    });

    test("with questions emits ReviewInProgress", () async {
      mockRepo.mockQueue = [createReviewQuestion(id: "rq001")];
      bloc.add(const StartReview());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReviewLoading>(),
          isA<ReviewInProgress>(),
        ]),
      );
      final state = bloc.state as ReviewInProgress;
      expect(state.currentIndex, 0);
      expect(state.total, 1);
      expect(state.isAnswerShown, false);
    });
  });

  group("ShowAnswer", () {
    test("flips card to show answer", () async {
      mockRepo.mockQueue = [createReviewQuestion()];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      final state = bloc.state as ReviewInProgress;
      expect(state.isAnswerShown, true);
    });
  });

  group("SelfEvaluate", () {
    test("emits EvaluationPending for non-eliminate rating", () async {
      mockRepo.mockQueue = [createReviewQuestion(round: 1)];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.partial));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EvaluationPending>());
    });

    // ─── 回归守护：消灭动画触发条件 ───
    // _checkShouldEliminate 要求 currentReviewRound >= 3 且 rating 为
    // mastered/remembered。若 fromJson 读错 key 致 currentReviewRound 恒 0，
    // 这里会失败（emit 的是 EvaluationPending 而非 EliminateTriggered）。
    test("round>=3 + mastered → 触发 EliminateTriggered（消灭动画可触发）",
        () async {
      mockRepo.mockQueue = [createReviewQuestion(id: "elim1", round: 3)];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.mastered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EliminateTriggered>());
      final state = bloc.state as EliminateTriggered;
      expect(state.questionId, "elim1");
      expect(state.totalEliminated, 1);
    });

    test("round>=3 + remembered → 触发 EliminateTriggered", () async {
      mockRepo.mockQueue = [createReviewQuestion(id: "elim2", round: 4)];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.remembered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EliminateTriggered>());
      expect((bloc.state as EliminateTriggered).totalEliminated, 1);
    });

    test("round<3 + mastered → 不触发 EliminateTriggered（仍 EvaluationPending）",
        () async {
      mockRepo.mockQueue = [createReviewQuestion(id: "noelim", round: 2)];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.mastered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EvaluationPending>());
      expect(bloc.state, isNot(isA<EliminateTriggered>()));
    });
  });

  group("ReviewState models", () {
    test("ReviewInProgress progress calculation", () {
      final q = createReviewQuestion();
      final state = ReviewInProgress(
        currentIndex: 2,
        total: 5,
        currentQuestion: q,
        isAnswerShown: false,
        isReviveCheck: false,
        daysSinceLastMastered: 0,
        eliminatedInSession: 0,
      );
      expect(state.progress, closeTo(0.6, 0.01));
    });

    test("ReviewReportModel.empty creates zero report", () {
      final report = ReviewReportModel.empty();
      expect(report.totalCount, 0);
      expect(report.masteredCount, 0);
      expect(report.partialCount, 0);
      expect(report.forgotCount, 0);
      expect(report.durationMinutes, 0);
      expect(report.streakDays, 0);
      expect(report.eliminatedCount, 0);
    });

    test("ReviewReportModel Equatable", () {
      const a = ReviewReportModel(
        totalCount: 10,
        masteredCount: 5,
        partialCount: 3,
        forgotCount: 2,
        durationMinutes: 15,
        streakDays: 7,
        eliminatedCount: 1,
      );
      const b = ReviewReportModel(
        totalCount: 10,
        masteredCount: 5,
        partialCount: 3,
        forgotCount: 2,
        durationMinutes: 15,
        streakDays: 7,
        eliminatedCount: 1,
      );
      expect(a, equals(b));
    });
  });

  // ─── 修复1 契约守护 ──────────────────────────────────────
  // 这些用例直接锁死"有题就要进复习，不能秒完成"的核心契约。
  // 任何让 ReviewBloc 误把非空队列直接 ReviewCompleted 的回退都会被抓住。
  group("StartReview contract (修复1 守护)", () {
    test("非空队列 → ReviewInProgress，绝不秒完成（不 emit ReviewCompleted）",
        () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "c1"),
        createReviewQuestion(id: "c2"),
      ];
      bloc.add(const StartReview());
      // 不秒完成：期间只应出现 Loading→InProgress，不应出现 ReviewCompleted
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReviewLoading>(),
          isA<ReviewInProgress>(),
        ]),
      );
      final state = bloc.state as ReviewInProgress;
      expect(state.total, 2);
      expect(state.currentIndex, 0);
      expect(state.currentQuestion.id, "c1");
    });

    test("空队列 → ReviewCompleted（与现有用例互补，独立断言不 emit InProgress）",
        () async {
      mockRepo.mockQueue = [];
      bloc.add(const StartReview());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReviewLoading>(),
          isA<ReviewCompleted>(),
        ]),
      );
      // 确保没有混入 InProgress
      expect(bloc.state, isA<ReviewCompleted>());
      expect((bloc.state as ReviewCompleted).report.totalCount, 0);
    });

    test("含一道 mastered 题 → ReviewInProgress.isReviveCheck 为 true",
        () async {
      // revive 检测题：status=mastered，BLoC 据 _isReviveCheck 识别为复活检测
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "revive1",
          status: QuestionStatus.mastered,
          round: 5,
        ),
      ];
      bloc.add(const StartReview());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReviewLoading>(),
          isA<ReviewInProgress>(),
        ]),
      );
      final state = bloc.state as ReviewInProgress;
      expect(state.isReviveCheck, isTrue);
      expect(state.daysSinceLastMastered, greaterThan(0));
    });

    test("非 mastered 题 → isReviveCheck 为 false", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "normal1",
          status: QuestionStatus.reviewing,
        ),
      ];
      bloc.add(const StartReview());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReviewLoading>(),
          isA<ReviewInProgress>(),
        ]),
      );
      expect((bloc.state as ReviewInProgress).isReviveCheck, isFalse);
    });
  });

  group("SelfEvalRating", () {
    test("fromCode valid codes", () {
      expect(SelfEvalRating.fromCode("MASTERED"), SelfEvalRating.mastered);
      expect(SelfEvalRating.fromCode("PARTIAL"), SelfEvalRating.partial);
      expect(SelfEvalRating.fromCode("FORGOT"), SelfEvalRating.forgot);
      expect(SelfEvalRating.fromCode("REMEMBERED"), SelfEvalRating.remembered);
      expect(SelfEvalRating.fromCode("FORGOTTEN"), SelfEvalRating.forgotten);
    });

    test("fromCode invalid returns forgot", () {
      expect(SelfEvalRating.fromCode("INVALID"), SelfEvalRating.forgot);
    });
  });

  group("ReviewEvent Equatable", () {
    test("StartReview equality", () {
      const a = StartReview();
      const b = StartReview();
      expect(a, equals(b));
    });

    test("SelfEvaluate equality by rating", () {
      const a = SelfEvaluate(SelfEvalRating.mastered);
      const b = SelfEvaluate(SelfEvalRating.mastered);
      const c = SelfEvaluate(SelfEvalRating.forgot);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ─── P0 修复守护：复活检测提交 revive_result ──────────────
  // 后端 handleReviveCheck 强制要求 revive_result（REMEMBERED/FORGOTTEN），
  // 缺失返回 400。前端必须把"还记得/忘记"映射为 revive_result 一并提交。
  group("Revive check submit (P0 守护)", () {
    test("复活题评 remembered → 提交带 revive_result=REMEMBERED", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "rev1",
          status: QuestionStatus.mastered,
          round: 5,
          masterCount: 3,
          masteredAt: DateTime(2026, 6, 14),
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.remembered));
      await Future.delayed(const Duration(milliseconds: 50));

      // 复活题不触发消灭动画，走 EvaluationPending
      expect(bloc.state, isA<EvaluationPending>());

      // 确认提交
      bloc.add(const ConfirmAndNext());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockRepo.submitted, isNotEmpty);
      final last = mockRepo.submitted.last;
      expect(last['question_id'], "rev1");
      expect(last['is_revive_check'], isTrue);
      expect(last['revive_result'], "REMEMBERED");
      // self_rating 仍按映射传 MASTERED（后端复活分支不读，但 binding required）
      expect(last['self_rating'], "MASTERED");
    });

    test("复活题评 forgotten → 提交带 revive_result=FORGOTTEN", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "rev2",
          status: QuestionStatus.mastered,
          round: 5,
          masterCount: 3,
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.forgotten));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const ConfirmAndNext());
      await Future.delayed(const Duration(milliseconds: 50));

      final last = mockRepo.submitted.last;
      expect(last['revive_result'], "FORGOTTEN");
      expect(last['self_rating'], "FAILED");
    });

    test("普通题提交不带 revive_result", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "norm1", round: 1, masterCount: 0),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.partial));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const ConfirmAndNext());
      await Future.delayed(const Duration(milliseconds: 50));

      final last = mockRepo.submitted.last;
      expect(last['is_revive_check'], isFalse);
      expect(last.containsKey('revive_result'), isFalse);
    });
  });

  // ─── P0 修复守护：消灭判定用 master_count ──────────────────
  // 后端 master_count >= 3 即消灭。原前端用 currentReviewRound 近似，会误判
  // round=3 但 master_count=0（连续失败重置过）的题为可消灭。
  group("Eliminate by masterCount (P0 守护)", () {
    test("masterCount>=3 + mastered → 触发消灭动画", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "elim_mc",
          round: 1,
          masterCount: 3,
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.mastered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EliminateTriggered>());
    });

    test("masterCount=2 + mastered → 不触发消灭（仍 EvaluationPending）",
        () async {
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "noelim_mc",
          round: 4,
          masterCount: 2,
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.mastered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EvaluationPending>());
      expect(bloc.state, isNot(isA<EliminateTriggered>()));
    });

    test("复活检测题（mastered）即使 masterCount>=3 也不触发消灭动画",
        () async {
      // 复活题已消灭过，走 revive_result 路径，不应再弹消灭动画。
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "revive_noelim",
          status: QuestionStatus.mastered,
          round: 5,
          masterCount: 3,
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.remembered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EvaluationPending>());
      expect(bloc.state, isNot(isA<EliminateTriggered>()));
    });
  });

  // ─── P1 修复守护：复活检测真实天数 ─────────────────────────
  group("daysSinceMastered (P1 守护)", () {
    test("masteredAt 存在 → 计算真实天数", () async {
      // 10 天前消灭
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "rev_days",
          status: QuestionStatus.mastered,
          round: 5,
          masterCount: 3,
          masteredAt: tenDaysAgo,
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      final state = bloc.state as ReviewInProgress;
      // 容忍 ±1 天边界（inDays 舍入）
      expect(state.daysSinceLastMastered, greaterThanOrEqualTo(9));
      expect(state.daysSinceLastMastered, lessThanOrEqualTo(11));
    });

    test("masteredAt 缺失 → 回退 14（兼容旧缓存/mock）", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(
          id: "rev_fallback",
          status: QuestionStatus.mastered,
          round: 5,
          masterCount: 3,
          // masteredAt 不传
        ),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      final state = bloc.state as ReviewInProgress;
      expect(state.daysSinceLastMastered, 14);
    });
  });

  // ─── P1 修复守护：提交携带 review_duration_sec ─────────────
  group("review_duration_sec (P1 守护)", () {
    test("确认提交时携带 review_duration_sec", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "dur1", round: 1, masterCount: 0),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.partial));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const ConfirmAndNext());
      await Future.delayed(const Duration(milliseconds: 50));

      final last = mockRepo.submitted.last;
      expect(last.containsKey('review_duration_sec'), isTrue);
      // 至少 >= 0
      expect(last['review_duration_sec'] as int, greaterThanOrEqualTo(0));
    });

    test("消灭路径提交也携带 review_duration_sec", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "dur2", round: 1, masterCount: 3),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.mastered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EliminateTriggered>());
      expect(mockRepo.submitted, isNotEmpty);
      expect(
        mockRepo.submitted.last.containsKey('review_duration_sec'),
        isTrue,
      );
    });
  });

  // ─── P1 修复守护：中途退出提交撤销窗口内评价 ───────────────
  group("ExitReview (P1 守护)", () {
    test("EvaluationPending 状态退出 → 提交当前评价", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "exit1", round: 1, masterCount: 0),
        createReviewQuestion(id: "exit2", round: 1, masterCount: 0),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.partial));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EvaluationPending>());

      // 模拟用户确认退出
      bloc.add(const ExitReview());
      await Future.delayed(const Duration(milliseconds: 50));

      // 撤销窗口内的评价应被提交
      final submitted = mockRepo.submitted
          .where((s) => s['question_id'] == "exit1")
          .toList();
      expect(submitted, isNotEmpty);
      expect(submitted.last['self_rating'], "PARTIAL");
    });

    test("ReviewInProgress 状态退出（未评价）→ 不提交", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "exit3", round: 1, masterCount: 0),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      // 未评价直接退出
      bloc.add(const ExitReview());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.submitted, isEmpty);
    });
  });

  // ─── P1 修复守护：GoToPrevious 提交撤销窗口内评价 ─────────
  group("GoToPrevious flushes pending (P1 守护)", () {
    test("EvaluationPending 状态回看 → 先提交当前评价", () async {
      mockRepo.mockQueue = [
        createReviewQuestion(id: "prev1", round: 1, masterCount: 0),
        createReviewQuestion(id: "prev2", round: 1, masterCount: 0),
      ];
      bloc.add(const StartReview());
      await Future.delayed(const Duration(milliseconds: 100));
      // 先评价第 1 题并确认，进入第 2 题
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.partial));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const ConfirmAndNext());
      await Future.delayed(const Duration(milliseconds: 50));
      // 现在在第 2 题（prev2）
      expect(bloc.state, isA<ReviewInProgress>());
      expect((bloc.state as ReviewInProgress).currentIndex, 1);

      // 第 2 题评价，进入撤销窗口
      bloc.add(const ShowAnswer());
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const SelfEvaluate(SelfEvalRating.mastered));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<EvaluationPending>());

      // 撤销窗口内立即回看
      bloc.add(const GoToPrevious());
      await Future.delayed(const Duration(milliseconds: 50));

      // prev2 的评价应被提交（不被撤销窗口吞掉）
      final submitted = mockRepo.submitted
          .where((s) => s['question_id'] == "prev2")
          .toList();
      expect(submitted, isNotEmpty);
      expect(submitted.last['self_rating'], "MASTERED");
    });
  });

  // ─── QuestionModel 字段解析守护（跨区必要改动）──────────────
  group("QuestionModel masterCount/masteredAt parsing", () {
    test("fromJson 解析 master_count 和 mastered_at", () {
      final json = {
        'id': 42,
        'image_url': 'https://example.com/x.jpg',
        'status': 'MASTERED',
        'error_category': 'KNOWLEDGE',
        'review_round': 5,
        'total_review_rounds': 5,
        'master_count': 3,
        'mastered_at': '2026-06-14T10:00:00.000Z',
        'created_at': '2026-06-01T00:00:00.000Z',
      };
      final q = QuestionModel.fromJson(json);
      expect(q.masterCount, 3);
      expect(q.masteredAt, isNotNull);
    });

    test("fromJson 缺失 master_count → 默认 0", () {
      final json = {
        'id': 1,
        'image_url': 'x.jpg',
        'status': 'REVIEWING',
        'error_category': 'KNOWLEDGE',
        'review_round': 1,
        'created_at': '2026-06-01T00:00:00.000Z',
      };
      final q = QuestionModel.fromJson(json);
      expect(q.masterCount, 0);
      expect(q.masteredAt, isNull);
    });

    test("toJson 回写 master_count", () {
      final q = createReviewQuestion(id: "t1", masterCount: 2);
      final json = q.toJson();
      expect(json['master_count'], 2);
    });
  });
}
