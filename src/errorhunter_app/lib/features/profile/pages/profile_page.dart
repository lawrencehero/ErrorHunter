/// 错题猎手 - P11 个人中心页 V2.0
/// 渐变顶栏头像区 + elevation 菜单卡片 + 圆形图标底色
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/gradients.dart';
import '../../../theme/radius.dart';
import '../../../theme/shadows.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/app_theme_mode.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/dialogs/confirm_dialog.dart';

/// 个人中心页 V2.0
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    // TODO: 替换为真实用户数据
    const mockNickname = '小明同学';
    const mockGrade = '五年级';
    const mockEliminatedCount = 128;
    const mockTotalCount = 156;
    const mockStreakDays = 12;
    const appVersion = 'v1.0.0';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: AppSpacing.xxxl),
        child: Column(
          children: [
            // ─── 渐变顶栏 + 头像区 ────────────────────────
            _buildHeroSection(
              nickname: mockNickname,
              grade: mockGrade,
              eliminatedCount: mockEliminatedCount,
              totalCount: mockTotalCount,
              streakDays: mockStreakDays,
            ),

            SizedBox(height: AppSpacing.lg),

            // ─── 设置项列表 ──────────────────────────────
            Padding(
              padding: AppSpacing.pagePadding,
              child: _buildSettingsCard(
                items: [
                  _SettingItemData(
                    icon: Icons.person_outline_rounded,
                    label: '个人信息',
                    color: AppColors.brandPrimary,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('个人信息编辑即将上线')),
                    ),
                  ),
                  _SettingItemData(
                    icon: Icons.notifications_outlined,
                    label: '复习提醒',
                    color: AppColors.warning,
                    onTap: () => context.push(Routes.settingsReminder),
                  ),
                  _SettingItemData(
                    icon: Icons.palette_outlined,
                    label: '切换主题',
                    color: const Color(0xFF6C5CE7),
                    onTap: () => context.push(Routes.settingsTheme),
                  ),
                  _SettingItemData(
                    icon: Icons.storage_outlined,
                    label: '存储管理',
                    color: AppColors.errorSkill,
                    onTap: () => context.push(Routes.settingsStorage),
                  ),
                  _SettingItemData(
                    icon: Icons.bar_chart_outlined,
                    label: '学情周报',
                    color: AppColors.success,
                    onTap: () => context.push(Routes.weeklyReports),
                  ),
                  _SettingItemData(
                    icon: Icons.delete_outline_rounded,
                    label: '回收站',
                    color: tc.secondary,
                    onTap: () => context.push(Routes.recycleBin),
                  ),
                  _SettingItemData(
                    icon: Icons.picture_as_pdf_outlined,
                    label: '导出错题集',
                    color: AppColors.errorKnowledge,
                    onTap: () => context.push(Routes.pdfExport),
                  ),
                  _SettingItemData(
                    icon: Icons.help_outline_rounded,
                    label: '帮助与反馈',
                    color: AppColors.brandSecondary,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('帮助中心即将上线，如有问题请联系客服')),
                    ),
                  ),
                  _SettingItemData(
                    icon: Icons.info_outline_rounded,
                    label: '关于我们',
                    color: tc.secondary,
                    showDivider: false,
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: '错题猎手',
                      applicationVersion: appVersion,
                      children: [
                        const Text('采集 → 归因 → 复习 → 消灭\n错题全生命周期管理'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.base),

            // ─── 危险操作区 ──────────────────────────────
            Padding(
              padding: AppSpacing.pagePadding,
              child: _buildSettingsCard(
                items: [
                  _SettingItemData(
                    icon: Icons.person_remove_outlined,
                    label: '注销账号',
                    color: AppColors.danger,
                    isDestructive: true,
                    onTap: () => context.push(Routes.deactivate),
                  ),
                  _SettingItemData(
                    icon: Icons.logout_rounded,
                    label: '退出登录',
                    color: AppColors.danger,
                    isDestructive: true,
                    showDivider: false,
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            // ─── 版本号 ──────────────────────────────────
            Center(
              child: Text(
                appVersion,
                style: AppTypography.primary.caption.copyWith(
                  color: tc.tertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 渐变英雄区 ─────────────────────────────────────────

  Widget _buildHeroSection({
    required String nickname,
    required String grade,
    required int eliminatedCount,
    required int totalCount,
    required int streakDays,
  }) {
    final rate = totalCount > 0 ? (eliminatedCount / totalCount * 100).toStringAsFixed(0) : '0';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.xxl,
        AppSpacing.base,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
      ),
      child: Column(
        children: [
          // 头像 + 名称
          Row(
            children: [
              // 头像
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Center(
                  child: Text(
                    nickname.isNotEmpty ? nickname.substring(0, 1) : '?',
                    style: AppTypography.primary.h1.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // 名称 + 年级
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: AppTypography.primary.h2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.radiusFull,
                      ),
                      child: Text(
                        grade,
                        style: AppTypography.primary.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 编辑按钮
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          // 统计行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeroStat(
                value: '$eliminatedCount',
                label: '已消灭',
              ),
              _buildHeroDivider(),
              _buildHeroStat(
                value: '$rate%',
                label: '消灭率',
              ),
              _buildHeroDivider(),
              _buildHeroStat(
                value: '$streakDays',
                label: '连续打卡',
                suffix: '🔥',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String value,
    required String label,
    String? suffix,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.primary.number.copyWith(
                color: Colors.white,
                fontSize: 28,
              ),
            ),
            if (suffix != null) ...[
              SizedBox(width: 2),
              Text(
                suffix,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.primary.caption.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.2),
    );
  }

  // ─── 设置卡片 ─────────────────────────────────────────

  Widget _buildSettingsCard({required List<_SettingItemData> items}) {
    return Builder(
      builder: (context) {
        final ext = context.themeExt;
        final isGlass = ext.headerStyle == HeaderStyle.transparent;
        return Container(
          decoration: BoxDecoration(
            color: isGlass ? Colors.white.withOpacity(0.12) : AppColors.surface,
            borderRadius: AppRadius.radiusLg,
            boxShadow: isGlass ? null : AppShadows.elevation1,
            border: isGlass
                ? Border.all(color: Colors.white.withOpacity(0.18), width: 1)
                : Border.all(color: AppColors.border.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildSettingItem(item, isLast: index == items.length - 1);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSettingItem(_SettingItemData item, {bool isLast = false}) {
    return Builder(
      builder: (context) {
        final tc = context.textColors;
        return Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(16))
                    : BorderRadius.zero,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, size: 18, color: item.color),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTypography.primary.body.copyWith(
                            color: item.isDestructive ? AppColors.danger : tc.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: tc.tertiary),
                    ],
                  ),
                ),
              ),
            ),
            if (!isLast && item.showDivider)
              Padding(
                padding: EdgeInsets.only(left: 64),
                child: Divider(height: 0.5, thickness: 0.5, color: tc.tertiary.withOpacity(0.2)),
              ),
          ],
        );
      },
    );
  }

  void _handleLogout(BuildContext context) {
    EHConfirmDialog.show(
      context,
      title: '确认退出登录？',
      content: '退出后需要重新登录才能使用',
      confirmText: '退出',
      cancelText: '取消',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.go(Routes.login);
      }
    });
  }
}

/// 设置项数据
class _SettingItemData {
  const _SettingItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDivider;
}
