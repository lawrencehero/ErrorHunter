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
  /// grade 为 null 时走"已注册用户登录"路径
  Future<AuthUser> verifyOtp({
    required String phone,
    required String otp,
    String? grade,
  });

  /// 更新昵称
  Future<void> updateNickname(String nickname);

  /// 登出（通知后端撤销 token）
  ///
  /// 失败不应阻塞本地登出：调用方需 try/catch 后无论成败都清本地态。
  Future<void> logout();
}
