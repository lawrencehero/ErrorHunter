/// 错题猎手 - Question Mock 数据源
/// 提供错题管理的模拟数据，后端就绪后替换为 RemoteDataSource
library;

import '../../features/question/models/question_model.dart';
import '../../features/question/models/knowledge_point_model.dart';

/// Question 模块的 Mock 数据源
class MockQuestionDataSource {
  /// 生成模拟错题列表
  List<QuestionModel> getQuestions() {
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

  /// 模拟 OCR 识别结果
  String getMockOcrResult() {
    return '计算：25 × 4 + 36 ÷ 9 = ?\n\n'
        '解题步骤：\n'
        '1. 先算乘法 25 × 4 = 100\n'
        '2. 再算除法 36 ÷ 9 = 4\n'
        '3. 最后算加法 100 + 4 = 104';
  }
}
