# 错题猎手 Flutter App

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── theme/                 # Design Tokens & 主题系统
│   ├── theme.dart         # 统一导出
│   ├── colors.dart        # 色彩系统
│   ├── typography.dart    # 字体系统
│   ├── spacing.dart       # 间距系统
│   ├── radius.dart        # 圆角系统
│   └── app_theme.dart     # ThemeData 配置
├── router/                # 路由配置
│   └── app_router.dart    # GoRouter 路由定义
└── di/                    # 依赖注入
    └── injection.dart     # GetIt 服务注册
```

## 快速开始

```bash
cd src/errorhunter_app
flutter pub get
flutter run
```

## 设计规范参考

- 界面与交互设计文档 V1.0 §1.3
- 技术设计文档 V1.0 §1.2
