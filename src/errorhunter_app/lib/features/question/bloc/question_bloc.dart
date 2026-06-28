/// 错题猎手 - Question BLoC
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/question_model.dart';
import '../../../domain/repositories/question_repository.dart';
import 'question_event.dart';
import 'question_state.dart';

/// 错题管理 BLoC
class QuestionBloc extends Bloc<QuestionEvent, QuestionState> {
  final QuestionRepository _questionRepository;

  QuestionBloc(this._questionRepository) : super(const QuestionListInitial()) {
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

  // ─── Event Handlers ───────────────────────────────────────

  Future<void> _onLoadQuestions(
    LoadQuestions event,
    Emitter<QuestionState> emit,
  ) async {
    // 仅在首次加载（尚未加载过）时显示骨架屏；tab/筛选切换时保留旧列表，
    // 避免滑动切换中闪现骨架屏
    if (event.refresh && state is! QuestionListLoaded) {
      emit(const QuestionListLoading());
    }

    try {
      final questions = await _questionRepository.getQuestions(
        category: event.category,
        status: event.status,
        knowledgePointId: event.knowledgePointId,
        page: event.page,
      );

      // 非刷新（加载更多）时追加到现有列表；刷新时替换
      final previous = (state is QuestionListLoaded && !event.refresh)
          ? (state as QuestionListLoaded).questions
          : const <QuestionModel>[];
      final all = event.refresh ? questions : [...previous, ...questions];

      // hasMore：本页满页（>= pageSize）才认为可能还有更多
      final hasMore = questions.length >= event.pageSize;

      emit(QuestionListLoaded(
        questions: all,
        hasMore: hasMore,
        currentPage: event.page,
        filterStatus: event.status,
        filterCategory: event.category,
        filterKnowledgePoint: event.knowledgePointId,
      ));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onSearchQuestions(
    SearchQuestions event,
    Emitter<QuestionState> emit,
  ) async {
    emit(const QuestionListLoading());

    final filtered = await _questionRepository.searchQuestions(event.keyword);

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

    final question = await _questionRepository.getQuestionDetail(event.id);

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

    try {
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

      final created = await _questionRepository.addQuestion(newQuestion);
      emit(QuestionAdded(created));
    } catch (e) {
      emit(QuestionAddFailed(e.toString()));
    }
  }

  Future<void> _onUpdateQuestion(
    UpdateQuestion event,
    Emitter<QuestionState> emit,
  ) async {
    try {
      await _questionRepository.updateQuestion(event.question);
      emit(QuestionDetailLoaded(event.question));
    } catch (e) {
      emit(QuestionUpdateFailed(event.question));
    }
  }

  Future<void> _onDeleteQuestion(
    DeleteQuestion event,
    Emitter<QuestionState> emit,
  ) async {
    await _questionRepository.deleteQuestion(event.id);
    add(const LoadQuestions(refresh: true));
  }

  Future<void> _onOcrImage(
    OcrImage event,
    Emitter<QuestionState> emit,
  ) async {
    emit(const OcrProcessing());

    try {
      final result = await _questionRepository.ocrImage(event.imagePath);
      if (result.text.isNotEmpty) {
        emit(OcrCompleted(
          text: result.text,
          imageUrl: result.imageUrl,
          figures: result.figures,
        ));
      } else {
        // OCR 返回空字符串视为识别失败（不阻塞用户保存，但提示重试）
        emit(const OcrFailed('未识别到文字内容，请检查图片清晰度后重试'));
      }
    } catch (e) {
      // 修复 Bug #3：捕获异常 emit OcrFailed，UI 才能进入失败状态而不是永远卡在 loading
      emit(OcrFailed(e.toString()));
    }
  }
}
