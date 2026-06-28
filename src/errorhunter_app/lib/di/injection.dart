/// 错题猎手 - GetIt 依赖注入配置
/// 通过 AppConfig.useMock 控制 Mock / 真实 API 切换
library;

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/local/database_helper.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_remote_data_source.dart';
import '../data/remote/knowledge_point_remote_data_source.dart';
import '../data/remote/question_remote_data_source.dart';
import '../data/remote/report_remote_data_source.dart';
import '../data/remote/review_remote_data_source.dart';
import '../data/remote/storage_remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/auth_repository_mock.dart';
import '../data/repositories/knowledge_point_repository_impl.dart';
import '../data/repositories/knowledge_point_repository_mock.dart';
import '../data/repositories/question_repository_impl.dart';
import '../data/repositories/question_repository_mock.dart';
import '../data/repositories/report_repository_impl.dart';
import '../data/repositories/report_repository_mock.dart';
import '../data/repositories/review_repository_impl.dart';
import '../data/repositories/review_repository_mock.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/knowledge_point_repository.dart';
import '../domain/repositories/question_repository.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/review_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/question/bloc/question_bloc.dart';
import '../features/report/bloc/report_bloc.dart';
import '../features/review/bloc/review_bloc.dart';

/// 全局服务定位器
final GetIt sl = GetIt.instance;

/// 初始化所有依赖注入
/// 调用时机：main() 中 runApp() 之前
Future<void> configureDependencies() async {
  // ─── Core Services ──────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ─── Data Layer ─────────────────────────────────────────
  sl.registerSingleton<ApiClient>(ApiClient(
    prefs: prefs,
    baseUrl: AppConfig.apiBaseUrl,
  ));
  sl.registerSingleton<DatabaseHelper>(DatabaseHelper());

  // ─── Data Sources (Remote) ──────────────────────────────
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<QuestionRemoteDataSource>(
    () => QuestionRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<ReviewRemoteDataSource>(
    () => ReviewRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<StorageRemoteDataSource>(
    () => StorageRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<KnowledgePointRemoteDataSource>(
    () => KnowledgePointRemoteDataSource(client: sl<ApiClient>()),
  );

  // ─── Repositories ──────────────────────────────────────
  // AppConfig.useMock = false → 使用真实 API（Impl + Remote）
  // AppConfig.useMock = true  → 使用内置 Mock 数据
  if (AppConfig.useMock) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryMock(),
    );
    sl.registerLazySingleton<QuestionRepository>(
      () => QuestionRepositoryMock(),
    );
    sl.registerLazySingleton<KnowledgePointRepository>(
      () => KnowledgePointRepositoryMock(),
    );
    sl.registerLazySingleton<ReviewRepository>(
      () => ReviewRepositoryMock(),
    );
    sl.registerLazySingleton<ReportRepository>(
      () => ReportRepositoryMock(),
    );
  } else {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(dataSource: sl<AuthRemoteDataSource>()),
    );
    sl.registerLazySingleton<QuestionRepository>(
      () => QuestionRepositoryImpl(dataSource: sl<QuestionRemoteDataSource>()),
    );
    sl.registerLazySingleton<KnowledgePointRepository>(
      () => KnowledgePointRepositoryImpl(
          dataSource: sl<KnowledgePointRemoteDataSource>()),
    );
    sl.registerLazySingleton<ReviewRepository>(
      () => ReviewRepositoryImpl(dataSource: sl<ReviewRemoteDataSource>()),
    );
    sl.registerLazySingleton<ReportRepository>(
      () => ReportRepositoryImpl(dataSource: sl<ReportRemoteDataSource>()),
    );
  }

  // ─── BLoCs / Cubits ────────────────────────────────────
  // ✅ AuthBloc 改为 lazySingleton：app_router.dart 的 redirect 和 BlocProvider 需要同一个实例
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(sl<SharedPreferences>(), sl<AuthRepository>()),
  );
  sl.registerFactory<QuestionBloc>(
    () => QuestionBloc(sl<QuestionRepository>()),
  );
  sl.registerFactory<ReviewBloc>(
    () => ReviewBloc(sl<ReviewRepository>()),
  );
  sl.registerFactory<ReportBloc>(
    () => ReportBloc(sl<ReportRepository>()),
  );
}

/// 重置所有注册（仅测试使用）
Future<void> resetDependencies() async {
  await sl.reset();
}
