/// 错题猎手（ErrorHunter）
/// 小学3-6年级及初中学生错题全生命周期管理工具
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'di/injection.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/question/bloc/question_bloc.dart';
import 'features/report/bloc/report_bloc.dart';
import 'features/review/bloc/review_bloc.dart';
import 'router/app_router.dart';
import 'theme/theme.dart';
import 'widgets/common/app_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();
  await ThemeManager.instance.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ErrorHunterApp());
}

class ErrorHunterApp extends StatelessWidget {
  const ErrorHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // AuthBloc 用 .value + singleton，与 app_router.dart 的 redirect 共享同一实例
        BlocProvider<AuthBloc>.value(value: sl<AuthBloc>()),
        BlocProvider<QuestionBloc>(create: (_) => sl<QuestionBloc>()),
        BlocProvider<ReviewBloc>(create: (_) => sl<ReviewBloc>()),
        BlocProvider<ReportBloc>(create: (_) => sl<ReportBloc>()),
      ],
      child: AnimatedBuilder(
        animation: ThemeManager.instance,
        builder: (context, _) {
          final mode = ThemeManager.instance.currentMode;
          final ext = ThemeManager.instance.extension;

          return MaterialApp.router(
            title: '错题猎手',
            debugShowCheckedModeBanner: false,
            theme: _buildThemedData(mode, ext),
            routerConfig: appRouter,
            // 全局背景包裹 —— 所有页面共享渐变/纯色背景
            builder: (context, child) {
              return AppBackground(
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  ThemeData _buildThemedData(AppThemeMode mode, AppThemeExtension ext) {
    final base = AppTheme.light;

    switch (mode) {
      case AppThemeMode.gamified:
        return base.copyWith(extensions: [ext]);

      case AppThemeMode.glassmorphism:
        return base.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          // 路由转场(MaterialPageRoute)首帧以 canvasColor 绘制，
          // 默认白色会在进入子页面瞬间闪白底；玻璃主题下置透明，
          // 让全局 AppBackground 渐变成为唯一背景。
          canvasColor: Colors.transparent,
          shadowColor: Colors.transparent,
          extensions: [ext],
          // 文字颜色：深色背景上用白色系
          textTheme: base.textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
            decorationColor: Colors.white,
          ),
          colorScheme: base.colorScheme.copyWith(
            onSurface: Colors.white,
            onSurfaceVariant: Colors.white70,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            outline: Colors.white24,
          ),
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
          ),
          iconTheme: base.iconTheme.copyWith(color: Colors.white70),
          dividerColor: Colors.white12,
          navigationBarTheme: base.navigationBarTheme.copyWith(
            backgroundColor: Colors.white.withOpacity(0.08),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          cardTheme: base.cardTheme.copyWith(
            color: Colors.white.withOpacity(0.12),
            elevation: 0,
          ),
        );
    }
  }
}
