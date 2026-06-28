/// Question BLoC Unit Tests
import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/features/question/bloc/question_bloc.dart";
import "package:errorhunter_app/features/question/bloc/question_event.dart";
import "package:errorhunter_app/features/question/bloc/question_state.dart";
import "package:errorhunter_app/features/question/models/question_model.dart";
import "package:errorhunter_app/features/question/models/knowledge_point_model.dart";
import "package:errorhunter_app/features/question/models/ocr_result.dart";
import "package:errorhunter_app/domain/repositories/question_repository.dart";
import "package:errorhunter_app/utils/image_url_helper.dart";

class MockQuestionRepository implements QuestionRepository {
  List<QuestionModel> mockQuestions = [];
  OcrResult ocrResult = const OcrResult(text: "OCR text result");

  @override
  Future<List<QuestionModel>> getQuestions({
    ErrorCategory? category,
    QuestionStatus? status,
    String? knowledgePointId,
    int page = 1,
  }) async {
    if (category != null) {
      return mockQuestions.where((q) => q.errorCategory == category).toList();
    }
    if (status != null) {
      return mockQuestions.where((q) => q.status == status).toList();
    }
    return mockQuestions;
  }

  @override
  Future<List<QuestionModel>> searchQuestions(String keyword) async {
    return mockQuestions
        .where((q) => q.ocrText?.contains(keyword) ?? false)
        .toList();
  }

  @override
  Future<QuestionModel?> getQuestionDetail(String id) async {
    try {
      return mockQuestions.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<QuestionModel> addQuestion(QuestionModel question) async {
    mockQuestions.add(question);
    return question;
  }

  @override
  Future<void> updateQuestion(QuestionModel question) async {
    final index = mockQuestions.indexWhere((q) => q.id == question.id);
    if (index >= 0) mockQuestions[index] = question;
  }

  @override
  Future<void> deleteQuestion(String id) async {
    mockQuestions.removeWhere((q) => q.id == id);
  }

  @override
  Future<OcrResult> ocrImage(String imagePath) async => ocrResult;
}

QuestionModel createMockQuestion({
  String id = "q001",
  ErrorCategory category = ErrorCategory.knowledge,
  QuestionStatus status = QuestionStatus.notStarted,
}) {
  return QuestionModel(
    id: id,
    imageUrl: "https://example.com/img/" + id + ".jpg",
    ocrText: "Calculate 2+3=?",
    errorCategory: category,
    status: status,
    knowledgePoints: const [
      KnowledgePoint(id: "kp1", name: "Addition", subject: "Math"),
    ],
    createdAt: DateTime(2026, 6, 1),
  );
}

void main() {
  late QuestionBloc bloc;
  late MockQuestionRepository mockRepo;

  setUp(() {
    mockRepo = MockQuestionRepository();
    bloc = QuestionBloc(mockRepo);
  });

  tearDown(() async {
    await bloc.close();
  });

  group("LoadQuestions", () {
    test("empty list returns QuestionListLoaded with empty list", () async {
      bloc.add(const LoadQuestions(refresh: true));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<QuestionListLoading>(),
          isA<QuestionListLoaded>(),
        ]),
      );
      final state = bloc.state as QuestionListLoaded;
      expect(state.questions, isEmpty);
    });

    test("with data returns QuestionListLoaded with questions", () async {
      mockRepo.mockQuestions = [
        createMockQuestion(id: "q001"),
        createMockQuestion(id: "q002"),
      ];
      bloc.add(const LoadQuestions(refresh: true));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<QuestionListLoading>(),
          isA<QuestionListLoaded>(),
        ]),
      );
      final state = bloc.state as QuestionListLoaded;
      expect(state.questions.length, 2);
    });

    test("no refresh skips Loading state", () async {
      mockRepo.mockQuestions = [createMockQuestion()];
      bloc.add(const LoadQuestions());
      await expectLater(
        bloc.stream,
        emits(isA<QuestionListLoaded>()),
      );
    });
  });

  group("SearchQuestions", () {
    test("search returns filtered results", () async {
      mockRepo.mockQuestions = [
        createMockQuestion(id: "q001"),
        createMockQuestion(id: "q002"),
      ];
      bloc.add(const SearchQuestions("Calculate"));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<QuestionListLoading>(),
          isA<QuestionListLoaded>(),
        ]),
      );
    });
  });

  group("AddQuestion", () {
    test("add success emits QuestionAdded", () async {
      bloc.add(const AddQuestion(
        imageUrl: "https://example.com/new.jpg",
        errorCategory: ErrorCategory.skill,
        knowledgePoints: [
          KnowledgePoint(id: "kp1", name: "Multiplication", subject: "Math"),
        ],
      ));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<QuestionAdding>(),
          isA<QuestionAdded>(),
        ]),
      );
      final state = bloc.state as QuestionAdded;
      expect(state.question.errorCategory, ErrorCategory.skill);
    });
  });

  group("DeleteQuestion", () {
    test("delete triggers reload", () async {
      mockRepo.mockQuestions = [createMockQuestion(id: "q001")];
      bloc.add(const DeleteQuestion("q001"));
      await Future.delayed(const Duration(milliseconds: 200));
      expect(bloc.state, isA<QuestionListLoaded>());
    });
  });

  group("LoadQuestionDetail", () {
    test("found emits QuestionDetailLoaded", () async {
      mockRepo.mockQuestions = [createMockQuestion(id: "q001")];
      bloc.add(const LoadQuestionDetail("q001"));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<QuestionDetailLoading>(),
          isA<QuestionDetailLoaded>(),
        ]),
      );
    });

    test("not found emits QuestionError", () async {
      bloc.add(const LoadQuestionDetail("nonexistent"));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<QuestionDetailLoading>(),
          isA<QuestionError>(),
        ]),
      );
    });
  });

  group("OcrImage", () {
    test("OCR success emits OcrCompleted", () async {
      bloc.add(const OcrImage("/path/to/image.jpg"));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<OcrProcessing>(),
          isA<OcrCompleted>(),
        ]),
      );
      final state = bloc.state as OcrCompleted;
      expect(state.text, "OCR text result");
    });
  });

  group("FilterByStatus", () {
    test("filter by status triggers LoadQuestions", () async {
      mockRepo.mockQuestions = [
        createMockQuestion(id: "q001", status: QuestionStatus.reviewing),
        createMockQuestion(id: "q002", status: QuestionStatus.notStarted),
      ];
      bloc.add(const FilterByStatus(QuestionStatus.reviewing));
      await Future.delayed(const Duration(milliseconds: 200));
      expect(bloc.state, isA<QuestionListLoaded>());
      final state = bloc.state as QuestionListLoaded;
      expect(
        state.questions.every((q) => q.status == QuestionStatus.reviewing),
        isTrue,
      );
    });
  });

  group("FilterByCategory", () {
    test("filter by category triggers LoadQuestions", () async {
      mockRepo.mockQuestions = [
        createMockQuestion(id: "q001", category: ErrorCategory.knowledge),
        createMockQuestion(id: "q002", category: ErrorCategory.skill),
      ];
      bloc.add(const FilterByCategory(ErrorCategory.skill));
      await Future.delayed(const Duration(milliseconds: 200));
      expect(bloc.state, isA<QuestionListLoaded>());
    });
  });

  group("QuestionModel", () {
    test("reviewProgress calculates correctly", () {
      final q = createMockQuestion().copyWith(
        currentReviewRound: 3,
        totalReviewRounds: 5,
      );
      expect(q.reviewProgress, closeTo(0.6, 0.01));
    });

    test("isEliminated returns true for mastered", () {
      final q = createMockQuestion().copyWith(status: QuestionStatus.mastered);
      expect(q.isEliminated, isTrue);
    });

    test("isEliminated returns false for notStarted", () {
      final q = createMockQuestion().copyWith(status: QuestionStatus.notStarted);
      expect(q.isEliminated, isFalse);
    });

    test("toJson/fromJson roundtrip", () {
      final original = createMockQuestion();
      final json = original.toJson();
      final restored = QuestionModel.fromJson(json);
      expect(restored.id, original.id);
      // imageUrl 经 fromJson 会归一化 host（设计如此），roundtrip 后为归一化结果
      expect(restored.imageUrl, normalizeImageUrl(original.imageUrl));
      expect(restored.errorCategory, original.errorCategory);
      expect(restored.status, original.status);
    });

    test("ErrorCategory.fromCode valid codes", () {
      expect(ErrorCategory.fromCode("KNOWLEDGE"), ErrorCategory.knowledge);
      expect(ErrorCategory.fromCode("SKILL"), ErrorCategory.skill);
      expect(ErrorCategory.fromCode("PSYCHOLOGY"), ErrorCategory.psychology);
      expect(ErrorCategory.fromCode("HABIT"), ErrorCategory.habit);
    });

    test("ErrorCategory.fromCode invalid returns unknown", () {
      expect(ErrorCategory.fromCode("INVALID"), ErrorCategory.unknown);
    });

    test("QuestionStatus.fromCode valid codes", () {
      expect(QuestionStatus.fromCode("NOT_STARTED"), QuestionStatus.notStarted);
      expect(QuestionStatus.fromCode("REVIEWING"), QuestionStatus.reviewing);
      expect(QuestionStatus.fromCode("MASTERED"), QuestionStatus.mastered);
    });

    test("QuestionStatus.fromCode invalid returns notStarted", () {
      expect(QuestionStatus.fromCode("INVALID"), QuestionStatus.notStarted);
    });
  });
}
