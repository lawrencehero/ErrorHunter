/// 错题猎手 - 主题管理器
/// 管理当前主题模式，支持切换和持久化
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_mode.dart';

/// 主题管理器
class ThemeManager extends ChangeNotifier {
  ThemeManager._();

  static ThemeManager? _instance;

  /// 获取单例
  static ThemeManager get instance {
    _instance ??= ThemeManager._();
    return _instance!;
  }

  static const _prefKey = 'app_theme_mode';

  AppThemeMode _currentMode = AppThemeMode.gamified;

  /// 当前主题模式
  AppThemeMode get currentMode => _currentMode;

  /// 当前主题扩展
  AppThemeExtension get extension {
    switch (_currentMode) {
      case AppThemeMode.gamified:
        return AppThemeExtension.gamified;
      case AppThemeMode.glassmorphism:
        return AppThemeExtension.glassmorphism;
    }
  }

  /// 初始化（从 SharedPreferences 恢复）
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _currentMode = AppThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => AppThemeMode.gamified,
      );
    }
    notifyListeners();
  }

  /// 切换主题
  Future<void> setMode(AppThemeMode mode) async {
    if (_currentMode == mode) return;
    _currentMode = mode;
    notifyListeners();

    // 持久化
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }

  /// 切换到下一个主题
  Future<void> toggleTheme() async {
    final nextIndex = (_currentMode.index + 1) % AppThemeMode.values.length;
    await setMode(AppThemeMode.values[nextIndex]);
  }
}

/// 便捷方法：从 BuildContext 获取当前主题扩展
extension ThemeExtensionContext on BuildContext {
  AppThemeExtension get themeExt {
    return Theme.of(this).extension<AppThemeExtension>() ?? AppThemeExtension.gamified;
  }

  /// 主题感知的文字颜色
  AppTextThemeColors get textColors {
    final ext = themeExt;
    if (ext.isDarkBackground) {
      return AppTextThemeColors(
        primary: Colors.white,
        secondary: Colors.white70,
        tertiary: Colors.white54,
      );
    }
    return AppTextThemeColors(
      primary: const Color(0xFF1A1A2E),
      secondary: const Color(0xFF6B7280),
      tertiary: const Color(0xFF9CA3AF),
    );
  }
}

/// 主题感知的文字颜色集合
class AppTextThemeColors {
  const AppTextThemeColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  /// 主要文字 — 标题、正文
  final Color primary;

  /// 次要文字 — 辅助说明、时间戳
  final Color secondary;

  /// 三级文字 — 占位符、禁用态
  final Color tertiary;
}
