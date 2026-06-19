/// 错题猎手 - Auth Mock 数据源
/// 提供认证流程的模拟数据，后端就绪后替换为 RemoteDataSource
library;

import '../../features/auth/bloc/auth_state.dart';

/// Auth 模块的 Mock 数据源
class MockAuthDataSource {
  /// 模拟 OTP 验证返回的用户数据
  AuthUser mockVerifyOtpResult({
    required String phone,
    required String grade,
  }) {
    return AuthUser(
      id: 'user_001',
      phone: phone,
      nickname: '小明',
      grade: grade,
      token: 'mock_jwt_token_abc123',
      isFirstLogin: true,
    );
  }

  /// 模拟 Token 验证（始终有效）
  Future<bool> validateToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  /// 模拟发送 OTP 延迟
  Future<void> sendOtp(String phone) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  /// 模拟验证 OTP 延迟
  Future<void> verifyOtpDelay() async {
    await Future.delayed(const Duration(seconds: 1));
  }
}
