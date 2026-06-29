/// 回归测试：DashboardData.fromJson 与后端 /reports 字段对齐。
/// 覆盖：greeting / today_task / statistics / weak_knowledge_top / weekly_completed。
/// 后端还返回 error_distribution / weekly_trend（前端暂未消费），确认多余字段不破坏解析。
import 'package:errorhunter_app/features/report/models/dashboard_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('完整 dashboard JSON 解析：所有字段对齐', () {
    final json = {
      'greeting': {'nickname': '小明', 'streak_days': 12},
      'today_task': {
        'pending_review_count': 8,
        'has_overflow': false,
        'overflow_count': 0,
      },
      'statistics': {
        'total_questions': 156,
        'mastered_count': 98,
        'elimination_rate': 62.8,
      },
      'error_distribution': [
        {'category': 'KNOWLEDGE', 'count': 20},
        {'category': 'SKILL', 'count': 10},
      ],
      'weekly_trend': [
        {'date': '2026-06-23', 'new_questions': 3, 'mastered_count': 1},
      ],
      'weak_knowledge_top': [
        {'id': 5, 'name': '分数运算', 'count': 8},
        {'id': 7, 'name': '几何面积', 'count': 5},
      ],
      'weekly_completed': [true, false, true, true, false, false, false],
    };

    final d = DashboardData.fromJson(json);

    expect(d.nickname, '小明');
    expect(d.streakDays, 12);
    expect(d.pendingReviewCount, 8);
    expect(d.totalQuestions, 156);
    expect(d.masteredCount, 98);
    expect(d.eliminationRate, 62.8);

    expect(d.weakKnowledge.length, 2);
    expect(d.weakKnowledge[0].id, '5'); // 后端 int → 前端 String
    expect(d.weakKnowledge[0].name, '分数运算');
    expect(d.weakKnowledge[0].count, 8);
    expect(d.weakKnowledge[1].name, '几何面积');

    expect(d.weeklyCompleted,
        [true, false, true, true, false, false, false]);
  });

  test('weekly_completed 全 false（本周未复习）', () {
    final json = {
      'greeting': {'nickname': '同学', 'streak_days': 0},
      'today_task': {'pending_review_count': 0},
      'statistics': {
        'total_questions': 0,
        'mastered_count': 0,
        'elimination_rate': 0.0,
      },
      'weekly_completed': [false, false, false, false, false, false, false],
    };
    final d = DashboardData.fromJson(json);
    expect(d.weeklyCompleted.every((e) => e == false), isTrue);
  });

  test('后端 omitempty 缺字段时安全兜底（新用户）', () {
    // 后端部分字段在零值时 omitempty 可能不返回，前端需兜底
    final json = <String, dynamic>{
      'greeting': {'streak_days': 0},
      'today_task': {},
      'statistics': {},
      'weekly_completed': [],
    };
    final d = DashboardData.fromJson(json);
    expect(d.nickname, '同学');
    expect(d.streakDays, 0);
    expect(d.pendingReviewCount, 0);
    expect(d.totalQuestions, 0);
    expect(d.masteredCount, 0);
    expect(d.eliminationRate, 0.0);
    expect(d.weakKnowledge, isEmpty);
    expect(d.weeklyCompleted, isEmpty);
  });

  test('empty() 工厂：新用户空数据', () {
    final d = DashboardData.empty();
    expect(d.nickname, '同学');
    expect(d.totalQuestions, 0);
    expect(d.weeklyCompleted, isEmpty);
  });

  test('weak_knowledge_top id 为字符串时也兼容', () {
    final json = {
      'greeting': {},
      'today_task': {},
      'statistics': {},
      'weak_knowledge_top': [
        {'id': 'abc', 'name': 'X', 'count': 1},
      ],
    };
    final d = DashboardData.fromJson(json);
    expect(d.weakKnowledge[0].id, 'abc');
  });
}
