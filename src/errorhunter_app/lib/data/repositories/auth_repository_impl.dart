/// 错题猎手 - Auth Repository 真实实现
/// 调用 AuthRemoteDataSource 对接后端 API
library;

import '../../domain/repositories/auth_repository.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../remote/auth_remote_data_source.dart';

/// Auth Repository 的真实实现
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final AuthRemoteDataSource _dataSource;

  @override
  Future<bool> validateToken(String token) =>
      _dataSource.validateToken(token);

  @override
  Future<void> sendOtp(String phone) => _dataSource.sendOtp(phone);

  @override
  Future<VerifyOtpResult> verifyOtp({
    required String phone,
    required String otp,
  }) =>
      _dataSource.verifyOtp(phone: phone, otp: otp);

  @override
  Future<AuthUser> register({
    required String registrationToken,
    required String grade,
    required bool agreementAccepted,
    String? nickname,
    String phone = '',
  }) async {
    final result = await _dataSource.register(
      registrationToken: registrationToken,
      grade: grade,
      agreementAccepted: agreementAccepted,
      nickname: nickname,
      phone: phone,
    );
    return result.user;
  }

  @override
  Future<void> updateNickname(String nickname) =>
      _dataSource.updateNickname(nickname);

  @override
  Future<void> logout() => _dataSource.logout();
}
