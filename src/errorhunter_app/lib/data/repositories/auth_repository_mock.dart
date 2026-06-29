/// 错题猎手 - Auth Repository Mock 实现
/// 使用 MockAuthDataSource 提供数据，后端就绪后替换为 Remote 实现
library;

import '../../domain/repositories/auth_repository.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../mock/mock_auth_data_source.dart';

/// Auth Repository 的 Mock 实现
class AuthRepositoryMock implements AuthRepository {
  AuthRepositoryMock({MockAuthDataSource? dataSource})
      : _dataSource = dataSource ?? MockAuthDataSource();

  final MockAuthDataSource _dataSource;

  @override
  Future<bool> validateToken(String token) =>
      _dataSource.validateToken(token);

  @override
  Future<void> sendOtp(String phone) => _dataSource.sendOtp(phone);

  @override
  Future<AuthUser> verifyOtp({
    required String phone,
    required String otp,
    String? grade,
  }) async {
    await _dataSource.verifyOtpDelay();
    return _dataSource.mockVerifyOtpResult(phone: phone, grade: grade);
  }

  @override
  Future<void> updateNickname(String nickname) async {
    // Mock: 无需网络请求，由 BLoC 层直接写入 SharedPreferences
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> logout() async {
    // Mock: 无后端，仅模拟延迟
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
