/// 错题猎手 - Auth Remote Data Source
/// 调用后端认证 API，替代 MockAuthDataSource
library;

import 'package:dio/dio.dart';

import '../../features/auth/bloc/auth_state.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// Auth 远程数据源 — 对接后端 /v1/auth/* 接口
class AuthRemoteDataSource {
  AuthRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 发送 OTP 验证码
  Future<void> sendOtp(String phone) async {
    await _client.post(
      ApiEndpoints.sendOtp,
      data: {
        'phone': phone,
        'scene': 'REGISTER',
      },
    );
  }

  /// 验证 OTP 并注册/登录，返回用户信息 + token
  /// grade 为 null 时走"登录"路径（不传 grade 给后端，由后端按手机号识别用户）
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String? grade,
    String? nickname,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.verifyOtp,
      data: {
        'phone': phone,
        'code': otp,
        'scene': 'REGISTER',
        if (grade != null && grade.isNotEmpty) 'grade': grade,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Invalid verify OTP response');
    }

    final userData = data['user'] as Map<String, dynamic>?;
    final accessToken = data['access_token'] as String? ?? '';
    final refreshToken = data['refresh_token'] as String? ?? '';

    // 保存 token 到本地存储
    await _client.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final user = AuthUser(
      id: (userData?['id'] ?? 0).toString(),
      phone: phone,
      nickname: userData?['nickname'] as String? ?? '',
      // 已注册用户登录时，后端返回的 grade 优先；否则用入参
      grade: userData?['grade'] as String? ?? grade ?? '',
      token: accessToken,
      isFirstLogin: true,
    );

    return AuthResult(user: user, refreshToken: refreshToken);
  }

  /// 验证 Token 有效性
  ///
  /// 区分错误类型：
  /// - 401/403：token 明确无效，返回 false（让上层清 token）
  /// - 网络错误 / 5xx：视为"无法验证"，返回 true（保留本地登录态）
  /// - 其他异常：保守返回 true
  Future<bool> validateToken(String token) async {
    try {
      await _client.get(ApiEndpoints.user);
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // token 明确无效或过期
        return false;
      }
      // 网络错误 / 5xx / 超时 → 不要错杀本地登录态
      return true;
    } catch (_) {
      // 未知错误，保守保留本地登录态
      return true;
    }
  }

  /// 更新昵称
  Future<void> updateNickname(String nickname) async {
    await _client.put(
      ApiEndpoints.userSettings,
      data: {'nickname': nickname},
    );
  }
}

/// 验证 OTP 的返回结果
class AuthResult {
  const AuthResult({required this.user, required this.refreshToken});

  final AuthUser user;
  final String refreshToken;
}
