/// 错题猎手 - Auth Repository 抽象接口
/// 定义认证相关的数据访问契约
library;

import '../../data/remote/auth_remote_data_source.dart';
import '../../features/auth/bloc/auth_state.dart';

/// 认证仓库抽象
abstract class AuthRepository {
  /// 验证 Token 有效性
  Future<bool> validateToken(String token);

  /// 发送 OTP 验证码
  Future<void> sendOtp(String phone);

  /// 验证 OTP（注册/登录合一）：老用户返回登录态，新用户返回需补全资料。
  Future<VerifyOtpResult> verifyOtp({
    required String phone,
    required String otp,
  });

  /// 凭注册凭证补全年级+协议并建号（仅新用户）。
  Future<AuthUser> register({
    required String registrationToken,
    required String grade,
    required bool agreementAccepted,
    String? nickname,
    String phone = '',
  });

  /// 更新昵称
  Future<void> updateNickname(String nickname);

  /// 登出（通知后端撤销 token）
  ///
  /// 失败不应阻塞本地登出：调用方需 try/catch 后无论成败都清本地态。
  Future<void> logout();
}
