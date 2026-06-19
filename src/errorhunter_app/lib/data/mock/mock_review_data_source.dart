/// 错题猎手 - Review Mock 数据源
/// 提供复习流程的模拟数据，后端就绪后替换为 RemoteDataSource
library;

import '../../features/question/models/question_model.dart';

/// Review 模块的 Mock 数据源
class MockReviewDataSource {
  /// 生成复习队列的模拟题目
  List<QuestionModel> getReviewQueue() {
    return List.generate(8, (i) {
      final isRevive = i == 2 || i == 5; // 第3和第6题为复活检测
      return QuestionModel(
        id: 'mock_q_${i + 1}',
        imageUrl: '',
        ocrText: '题目 ${i + 1}：${_questionText(i)}',
        myAnswer: _myAnswer(i),
        correctAnswer: _correctAnswer(i),
        errorCategory: ErrorCategory.values[i % ErrorCategory.values.length],
        status: isRevive ? QuestionStatus.mastered : QuestionStatus.reviewing,
        knowledgePoints: [],
        solutionSteps: _solutionSteps(i),
        currentReviewRound: isRevive ? 3 : (i % 3 + 1),
        totalReviewRounds: 5,
        createdAt: DateTime.now().subtract(Duration(days: 30 - i)),
        subject: '数学',
      );
    });
  }

  /// 模拟连续打卡天数
  int getStreakDays() => 7;

  // ─── Private Helpers ──────────────────────────────────────

  static String _questionText(int index) {
    const texts = [
      '计算 24 × 15 的结果',
      '一个长方形的长是8cm，宽是5cm，求周长和面积',
      '解方程 3x + 7 = 22',
      '将分数 3/4 转换为小数和百分数',
      '一个圆的半径为3cm，求圆的面积（π取3.14）',
      '甲乙两地相距240km，汽车每小时行60km，几小时到达？',
      '化简比 12:18',
      '一块三角形菜地底边长20m，高15m，面积是多少？',
    ];
    return texts[index % texts.length];
  }

  static String _myAnswer(int index) {
    const answers = [
      '340',
      '周长=26cm 面积=40cm²',
      'x=4',
      '0.75 和 70%',
      '27.12cm²',
      '5小时',
      '2:3',
      '100m²',
    ];
    return answers[index % answers.length];
  }

  static String _correctAnswer(int index) {
    const answers = [
      '360',
      '周长=26cm 面积=40cm²',
      'x=5',
      '0.75 和 75%',
      '28.26cm²',
      '4小时',
      '2:3',
      '150m²',
    ];
    return answers[index % answers.length];
  }

  static List<SolutionStep> _solutionSteps(int index) {
    return [
      const SolutionStep(stepNumber: 1, content: '审题，明确已知条件和要求'),
      const SolutionStep(stepNumber: 2, content: '列出计算公式或方程'),
      SolutionStep(
        stepNumber: 3,
        content: '代入数据进行计算',
        isErrorStep: index % 2 == 0,
      ),
      const SolutionStep(stepNumber: 4, content: '检验结果是否合理'),
    ];
  }
}
