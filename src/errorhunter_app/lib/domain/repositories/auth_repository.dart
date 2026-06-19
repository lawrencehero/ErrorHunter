/// 错题猎手 - Auth Repository 抽象接口
/// 定义认证相关的数据访问契约
library;

import '../../features/auth/bloc/auth_state.dart';

/// 认证仓库抽象
abstract class AuthRepository {
  /// 验证 Token 有效性
  Future<bool> validateToken(String token);

  /// 发送 OTP 验证码
  Future<void> sendOtp(String phone);

  /// 验证 OTP 并返回用户信息
  Future<AuthUser> verifyOtp({
    required String phone,
    required String otp,
    required String grade,
  });

  /// 更新昵称
  Future<void> updateNickname(String nickname);
}
