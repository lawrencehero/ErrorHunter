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

/// 验证 OTP 并注册/登录
class VerifyOtp extends AuthEvent {
  final String phone;
  final String otp;
  final String grade; // 年级代码，如 "31", "72"

  const VerifyOtp({
    required this.phone,
    required this.otp,
    required this.grade,
  });

  @override
  List<Object?> get props => [phone, otp, grade];
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
