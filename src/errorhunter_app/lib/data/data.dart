/// 错题猎手 - 数据层 Barrel 导出
/// 统一导出数据服务，方便外部引用
library;

// ─── Remote ──────────────────────────────────────────────
export 'remote/api_client.dart';
export 'remote/api_endpoints.dart';

// ─── Local ───────────────────────────────────────────────
export 'local/database_helper.dart';

// ─── Mock Data Sources ──────────────────────────────────
export 'mock/mock_auth_data_source.dart';
export 'mock/mock_question_data_source.dart';
export 'mock/mock_review_data_source.dart';
export 'mock/mock_report_data_source.dart';

// ─── Repository Implementations ─────────────────────────
export 'repositories/auth_repository_mock.dart';
export 'repositories/question_repository_mock.dart';
export 'repositories/review_repository_mock.dart';
export 'repositories/report_repository_mock.dart';
