/// 错题猎手 - Auth BLoC States
/// 定义所有认证相关状态
library;

import 'package:equatable/equatable.dart';

/// 用户模型（轻量级，仅 Auth 流程使用）
class AuthUser extends Equatable {
  final String id;
  final String phone;
  final String nickname;
  final String grade; // "31"-"34" 小学, "71"-"73" 初中
  final String token;
  final bool isFirstLogin;

  const AuthUser({
    required this.id,
    required this.phone,
    required this.nickname,
    required this.grade,
    required this.token,
    this.isFirstLogin = false,
  });

  /// 从 SharedPreferences 重建
  factory AuthUser.fromStorage({
    required String id,
    required String phone,
    required String nickname,
    required String grade,
    required String token,
  }) {
    return AuthUser(
      id: id,
      phone: phone,
      nickname: nickname,
      grade: grade,
      token: token,
    );
  }

  @override
  List<Object?> get props => [id, phone, nickname, grade, token, isFirstLogin];
}

/// Auth 状态基类
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// 初始状态（尚未检查本地 Token）
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// 加载中（检查 Token / 发送 OTP / 验证 OTP）
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// 已认证（有有效 Token）
class Authenticated extends AuthState {
  final AuthUser user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// 未认证（无 Token 或 Token 过期）
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// OTP 已发送，等待验证
class OtpSent extends AuthState {
  /// 可以重新发送的时间戳（秒）
  final DateTime canResendAt;

  const OtpSent(this.canResendAt);

  @override
  List<Object?> get props => [canResendAt];
}

/// OTP 验证成功（用于过渡态）
class OtpVerified extends AuthState {
  const OtpVerified();
}

/// 新用户验证码已通过，需补全年级+协议。
/// 携带一次性 registration_token 与手机号，供补全页提交注册。
class RegistrationRequired extends AuthState {
  final String registrationToken;
  final String phone;

  const RegistrationRequired({
    required this.registrationToken,
    required this.phone,
  });

  @override
  List<Object?> get props => [registrationToken, phone];
}

/// 认证错误
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
