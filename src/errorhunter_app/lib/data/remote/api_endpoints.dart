/// 错题猎手 - API 路径常量
/// 集中管理所有后端接口路径，避免硬编码
library;

/// API 端点常量
class ApiEndpoints {
  ApiEndpoints._();

  // ─── Auth ────────────────────────────────────────────────
  static const String auth = '/auth';
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // ─── Questions ───────────────────────────────────────────
  static const String questions = '/questions';
  static const String questionDetail = '/questions/{id}';
  static const String questionRestore = '/questions/{id}/restore';
  static const String questionPermanentDelete = '/questions/{id}/permanent';
  static const String recycleBin = '/questions/recycle-bin';
  static const String recycleBinClear = '/questions/recycle-bin/clear';

  // ─── Knowledge Points ───────────────────────────────────
  static const String knowledgePoints = '/knowledge-points';

  // ─── Reviews ─────────────────────────────────────────────
  static const String reviews = '/reviews';
  static const String reviewQueue = '/reviews/queue';
  static const String reviewResult = '/reviews/result';

  // ─── Reports ─────────────────────────────────────────────
  static const String reports = '/reports';
  static const String weeklyReports = '/reports/weekly';
  static const String weeklyReportDetail = '/reports/weekly/{id}';

  // ─── Upload ──────────────────────────────────────────────
  static const String upload = '/upload';
  static const String ocrRecognize = '/upload/ocr';

  // ─── Storage ─────────────────────────────────────────────
  /// 当前用户在 MinIO 的错题图片总用量
  static const String storage = '/storage';

  // ─── User ────────────────────────────────────────────────
  static const String user = '/users/me';
  static const String userSettings = '/users/me/settings';
  static const String deactivate = '/users/me/deactivate';

  // ─── Sync ────────────────────────────────────────────────
  static const String sync = '/sync';
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';

  /// 替换路径中的 {id} 占位符
  static String withId(String endpoint, String id) {
    return endpoint.replaceAll('{id}', id);
  }
}
