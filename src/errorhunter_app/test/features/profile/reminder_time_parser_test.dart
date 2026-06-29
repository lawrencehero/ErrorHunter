/// parseReminderTime 单元测试
///
/// 守护修复：复习提醒设置接后端 /users/me/settings 后，需要把后端返回的
/// review_reminder_time（"HH:mm" 或 "HH:mm:ss"）解析为 TimeOfDay。
/// 非法格式/越界必须返回 null，由调用方保留原值，避免把有效时间覆盖成错误值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/features/profile/pages/reminder_settings_page.dart';

void main() {
  group('parseReminderTime', () {
    test('标准 HH:mm 解析', () {
      expect(parseReminderTime('19:00'), const TimeOfDay(hour: 19, minute: 0));
      expect(parseReminderTime('08:30'), const TimeOfDay(hour: 8, minute: 30));
      expect(parseReminderTime('22:00'), const TimeOfDay(hour: 22, minute: 0));
    });

    test('HH:mm:ss（后端 TIME 类型带秒）解析，忽略秒', () {
      expect(parseReminderTime('19:00:00'), const TimeOfDay(hour: 19, minute: 0));
      expect(parseReminderTime('07:15:30'), const TimeOfDay(hour: 7, minute: 15));
    });

    test('边界时间 00:00 与 23:59 合法', () {
      expect(parseReminderTime('00:00'), const TimeOfDay(hour: 0, minute: 0));
      expect(parseReminderTime('23:59'), const TimeOfDay(hour: 23, minute: 59));
    });

    test('小时越界返回 null', () {
      expect(parseReminderTime('24:00'), isNull);
      expect(parseReminderTime('-1:00'), isNull);
    });

    test('分钟越界返回 null', () {
      expect(parseReminderTime('19:60'), isNull);
      expect(parseReminderTime('19:-1'), isNull);
    });

    test('非数字返回 null', () {
      expect(parseReminderTime('ab:cd'), isNull);
      expect(parseReminderTime('19:xy'), isNull);
    });

    test('格式不符（无冒号 / 空串 / 单段）返回 null', () {
      expect(parseReminderTime(''), isNull);
      expect(parseReminderTime('1900'), isNull);
      expect(parseReminderTime('19'), isNull);
    });

    test('仅 HH:mm:ss:ssss 超长也只取前两段，仍可解析', () {
      // 后端极少返回带毫秒，但解析器只看前两段，应稳健
      expect(parseReminderTime('19:00:00.000'), const TimeOfDay(hour: 19, minute: 0));
    });
  });
}
