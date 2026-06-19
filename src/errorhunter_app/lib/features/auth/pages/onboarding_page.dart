/// 错题猎手 - 引导页 (P1)
/// 3屏 PageView 滑动引导 + 跳过 + 分页指示器
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../bloc/auth_bloc.dart';

/// 引导页数据
class _OnboardingData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bgColor;

  const _OnboardingData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });
}

const _pages = [
  _OnboardingData(
    emoji: '📸',
    title: '拍一下，错题自动归档',
    subtitle: '告别手抄，3秒录入一道错题',
    bgColor: Color(0xFFEEF2FF),
  ),
  _OnboardingData(
    emoji: '🧠',
    title: '科学复习，记住不忘',
    subtitle: '艾宾浩斯曲线帮你安排复习',
    bgColor: Color(0xFFFFF4EB),
  ),
  _OnboardingData(
    emoji: '🎯',
    title: '消灭错题，看见进步',
    subtitle: '每消灭一道，离满分更近一步',
    bgColor: Color(0xFFEDFFF3),
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSkip() {
    _completeOnboarding();
  }

  void _onStart() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    context.read<AuthBloc>().markOnboarded();
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // PageView
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => _buildPage(_pages[index]),
            ),

            // 右上角跳过按钮（第3屏隐藏）
            if (_currentPage < 2)
              Positioned(
                top: AppSpacing.base,
                right: AppSpacing.base,
                child: GestureDetector(
                  onTap: _onSkip,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: AppRadius.radiusFull,
                    ),
                    child: Text(
                      '跳过',
                      style: AppTypography.primary.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            // 底部区域
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
              child: Column(
                children: [
                  // 前2屏：分页指示器
                  if (_currentPage < 2) ...[
                    _buildDots(),
                    SizedBox(height: AppSpacing.xxl),
                  ],
                  // 第3屏：开始使用按钮
                  if (_currentPage == 2) ...[
                    Padding(
                      padding: AppSpacing.pagePadding,
                      child: EHPrimaryButton(
                        text: '开始使用',
                        size: EHButtonSize.lg,
                        fullWidth: true,
                        onPressed: _onStart,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return Container(
      color: data.bgColor,
      padding: AppSpacing.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji 图标
          Text(
            data.emoji,
            style: const TextStyle(fontSize: 96),
          ),
          SizedBox(height: AppSpacing.xxxl),
          // 标题
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppTypography.primary.h1.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          // 副标题
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.primary.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandPrimary : AppColors.border,
            borderRadius: AppRadius.radiusFull,
          ),
        );
      }),
    );
  }
}
