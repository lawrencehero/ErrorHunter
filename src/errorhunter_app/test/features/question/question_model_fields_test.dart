/// 回归测试：QuestionModel.fromJson 解析后端返回的额外字段
///
/// 守护修复：
/// 1. solution_steps（后端 []string）转成 List<SolutionStep>，
///    error_step_index 标记错步骤。详情页"解题步骤"区块依赖此字段，
///    之前 fromJson 未解析导致永远空。
/// 2. deleted_at 解析：回收站页据此计算"剩余保留天数"。
/// 3. master_count 解析：复习模块据此判定消灭（>=3）。
library;

import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/features/question/models/question_model.dart";
import "package:errorhunter_app/features/question/bloc/question_state.dart";

Map<String, dynamic> _baseJson({
  List<String>? solutionSteps,
  int? errorStepIndex,
  String? deletedAt,
  int? masterCount,
  String? masteredAt,
  List<Map<String, dynamic>>? reviewRecords,
}) {
  final j = <String, dynamic>{
    "id": 42,
    "image_url": "http://api.example.com/v1/files/q/42.png",
    "error_category": "KNOWLEDGE",
    "status": "REVIEWING",
    "created_at": "2026-06-28T10:00:00+08:00",
  };
  if (solutionSteps != null) j["solution_steps"] = solutionSteps;
  if (errorStepIndex != null) j["error_step_index"] = errorStepIndex;
  if (deletedAt != null) j["deleted_at"] = deletedAt;
  if (masterCount != null) j["master_count"] = masterCount;
  if (masteredAt != null) j["mastered_at"] = masteredAt;
  if (reviewRecords != null) j["review_records"] = reviewRecords;
  return j;
}

void main() {
  group("solution_steps 解析", () {
    test("字符串数组转成 SolutionStep，stepNumber 从 1 起", () {
      final q = QuestionModel.fromJson(_baseJson(
        solutionSteps: ["先算乘法：25×4=100", "再算除法：36÷9=4", "相加得 104"],
      ));

      expect(q.solutionSteps, hasLength(3));
      expect(q.solutionSteps[0].stepNumber, 1);
      expect(q.solutionSteps[0].content, "先算乘法：25×4=100");
      expect(q.solutionSteps[2].stepNumber, 3);
    });

    test("error_step_index（0-based）标记对应错步骤", () {
      final q = QuestionModel.fromJson(_baseJson(
        solutionSteps: ["步骤1", "步骤2", "步骤3"],
        errorStepIndex: 1,
      ));

      expect(q.solutionSteps[0].isErrorStep, isFalse);
      expect(q.solutionSteps[1].isErrorStep, isTrue,
          reason: "error_step_index=1 应标记第 2 步为错步骤");
      expect(q.solutionSteps[2].isErrorStep, isFalse);
    });

    test("缺省 solution_steps 时为空列表", () {
      final q = QuestionModel.fromJson(_baseJson());
      expect(q.solutionSteps, isEmpty);
    });
  });

  group("deleted_at 解析", () {
    test("回收站列表返回的 deleted_at 被解析", () {
      final q = QuestionModel.fromJson(_baseJson(
        deletedAt: "2026-06-20T08:00:00+08:00",
      ));

      expect(q.deletedAt, isNotNull);
      expect(q.deletedAt!.day, 20);
    });

    test("常规列表无 deleted_at 时为 null", () {
      final q = QuestionModel.fromJson(_baseJson());
      expect(q.deletedAt, isNull);
    });
  });

  group("master_count 解析", () {
    test("后端返回的 master_count 被解析（用于复习消灭判定）", () {
      final q = QuestionModel.fromJson(_baseJson(masterCount: 3));
      expect(q.masterCount, 3);
    });

    test("缺省时为 0", () {
      final q = QuestionModel.fromJson(_baseJson());
      expect(q.masterCount, 0);
    });
  });

  group("QuestionDetailLoaded 状态重建", () {
    test("更新后 question 内容变化触发 Equatable 不相等（props 含完整 question）",
        () {
      final q1 = QuestionModel.fromJson(_baseJson());
      final q2 = q1.copyWith(ocrText: "改过的文本");
      // QuestionDetailLoaded 的 props 改为 [question]，
      // 内容不同的同 id 题应判不相等，否则 BlocBuilder 不会重建。
      final s1 = QuestionDetailLoaded(q1);
      final s2 = QuestionDetailLoaded(q2);
      expect(s1 == s2, isFalse,
          reason: "更新后内容变化但 id 不变时，状态应不相等以触发重建");
    });
  });

  // ===== #11 修复守护：review_records 解析 + SelfRating 枚举对齐 =====
  group("review_records 解析", () {
    test("详情接口返回 review_records → 解析为 reviewHistory（倒序保留）", () {
      final q = QuestionModel.fromJson(_baseJson(reviewRecords: [
        {
          "id": 10,
          "question_id": 42,
          "user_id": 1,
          "review_round": 2,
          "self_rating": "MASTERED",
          "master_count_after": 3,
          "reviewed_at": "2026-06-28T09:00:00+08:00",
        },
        {
          "id": 9,
          "question_id": 42,
          "user_id": 1,
          "review_round": 1,
          "self_rating": "FAILED",
          "master_count_after": 0,
          "reviewed_at": "2026-06-27T09:00:00+08:00",
          "review_duration_sec": 45,
        },
      ]));

      expect(q.reviewHistory, hasLength(2));
      // 后端按时间倒序返回，前端原样保留顺序（timeline 顺序展示）
      expect(q.reviewHistory[0].id, "10");
      expect(q.reviewHistory[0].reviewRound, 2);
      expect(q.reviewHistory[0].result, "MASTERED");
      expect(q.reviewHistory[1].result, "FAILED");
      expect(q.reviewHistory[1].reviewDurationSec, 45);
    });

    test("列表/复习队列不返回 review_records → 回退空复习历史", () {
      final q = QuestionModel.fromJson(_baseJson());
      expect(q.reviewHistory, isEmpty,
          reason: "非详情接口不返回 review_records，前端回退空");
    });

    test("缺省 self_rating 时回退 FAILED（防御非法值）", () {
      final q = QuestionModel.fromJson(_baseJson(reviewRecords: [
        {"id": 1, "review_round": 1, "reviewed_at": "2026-06-28T09:00:00+08:00"},
      ]));
      expect(q.reviewHistory.single.result, "FAILED");
    });
  });

  group("ReviewRecord result 枚举对齐后端 SelfRating", () {
    test("MASTERED / PARTIAL / FAILED 均可解析", () {
      for (final rating in ["MASTERED", "PARTIAL", "FAILED"]) {
        final q = QuestionModel.fromJson(_baseJson(reviewRecords: [
          {
            "id": 1,
            "review_round": 1,
            "self_rating": rating,
            "reviewed_at": "2026-06-28T09:00:00+08:00",
          },
        ]));
        expect(q.reviewHistory.single.result, rating,
            reason: "后端 SelfRating 三值都应原样保留");
      }
    });

    test("兼容旧 result 字段名（本地缓存残留）", () {
      final q = QuestionModel.fromJson(_baseJson(reviewRecords: [
        {
          "id": 1,
          "review_round": 1,
          "result": "CORRECT",
          "reviewed_at": "2026-06-28T09:00:00+08:00",
        },
      ]));
      // result 字段作为 self_rating 缺省时的 fallback
      expect(q.reviewHistory.single.result, "CORRECT");
    });
  });
}
