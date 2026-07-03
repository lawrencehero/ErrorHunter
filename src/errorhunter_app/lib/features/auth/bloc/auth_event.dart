/// 错题猎手 - Auth BLoC Events
/// 定义所有认证相关事件
library;

import 'package:equatable/equatable.dart';

/// Auth 事件基类
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// 检查本地认证状态（启动时调用）
class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

/// 发送验证码
class SendOtp extends AuthEvent {
  final String phone;

  const SendOtp(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// 验证 OTP（注册/登录合一入口）。
/// 后端按手机号是否存在自动判定：老用户直接登录，新用户进入补全资料流程。
class VerifyOtp extends AuthEvent {
  final String phone;
  final String otp;

  const VerifyOtp({
    required this.phone,
    required this.otp,
  });

  @override
  List<Object?> get props => [phone, otp];
}

/// 新用户补全年级+协议并完成注册。
/// registrationToken 由 VerifyOtp 在新用户分支返回（RegistrationRequired 携带）。
class CompleteRegistration extends AuthEvent {
  final String registrationToken;
  final String phone;
  final String grade;
  final bool agreementAccepted;
  final String? nickname;

  const CompleteRegistration({
    required this.registrationToken,
    required this.phone,
    required this.grade,
    required this.agreementAccepted,
    this.nickname,
  });

  @override
  List<Object?> get props =>
      [registrationToken, phone, grade, agreementAccepted, nickname];
}

/// 设置昵称（首次注册后）
class SetNickname extends AuthEvent {
  final String nickname;

  const SetNickname(this.nickname);

  @override
  List<Object?> get props => [nickname];
}

/// 登出
class Logout extends AuthEvent {
  const Logout();
}

/// 会话过期（refresh token 失效 / 被踢 / 后端 401）
///
/// 由 ApiClient.onSessionExpired 回调触发，AuthBloc 收到后清本地态并 emit
/// Unauthenticated，路由 refreshListenable 自动 redirect 到 /login。
///
/// 与 Logout 的区别：Logout 是用户主动登出（会先调后端 /auth/logout 撤销
/// redis token）；AuthSessionExpired 是后端已判定会话失效，本地不能再调
/// 受保护接口（access token 已无效），只需清本地态。
///
/// 幂等：AuthBloc 收到第一个 AuthSessionExpired 即 emit Unauthenticated，
/// 后续并发触发的同名事件在已是 Unauthenticated 时不再重复 emit。
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
