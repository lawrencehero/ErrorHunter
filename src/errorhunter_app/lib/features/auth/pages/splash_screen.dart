/// 错题猎手 - 启动页 (P1)
/// 品牌展示 + Token 检查 → 自动跳转
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Logo 淡入 + 缩放动画
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();

    // 触发 Auth 检查
    context.read<AuthBloc>().add(const CheckAuthStatus());

    // 1.5秒后根据状态跳转
    Timer(const Duration(milliseconds: 1500), _navigateAfterDelay);
  }

  void _navigateAfterDelay() {
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final hasOnboarded = context.read<AuthBloc>().hasOnboarded;

    if (authState is Authenticated) {
      // 已登录 → 首页
      context.go(Routes.home);
    } else if (hasOnboarded) {
      // 已完成引导但未登录 → 登录页
      context.go(Routes.login);
    } else {
      // 首次使用 → 引导页
      context.go(Routes.onboarding);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandPrimary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo 图标
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 52,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                // 中文名称
                Text(
                  '错题猎手',
                  style: AppTypography.primary.h1.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                // 英文名称
                Text(
                  'ErrorHunter',
                  style: AppTypography.primary.body.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: AppSpacing.xxxl),
                // Slogan
                Text(
                  '消灭错题，成为学霸猎手',
                  style: AppTypography.primary.caption.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
