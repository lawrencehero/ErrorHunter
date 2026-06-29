/// 错题猎手 - User Remote Data Source
/// 调用后端 /v1/users/me/* 与 /v1/auth/otp/* 接口，处理用户域操作（注销账号）
library;

import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// User 远程数据源 — 注销账号等用户域写操作
///
/// 注销流程（支付宝/微信式）：
///   1. sendDeactivateOtp(phone)  → 复用 /auth/otp/send 发送短信验证码
///   2. deactivate(phone, code)   → POST /users/me/deactivate
///      后端校验验证码 + 校验手机号与当前账号一致 + 软删除 + 撤销 token
class UserRemoteDataSource {
  UserRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 发送注销场景的短信验证码。
  ///
  /// 复用 /auth/otp/send（后端 scene 字段必填但仅做透传，不区分场景）。
  /// 注销是敏感操作，发码前调用方应已确认用户登录态。
  Future<void> sendDeactivateOtp(String phone) async {
    await _client.post(
      ApiEndpoints.sendOtp,
      data: {
        'phone': phone,
        'scene': 'REGISTER',
      },
    );
  }

  /// 注销账号。
  ///
  /// 后端契约：POST /users/me/deactivate
  ///   body: { "phone": string, "code": string, "confirm": true }
  /// 后端会：
  ///   - 校验短信验证码（阿里云）
  ///   - 校验 phone 与当前登录账号绑定手机号一致
  ///   - 软删除用户
  ///   - 撤销该用户 access/refresh token
  ///
  /// 成功后调用方需清本地 token 并跳登录页。
  Future<void> deactivate({
    required String phone,
    required String code,
  }) async {
    await _client.post(
      ApiEndpoints.deactivate,
      data: {
        'phone': phone,
        'code': code,
        'confirm': true,
      },
    );
  }
}
