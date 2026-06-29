/// 回归测试：WeeklyReportModel.fromDetailJson 与后端 /reports/weekly/:id 字段对齐。
/// 覆盖本次修复：
/// 1. week_start/week_end 带 UTC 时区，解析后 toLocal，日期不错位。
/// 2. top_error_category 可空：本周无新增错题时不返回 → null。
/// 3. prev_week_new/prev_week_mastered 可空：首周不返回 → delta 0。
/// 4. weak_knowledge_top JSONB 解析为 KnowledgeRankItem（含 rank）。
import 'package:errorhunter_app/features/report/models/weekly_report_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeeklyReportModel.fromDetailJson', () {
    test('完整详情解析', () {
      final data = {
        'id': 42,
        'week_number': 202626,
        'week_start': '2026-06-21T16:00:00Z', // 上海 06-22 00:00
        'week_end': '2026-06-27T16:00:00Z', // 上海 06-28 00:00
        'new_questions': 15,
        'mastered_questions': 12,
        'review_count': 42,
        'review_accuracy': 78.5,
        'prev_week_new': 12,
        'prev_week_mastered': 7,
        'prev_week_review_count': 50,
        'prev_week_accuracy': 70.0,
        'achievements': ['连续打卡达人', '消灭能手'],
        'top_error_category': 'KNOWLEDGE',
        'top_error_category_percentage': 42.5,
        'weak_knowledge_top': [
          {'id': 5, 'name': '分数运算', 'count': 8},
          {'id': 7, 'name': '几何面积', 'count': 5},
          {'id': 9, 'name': '小数乘法', 'count': 3},
        ],
      };

      final m = WeeklyReportModel.fromDetailJson(data, reportId: '42');

      // 周序：后端 6 位值保留在 summary.weekNumber，标题用 ISO 周序
      expect(m.summary.weekNumber, 202626);
      expect(m.summary.title, '第26周周报');

      // 日期：toLocal 后在东八区应为 06-22 / 06-28（不在 UTC 06-21 / 06-27）
      // 注：测试运行环境时区不确定，验证 startDate 与 UTC 输入的关系。
      // 输入 2026-06-21T16:00:00Z 在 UTC+8 为 2026-06-22 00:00。
      expect(m.summary.startDate.toUtc(), DateTime.utc(2026, 6, 21, 16, 0, 0));

      // 统计
      expect(m.summary.newCount, 15);
      expect(m.summary.eliminatedCount, 12);
      expect(m.summary.reviewCount, 42);
      expect(m.accuracyRate, 78.5);

      // delta：15-12=3, 12-7=5, 42-50=-8（复习次数 vs 上周）
      expect(m.newCountVsLastWeek, 3);
      expect(m.eliminatedCountVsLastWeek, 5);
      expect(m.reviewCountVsLastWeek, -8);
      // 正确率 delta：78.5 - 70.0 = 8.5
      expect(m.accuracyRateVsLastWeek, 8.5);

      // 成就：2 条文案映射为 AchievementItem
      expect(m.achievements.length, 2);
      expect(m.achievements[0].title, '连续打卡达人');
      expect(m.achievements[0].icon, '🔥');
      expect(m.achievements[0].description, isNotEmpty);
      expect(m.achievements[1].title, '消灭能手');
      expect(m.achievements[1].icon, '🎯');

      // 错因
      expect(m.mostFrequentErrorCategory, 'KNOWLEDGE');
      expect(m.mostFrequentErrorPercentage, 42.5);

      // 薄弱知识点 Top3 + rank
      expect(m.topKnowledgePoints.length, 3);
      expect(m.topKnowledgePoints[0].name, '分数运算');
      expect(m.topKnowledgePoints[0].errorCount, 8);
      expect(m.topKnowledgePoints[0].rank, 1);
      expect(m.topKnowledgePoints[2].rank, 3);
    });

    test('本周无新增错题：top_error_category 不返回 → null（不回退 UNKNOWN）', () {
      final data = {
        'id': 1,
        'week_number': 202626,
        'week_start': '2026-06-21T16:00:00Z',
        'week_end': '2026-06-27T16:00:00Z',
        'new_questions': 0,
        'mastered_questions': 0,
        'review_count': 0,
        'review_accuracy': 0.0,
        // top_error_category / top_error_category_percentage 被 omitempty 去掉
        // weak_knowledge_top 后端存 "[]"（空数组 JSONB）
        'weak_knowledge_top': [],
      };

      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');

      expect(m.mostFrequentErrorCategory, isNull);
      expect(m.mostFrequentErrorPercentage, 0.0);
      expect(m.topKnowledgePoints, isEmpty);
      // 详情页据此渲染「本周暂无新增错题」空态
    });

    test('首周无上周周报：prev_week_* 不返回 → delta 0', () {
      final data = {
        'id': 1,
        'week_number': 202601,
        'week_start': '2025-12-28T16:00:00Z',
        'week_end': '2026-01-03T16:00:00Z',
        'new_questions': 10,
        'mastered_questions': 5,
        'review_count': 20,
        'review_accuracy': 80.0,
        // prev_week_new / prev_week_mastered 被 omitempty 去掉
        'top_error_category': 'SKILL',
        'top_error_category_percentage': 60.0,
        'weak_knowledge_top': [],
      };

      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');

      // 无上周数据 → delta 0（UI 显示「持平 vs 上周」）
      expect(m.newCountVsLastWeek, 0);
      expect(m.eliminatedCountVsLastWeek, 0);

      // 跨年周序：2025-12-29 周一 → ISO 2026 第 1 周
      expect(m.summary.isoWeekNumber, 1);
      expect(m.summary.title, '第1周周报');
    });

    test('prev_week_* 为 0 时 delta 正确（上周也是 0）', () {
      final data = {
        'id': 1,
        'week_number': 202627,
        'week_start': '2026-06-28T16:00:00Z',
        'week_end': '2026-07-04T16:00:00Z',
        'new_questions': 5,
        'mastered_questions': 3,
        'review_count': 10,
        'review_accuracy': 50.0,
        'prev_week_new': 0,
        'prev_week_mastered': 0,
        'weak_knowledge_top': [],
      };

      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');
      // 注意：*int + omitempty，0 值会被去掉，所以实际拿不到 0；这里模拟
      // 后端若改为非 omitempty 返回 0 的情形，delta 应为 5-0=5。
      expect(m.newCountVsLastWeek, 5);
      expect(m.eliminatedCountVsLastWeek, 3);
    });

    test('review_accuracy 缺失时兜底 0.0', () {
      final data = {
        'id': 1,
        'week_number': 202626,
        'week_start': '2026-06-21T16:00:00Z',
        'week_end': '2026-06-27T16:00:00Z',
        'new_questions': 1,
        'mastered_questions': 0,
        'review_count': 0,
        'weak_knowledge_top': [],
      };
      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');
      expect(m.accuracyRate, 0.0);
    });

    test('首周：prev_week_review_count/prev_week_accuracy 不返回 → delta 0', () {
      // 后端 *int / *float64 + omitempty，首周无上周周报时不返回这两个 key。
      final data = {
        'id': 1,
        'week_number': 202601,
        'week_start': '2025-12-28T16:00:00Z',
        'week_end': '2026-01-03T16:00:00Z',
        'new_questions': 5,
        'mastered_questions': 2,
        'review_count': 10,
        'review_accuracy': 80.0,
        // prev_week_review_count / prev_week_accuracy 被 omitempty 去掉
        'weak_knowledge_top': [],
      };
      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');
      // 无上周数据 → delta 0（UI 显示「持平 vs 上周」）
      expect(m.reviewCountVsLastWeek, 0);
      expect(m.accuracyRateVsLastWeek, 0.0);
      // achievements 缺失 → 空列表（详情页显示「本周暂无成就」）
      expect(m.achievements, isEmpty);
    });

    test('prev_week_review_count=0 且 prev_week_accuracy=0：delta 取本周值', () {
      // 后端非 nil 即使 0 也会返回，delta = 本周 - 0 = 本周值。
      final data = {
        'id': 1,
        'week_number': 202627,
        'week_start': '2026-06-28T16:00:00Z',
        'week_end': '2026-07-04T16:00:00Z',
        'new_questions': 0,
        'mastered_questions': 0,
        'review_count': 10,
        'review_accuracy': 50.0,
        'prev_week_review_count': 0,
        'prev_week_accuracy': 0.0,
        'achievements': [],
        'weak_knowledge_top': [],
      };
      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');
      expect(m.reviewCountVsLastWeek, 10); // 10 - 0
      expect(m.accuracyRateVsLastWeek, 50.0); // 50 - 0
    });

    test('accuracyRateVsLastWeek 保留 2 位小数（负 delta）', () {
      final data = {
        'id': 1,
        'week_number': 202627,
        'week_start': '2026-06-28T16:00:00Z',
        'week_end': '2026-07-04T16:00:00Z',
        'new_questions': 0,
        'mastered_questions': 0,
        'review_count': 3,
        'review_accuracy': 33.33,
        'prev_week_accuracy': 66.66,
        'achievements': [],
        'weak_knowledge_top': [],
      };
      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');
      // 33.33 - 66.66 = -33.33（避免浮点尾巴如 -33.329999...）
      expect(m.accuracyRateVsLastWeek, -33.33);
    });

    test('achievements：每条字符串映射为 AchievementItem，icon 按文案选', () {
      final data = {
        'id': 1,
        'week_number': 202626,
        'week_start': '2026-06-21T16:00:00Z',
        'week_end': '2026-06-27T16:00:00Z',
        'new_questions': 6,
        'mastered_questions': 10,
        'review_count': 21,
        'review_accuracy': 80.0,
        'achievements': ['连续打卡达人', '消灭能手', '高正确率', '勤勉录入', '复习达人', '全勤王者', '未知成就'],
        'weak_knowledge_top': [],
      };
      final m = WeeklyReportModel.fromDetailJson(data, reportId: '1');
      expect(m.achievements.length, 7);
      // icon 按关键词选
      expect(m.achievements[0].icon, '🔥'); // 打卡
      expect(m.achievements[1].icon, '🎯'); // 消灭
      expect(m.achievements[2].icon, '⭐'); // 正确率
      expect(m.achievements[3].icon, '📝'); // 录入/勤勉
      expect(m.achievements[4].icon, '📚'); // 复习
      expect(m.achievements[5].icon, '🔥'); // 全勤（含"全勤"关键词）
      expect(m.achievements[6].icon, '✨'); // 未命中统一 ✨
      // 每条都有非空 description
      for (final a in m.achievements) {
        expect(a.description, isNotEmpty);
      }
    });

    test('achievements 非 List（如 null / 字符串）→ 空列表兜底', () {
      final base = {
        'id': 1,
        'week_number': 202626,
        'week_start': '2026-06-21T16:00:00Z',
        'week_end': '2026-06-27T16:00:00Z',
        'new_questions': 0,
        'mastered_questions': 0,
        'review_count': 0,
        'weak_knowledge_top': [],
      };
      // null
      var m = WeeklyReportModel.fromDetailJson(
        {...base, 'achievements': null},
        reportId: '1',
      );
      expect(m.achievements, isEmpty);
      // 字符串而非数组
      m = WeeklyReportModel.fromDetailJson(
        {...base, 'achievements': '连续打卡达人'},
        reportId: '1',
      );
      expect(m.achievements, isEmpty);
      // 数组中含非字符串元素：仅取 String 项
      m = WeeklyReportModel.fromDetailJson(
        {...base, 'achievements': <dynamic>['消灭能手', 123, null, '高正确率']},
        reportId: '1',
      );
      expect(m.achievements.length, 2);
      expect(m.achievements[0].title, '消灭能手');
      expect(m.achievements[1].title, '高正确率');
    });
  });
}
