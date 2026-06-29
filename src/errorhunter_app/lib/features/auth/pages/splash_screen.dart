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

  /// 品牌最短展示时间是否已过
  bool _minDisplayElapsed = false;

  /// AuthBloc 是否已产出终态（Authenticated / Unauthenticated）
  bool _authResolved = false;

  /// 最大超时 Timer（5s），防止 AuthBloc 卡死导致白屏
  Timer? _maxTimeoutTimer;

  /// 最短品牌展示 Timer（800ms）
  Timer? _minDisplayTimer;

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

    // 最短品牌展示 800ms
    _minDisplayTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _minDisplayElapsed = true;
      _tryNavigate();
    });

    // 最大超时 5s，超时后跳转登录页
    _maxTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (!_authResolved) {
        context.go(Routes.login);
      }
    });
  }

  /// 当品牌展示时间已过 且 AuthBloc 已产出终态时执行跳转
  void _tryNavigate() {
    if (!_minDisplayElapsed || !_authResolved) return;
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final hasOnboarded = context.read<AuthBloc>().hasOnboarded;

    _maxTimeoutTimer?.cancel();

    if (authState is Authenticated) {
      context.go(Routes.home);
    } else if (hasOnboarded) {
      context.go(Routes.login);
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  void dispose() {
    _maxTimeoutTimer?.cancel();
    _minDisplayTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // 仅当状态变为终态时标记已解析并尝试跳转
        if (state is Authenticated || state is Unauthenticated) {
          _authResolved = true;
          _tryNavigate();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.brandPrimary,
        body: Stack(
          children: [
            Center(
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
                        '消灭错题，每天进步一点点',
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
            // 底部加载指示器
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
