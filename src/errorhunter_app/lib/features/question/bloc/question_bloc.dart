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
    if (event.refresh) {
      emit(const QuestionListLoading());
    }

    final questions = await _questionRepository.getQuestions(
      category: event.category,
      status: event.status,
      knowledgePointId: event.knowledgePointId,
      page: event.page,
    );

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

    final result = await _questionRepository.ocrImage(event.imagePath);
    emit(OcrCompleted(result));
  }
}
