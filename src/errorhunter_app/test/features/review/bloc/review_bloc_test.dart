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
  Future<void> submitReviewResult({
    required String questionId,
    required String selfRating,
    int? reviewDurationSec,
    bool isReviveCheck = false,
  }) async {
    submitted.add({
      'question_id': questionId,
      'self_rating': selfRating,
      'is_revive_check': isReviveCheck,
    });
  }
}

QuestionModel createReviewQuestion({
  String id = "rq001",
  QuestionStatus status = QuestionStatus.notStarted,
  int round = 1,
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
}
