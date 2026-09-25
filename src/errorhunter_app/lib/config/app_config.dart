/// 错题猎手 - 全局应用配置
/// 控制 Mock 开关等运行时行为
library;

/// 全局应用配置
class AppConfig {
  AppConfig._();

  /// 是否使用 Mock 数据
  ///
  /// - `false`：使用真实 API（Impl Repository + Remote DataSource）
  /// - `true`：使用内置 Mock 数据（Mock Repository + Mock DataSource）
  ///
  /// 当前 V1.0 已切回真实 API 模式，使用真实后端接口。
  /// 修改后需重启 App 生效
  static const bool useMock = false;

  /// 后端 API 基础 URL（含 /v1 前缀）
  /// 默认指向本机后端；连接生产/远程环境时用 --dart-define=API_BASE_URL=... 覆盖，
  /// 例：flutter run --dart-define=API_BASE_URL=http://<your-server>:8080/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/v1',
  );

  /// API 请求超时时间（秒）
  static const int apiTimeoutSeconds = 15;

  /// OCR 请求超时时间（秒）
  static const int ocrTimeoutSeconds = 10;
}
