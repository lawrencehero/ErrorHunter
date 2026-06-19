/// 错题猎手 - GetIt 依赖注入配置
/// 来源：技术设计文档 V1.0 §1.2
library;

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_client.dart';
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

  // ─── BLoCs / Cubits ────────────────────────────────────
  sl.registerFactory<AuthBloc>(() => AuthBloc(sl<SharedPreferences>()));
  sl.registerFactory<QuestionBloc>(() => QuestionBloc());
  sl.registerFactory<ReviewBloc>(() => ReviewBloc());
  sl.registerFactory<ReportBloc>(() => ReportBloc());

  // ─── Data Sources ───────────────────────────────────────
  // TODO: 注册 RemoteDataSource（依赖 ApiClient）
  // sl.registerLazySingleton<AuthRemoteDataSource>(
  //   () => AuthRemoteDataSourceImpl(client: sl<ApiClient>()),
  // );
  // sl.registerLazySingleton<QuestionRemoteDataSource>(
  //   () => QuestionRemoteDataSourceImpl(client: sl<ApiClient>()),
  // );
  // sl.registerLazySingleton<QuestionLocalDataSource>(
  //   () => QuestionLocalDataSourceImpl(db: sl<DatabaseHelper>()),
  // );

  // ─── Repositories ───────────────────────────────────────
  // TODO: 注册 Repository 实现类
  // sl.registerLazySingleton<AuthRepository>(
  //   () => AuthRepositoryImpl(remote: sl(), local: sl()),
  // );
  // sl.registerLazySingleton<QuestionRepository>(
  //   () => QuestionRepositoryImpl(remote: sl(), local: sl()),
  // );
  // sl.registerLazySingleton<ReviewRepository>(
  //   () => ReviewRepositoryImpl(remote: sl(), local: sl()),
  // );
  // sl.registerLazySingleton<ReportRepository>(
  //   () => ReportRepositoryImpl(remote: sl()),
  // );

  // ─── Use Cases ──────────────────────────────────────────
  // TODO: 注册业务用例（如需要 Clean Architecture）
  // sl.registerLazySingleton<GetReviewQueue>(() => GetReviewQueue(sl()));
  // sl.registerLazySingleton<SubmitReviewResult>(() => SubmitReviewResult(sl()));
}

/// 重置所有注册（仅测试使用）
Future<void> resetDependencies() async {
  await sl.reset();
}
