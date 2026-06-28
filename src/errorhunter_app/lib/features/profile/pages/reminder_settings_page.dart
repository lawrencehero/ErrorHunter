/// 错题猎手 - 复习提醒设置页
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/colors.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../../../widgets/common/divider.dart';

/// 每日复习上限选项
const _reviewLimits = [10, 15, 20, 25, 30];

/// 复习提醒设置页
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);
  int _dailyLimit = 15;
  bool _eliminateAnimationEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = prefs.getBool('reminder_enabled') ?? true;
      final hour = prefs.getInt('reminder_hour') ?? 19;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _dailyLimit = prefs.getInt('daily_limit') ?? 15;
      _eliminateAnimationEnabled = prefs.getBool('eliminate_animation') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', _reminderEnabled);
    await prefs.setInt('reminder_hour', _reminderTime.hour);
    await prefs.setInt('reminder_minute', _reminderTime.minute);
    await prefs.setInt('daily_limit', _dailyLimit);
    await prefs.setBool('eliminate_animation', _eliminateAnimationEnabled);
    if (!mounted) return;
    setState(() => _isSaving = false);
    EHToast.show(context, message: '设置已保存', type: EHToastType.success);
    context.pop();
  }

  // 可选时间段：18:00-22:00，半小时步长
  List<TimeOfDay> get _availableTimes {
    final times = <TimeOfDay>[];
    for (int h = 18; h <= 22; h++) {
      times.add(TimeOfDay(hour: h, minute: 0));
      if (h < 22) {
        times.add(TimeOfDay(hour: h, minute: 30));
      }
    }
    return times;
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    // 玻璃拟态主题：背景为深色渐变，蓝色 brandPrimary 在其上对比度不足，
    // 改用暖琥珀色作为强调色（与 question_list_page.dart / profile_page.dart 保持一致）。
    final isGlass = context.themeExt.headerStyle == HeaderStyle.transparent;
    final accentColor = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    // 次要强调色（消灭动画开关用），玻璃下用更亮的橙红保证对比。
    final accentColor2 =
        isGlass ? const Color(0xFFFFAB91) : AppColors.brandSecondary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '复习提醒设置',
          style: AppTypography.primary.h3.copyWith(
            color: tc.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.base,
          bottom: AppSpacing.xxxl,
        ),
        child: Column(
          children: [
            // ─── 复习提醒开关 ──────────────────────────
            EHBaseCard(
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 24, color: accentColor),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '复习提醒',
                          style: AppTypography.primary.body.copyWith(
                            color: tc.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '开启后将在设定时间推送复习提醒',
                          style: AppTypography.primary.caption.copyWith(
                            color: tc.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _reminderEnabled,
                    activeColor: accentColor,
                    onChanged: (v) async {
                      setState(() => _reminderEnabled = v);
                      if (v) {
                        // 主动请求通知权限
                        final plugin = FlutterLocalNotificationsPlugin();
                        try {
                          // Android 13+ 请求通知权限
                          final androidImpl = plugin.resolvePlatformSpecificImplementation<
                              AndroidFlutterLocalNotificationsPlugin>();
                          if (androidImpl != null) {
                            await androidImpl.requestNotificationsPermission();
                          }
                          // iOS 请求通知权限
                          final iosImpl = plugin.resolvePlatformSpecificImplementation<
                              IOSFlutterLocalNotificationsPlugin>();
                          if (iosImpl != null) {
                            await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
                          }
                        } catch (_) {
                          // 权限请求失败不阻断流程
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('请确保已在系统设置中开启通知权限，否则将无法收到复习提醒'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // ─── 提醒时间选择器 ────────────────────────
            AnimatedOpacity(
              opacity: _reminderEnabled ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_reminderEnabled,
                child: EHBaseCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 22, color: accentColor),
                          SizedBox(width: AppSpacing.md),
                          Text(
                            '提醒时间',
                            style: AppTypography.primary.body.copyWith(
                              color: tc.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(isGlass ? 0.22 : 0.1),
                              borderRadius: AppRadius.radiusMd,
                            ),
                            child: Text(
                              '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                              style: AppTypography.primary.h3.copyWith(
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _availableTimes.map((t) {
                          final isSelected = t.hour == _reminderTime.hour &&
                              t.minute == _reminderTime.minute;
                          return GestureDetector(
                            onTap: () => setState(() => _reminderTime = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor
                                    : (isGlass
                                        ? Colors.white.withOpacity(0.12)
                                        : AppColors.background),
                                borderRadius: AppRadius.radiusMd,
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : (isGlass
                                          ? Colors.white.withOpacity(0.25)
                                          : AppColors.border),
                                ),
                              ),
                              child: Text(
                                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                style: AppTypography.primary.caption.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : tc.secondary,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // ─── 每日复习上限 ──────────────────────────
            EHBaseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered_rounded,
                          size: 22, color: accentColor),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        '每日复习上限',
                        style: AppTypography.primary.body.copyWith(
                          color: tc.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  ..._reviewLimits.map((limit) {
                    final isSelected = _dailyLimit == limit;
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.xs),
                      child: GestureDetector(
                        onTap: () => setState(() => _dailyLimit = limit),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withOpacity(isGlass ? 0.2 : 0.08)
                                : Colors.transparent,
                            borderRadius: AppRadius.radiusMd,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 20,
                                color: isSelected
                                    ? accentColor
                                    : tc.tertiary,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                '$limit道',
                                style: AppTypography.primary.body.copyWith(
                                  color: isSelected
                                      ? accentColor
                                      : tc.primary,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // ─── 消灭动画开关 ──────────────────────────
            EHBaseCard(
              child: Row(
                children: [
                  Icon(Icons.animation_rounded,
                      size: 24, color: accentColor2),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '消灭动画',
                          style: AppTypography.primary.body.copyWith(
                            color: tc.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '消灭错题时播放庆祝动画',
                          style: AppTypography.primary.caption.copyWith(
                            color: tc.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _eliminateAnimationEnabled,
                    activeColor: accentColor2,
                    onChanged: (v) =>
                        setState(() => _eliminateAnimationEnabled = v),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            // ─── 免打扰提示 ────────────────────────────
            // 玻璃拟态：brandPrimary 蓝在深色渐变上偏暗，沿用 accentColor 暖琥珀。
            Container(
              width: double.infinity,
              padding: AppSpacing.cardInnerPadding,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(isGlass ? 0.18 : 0.06),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: accentColor),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '💡 免打扰时段（22:00-07:00）内不会发送提醒通知',
                      style: AppTypography.primary.caption.copyWith(
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            // ─── 保存按钮 ──────────────────────────────
            EHPrimaryButton(
              text: '保存设置',
              onPressed: _isSaving ? null : _saveSettings,
              size: EHButtonSize.lg,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
