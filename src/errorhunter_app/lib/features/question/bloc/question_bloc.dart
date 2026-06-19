/// 错题猎手 - Question BLoC
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/question_model.dart';
import '../models/knowledge_point_model.dart';
import 'question_event.dart';
import 'question_state.dart';

/// 错题管理 BLoC
class QuestionBloc extends Bloc<QuestionEvent, QuestionState> {
  QuestionBloc() : super(const QuestionListInitial()) {
    on<LoadQuestions>(_onLoadQuestions);
    on<SearchQuestions>(_onSearchQuestions);
    on<FilterByStatus>(_onFilterByStatus);
    on<FilterByCategory>(_onFilterByCategory);
    on<FilterByKnowledgePoint>(_onFilterByKnowledgePoint);
    on<LoadQuestionDetail>(_onLoadQuestionDetail);
    on<AddQuestion>(_onAddQuestion);
    on<UpdateQuestion>(_onUpdateQuestion);
    on<DeleteQuestion>(_onDeleteQuestion);
    on<OcrImage>(_onOcrImage);
  }

  // ─── Mock Data Generator ──────────────────────────────────

  List<QuestionModel> _generateMockQuestions() {
    return [
      QuestionModel(
        id: 'q001',
        imageUrl: '',
        ocrText: '计算：25 × 4 + 36 ÷ 9 = ?',
        myAnswer: '104',
        correctAnswer: '104',
        errorCategory: ErrorCategory.skill,
        subCategories: ['运算顺序错误'],
        status: QuestionStatus.reviewing,
        knowledgePoints: [
          const KnowledgePoint(
            id: 'kp01',
            name: '四则运算',
            subject: '数学',
            isRecommended: true,
          ),
        ],
        customTags: ['计算题'],
        currentReviewRound: 2,
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        subject: '数学',
        solutionSteps: const [
          SolutionStep(stepNumber: 1, content: '先算乘法：25 × 4 = 100'),
          SolutionStep(stepNumber: 2, content: '再算除法：36 ÷ 9 = 4'),
          SolutionStep(
            stepNumber: 3,
            content: '最后加法：100 + 4 = 104',
            isErrorStep: false,
          ),
        ],
        reviewHistory: [
          ReviewRecord(
            id: 'r001',
            reviewRound: 1,
            reviewDate: DateTime.now().subtract(const Duration(days: 2)),
            result: 'WRONG',
          ),
          ReviewRecord(
            id: 'r002',
            reviewRound: 2,
            reviewDate: DateTime.now().subtract(const Duration(days: 1)),
            result: 'CORRECT',
          ),
        ],
      ),
      QuestionModel(
        id: 'q002',
        imageUrl: '',
        ocrText: '一个长方形的长是8cm，宽是5cm，求周长和面积。',
        myAnswer: '周长=26cm',
        correctAnswer: '周长=26cm，面积=40cm²',
        errorCategory: ErrorCategory.psychology,
        subCategories: ['漏做题'],
        status: QuestionStatus.notStarted,
        knowledgePoints: [
          const KnowledgePoint(
            id: 'kp02',
            name: '长方形周长与面积',
            subject: '数学',
            isRecommended: true,
          ),
        ],
        currentReviewRound: 0,
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        subject: '数学',
      ),
      QuestionModel(
        id: 'q003',
        imageUrl: '',
        ocrText: '把下列分数化成最简分数：12/18',
        correctAnswer: '2/3',
        errorCategory: ErrorCategory.knowledge,
        subCategories: ['最大公约数'],
        status: QuestionStatus.mastered,
        knowledgePoints: [
          const KnowledgePoint(
            id: 'kp03',
            name: '分数化简',
            subject: '数学',
          ),
        ],
        currentReviewRound: 5,
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        subject: '数学',
      ),
      QuestionModel(
        id: 'q004',
        imageUrl: '',
        ocrText: '小明有36颗糖，分给4个小朋友，每人分到几颗？还剩几颗？',
        myAnswer: '每人9颗',
        correctAnswer: '每人9颗，剩0颗',
        errorCategory: ErrorCategory.habit,
        subCategories: ['审题不清'],
        status: QuestionStatus.reviewing,
        knowledgePoints: [
          const KnowledgePoint(
            id: 'kp04',
            name: '有余数的除法',
            subject: '数学',
            isRecommended: true,
          ),
        ],
        customTags: ['应用题'],
        currentReviewRound: 3,
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        subject: '数学',
      ),
      QuestionModel(
        id: 'q005',
        imageUrl: '',
        ocrText: '选出下列句子中没有语病的一项',
        errorCategory: ErrorCategory.knowledge,
        status: QuestionStatus.notStarted,
        knowledgePoints: [
          const KnowledgePoint(
            id: 'kp05',
            name: '病句辨析',
            subject: '语文',
          ),
        ],
        currentReviewRound: 0,
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        subject: '语文',
      ),
    ];
  }

  // ─── Event Handlers ───────────────────────────────────────

  Future<void> _onLoadQuestions(
    LoadQuestions event,
    Emitter<QuestionState> emit,
  ) async {
    if (event.refresh) {
      emit(const QuestionListLoading());
    }

    // TODO: 调用 API 获取错题列表
    await Future.delayed(const Duration(milliseconds: 800));

    var questions = _generateMockQuestions();

    // Apply filters
    if (event.status != null) {
      questions =
          questions.where((q) => q.status == event.status).toList();
    }
    if (event.category != null) {
      questions = questions
          .where((q) => q.errorCategory == event.category)
          .toList();
    }

    emit(QuestionListLoaded(
      questions: questions,
      hasMore: event.page < 3,
      currentPage: event.page,
      filterStatus: event.status,
      filterCategory: event.category,
    ));
  }

  Future<void> _onSearchQuestions(
    SearchQuestions event,
    Emitter<QuestionState> emit,
  ) async {
    emit(const QuestionListLoading());

    // TODO: 调用搜索 API
    await Future.delayed(const Duration(milliseconds: 500));

    final allQuestions = _generateMockQuestions();
    final filtered = event.keyword.isEmpty
        ? allQuestions
        : allQuestions
            .where((q) =>
                (q.ocrText?.contains(event.keyword) ?? false) ||
                q.subject.contains(event.keyword))
            .toList();

    emit(QuestionListLoaded(
      questions: filtered,
      hasMore: false,
      searchKeyword: event.keyword,
    ));
  }

  Future<void> _onFilterByStatus(
    FilterByStatus event,
    Emitter<QuestionState> emit,
  ) async {
    add(LoadQuestions(status: event.status, refresh: true));
  }

  Future<void> _onFilterByCategory(
    FilterByCategory event,
    Emitter<QuestionState> emit,
  ) async {
    add(LoadQuestions(category: event.category, refresh: true));
  }

  Future<void> _onFilterByKnowledgePoint(
    FilterByKnowledgePoint event,
    Emitter<QuestionState> emit,
  ) async {
    add(LoadQuestions(
      knowledgePointId: event.knowledgePointId,
      refresh: true,
    ));
  }

  Future<void> _onLoadQuestionDetail(
    LoadQuestionDetail event,
    Emitter<QuestionState> emit,
  ) async {
    emit(const QuestionDetailLoading());

    // TODO: 调用 API 获取详情
    await Future.delayed(const Duration(milliseconds: 600));

    final allQuestions = _generateMockQuestions();
    final question = allQuestions
        .where((q) => q.id == event.id)
        .firstOrNull;

    if (question != null) {
      emit(QuestionDetailLoaded(question));
    } else {
      emit(const QuestionError('未找到该错题'));
    }
  }

  Future<void> _onAddQuestion(
    AddQuestion event,
    Emitter<QuestionState> emit,
  ) async {
    emit(const QuestionAdding());

    // TODO: 调用 API 创建错题
    await Future.delayed(const Duration(milliseconds: 1000));

    final newQuestion = QuestionModel(
      id: 'q${DateTime.now().millisecondsSinceEpoch}',
      imageUrl: event.imageUrl,
      ocrText: event.ocrText,
      myAnswer: event.myAnswer,
      correctAnswer: event.correctAnswer,
      errorCategory: event.errorCategory,
      subCategories: event.subCategories,
      status: QuestionStatus.notStarted,
      knowledgePoints: event.knowledgePoints,
      customTags: event.customTags,
      currentReviewRound: 0,
      totalReviewRounds: 5,
      createdAt: DateTime.now(),
    );

    emit(QuestionAdded(newQuestion));
  }

  Future<void> _onUpdateQuestion(
    UpdateQuestion event,
    Emitter<QuestionState> emit,
  ) async {
    // TODO: 调用 API 更新错题
    await Future.delayed(const Duration(milliseconds: 500));

    // Return to detail loaded state with updated question
    emit(QuestionDetailLoaded(event.question));
  }

  Future<void> _onDeleteQuestion(
    DeleteQuestion event,
    Emitter<QuestionState> emit,
  ) async {
    // TODO: 调用 API 软删除错题
    await Future.delayed(const Duration(milliseconds: 500));

    // Reload list
    add(const LoadQuestions(refresh: true));
  }

  Future<void> _onOcrImage(
    OcrImage event,
    Emitter<QuestionState> emit,
  ) async {
    emit(const OcrProcessing());

    // TODO: 调用 OCR API
    await Future.delayed(const Duration(seconds: 2));

    // Simulate OCR result
    emit(const OcrCompleted(
      '计算：25 × 4 + 36 ÷ 9 = ?\n\n解题步骤：\n1. 先算乘法 25 × 4 = 100\n2. 再算除法 36 ÷ 9 = 4\n3. 最后算加法 100 + 4 = 104',
    ));
  }
}
