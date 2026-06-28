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
/// grade 为 null 时走"已注册用户登录"路径（不传 grade 给后端）
/// grade 非 null 时走"新用户注册"路径（必传 grade 给后端）
class VerifyOtp extends AuthEvent {
  final String phone;
  final String otp;
  final String? grade; // 年级代码，注册时必填，登录时可空

  const VerifyOtp({
    required this.phone,
    required this.otp,
    this.grade,
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
