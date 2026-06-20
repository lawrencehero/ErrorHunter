/// 错题猎手 - GetIt 依赖注入配置
/// 来源：技术设计文档 V1.0 §1.2
library;

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_remote_data_source.dart';
import '../data/remote/question_remote_data_source.dart';
import '../data/remote/report_remote_data_source.dart';
import '../data/remote/review_remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/question_repository_impl.dart';
import '../data/repositories/report_repository_impl.dart';
import '../data/repositories/review_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
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
  sl.registerSingleton<ApiClient>(ApiClient(prefs: prefs));
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

  // ─── Repositories (真实实现，调用后端 API) ────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: sl<AuthRemoteDataSource>()),
  );
  sl.registerLazySingleton<QuestionRepository>(
    () => QuestionRepositoryImpl(dataSource: sl<QuestionRemoteDataSource>()),
  );
  sl.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(dataSource: sl<ReviewRemoteDataSource>()),
  );
  sl.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(dataSource: sl<ReportRemoteDataSource>()),
  );

  // ─── BLoCs / Cubits ────────────────────────────────────
  sl.registerFactory<AuthBloc>(
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

  // ─── Use Cases ──────────────────────────────────────────
  // TODO: 注册业务用例（如需要 Clean Architecture）
  // sl.registerLazySingleton<GetReviewQueue>(() => GetReviewQueue(sl()));
  // sl.registerLazySingleton<SubmitReviewResult>(() => SubmitReviewResult(sl()));
}

/// 重置所有注册（仅测试使用）
Future<void> resetDependencies() async {
  await sl.reset();
}
