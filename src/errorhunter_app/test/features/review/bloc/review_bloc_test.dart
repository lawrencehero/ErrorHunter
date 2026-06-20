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

  @override
  Future<List<QuestionModel>> getReviewQueue({List<String>? questionIds}) async {
    return mockQueue;
  }

  @override
  Future<int> getStreakDays() async => mockStreakDays;
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
