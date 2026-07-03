/// 错题猎手 - Auth Remote Data Source
/// 调用后端认证 API，替代 MockAuthDataSource
library;

import 'dart:convert' show jsonDecode;
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../../features/auth/bloc/auth_state.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

/// 后端业务错误异常 — 携带后端返回的 {code, message}。
///
/// 后端响应体约定：`{"code": <int>, "message": "<中文文案>", "data": ...}`。
/// 4xx 时 Dio 抛 DioException，其 toString() 不含后端 message 文案，
/// 故 AuthRemoteDataSource 在 4xx 时解析 response.data 并抛本异常，
/// 让 AuthBloc 能按 code 映射具体文案（10002 验证码错误 / 10007 频繁 /
/// 10014 已注销 / 10005 未注册 / 10010 昵称非法 等）。
///
/// toString 同时含 code 与 message，便于旧的关键字匹配逻辑兜底命中。
class AuthApiException implements Exception {
  const AuthApiException(this.code, this.message);

  /// 后端业务错误码（如 10002）。0 表示未能解析出 code。
  final int code;

  /// 后端返回的中文文案。
  final String message;

  @override
  String toString() => 'AuthApiException(code=$code, message=$message)';
}

/// 网络错误异常 — 网络不可达 / 超时 / DNS 失败等。
///
/// 与 AuthApiException 区分：AuthApiException 是后端正常返回的业务错误，
/// AuthNetworkException 是请求根本没到后端（或后端无响应）。AuthBloc 据此
/// 给出"网络连接失败"文案，而非具体业务错误文案。
class AuthNetworkException implements Exception {
  const AuthNetworkException([this.message = '网络连接失败']);

  final String message;

  @override
  String toString() => 'AuthNetworkException: $message';
}

/// Auth 远程数据源 — 对接后端 /v1/auth/* 接口
class AuthRemoteDataSource {
  AuthRemoteDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 发送 OTP 验证码
  Future<void> sendOtp(String phone) async {
    try {
      await _client.post(
        ApiEndpoints.sendOtp,
        data: {
          'phone': phone,
          'scene': 'REGISTER',
        },
      );
    } on DioException catch (e) {
      // 4xx → 解析后端 {code, message} 抛 AuthApiException
      // 网络错误（连接超时/DNS失败/连接拒绝）→ 抛 AuthNetworkException
      // 其它 DioException（如 5xx）若解析不出业务体也按网络错误处理
      throw _mapDioException(e);
    } on SocketException {
      throw const AuthNetworkException();
    }
  }

  /// 验证 OTP（注册/登录合一入口）。
  ///
  /// 后端先统一校验一次验证码，再按手机号是否存在区分：
  /// - 老用户：code=0，返回登录态 → [VerifyOtpLoggedIn]
  /// - 新用户：code=10017，返回 registration_token → [VerifyOtpNeedProfile]，
  ///   前端据此弹出年级+协议补全页，再调 [register] 建号。
  ///
  /// 验证码只在此消费一次；新用户不在 register 中二次校验（阿里云校验码成功即失效）。
  Future<VerifyOtpResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.verifyOtp,
        data: {
          'phone': phone,
          'code': otp,
          'scene': 'REGISTER',
        },
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on SocketException {
      throw const AuthNetworkException();
    }

    final body = response.data;
    if (body == null) {
      throw Exception('Invalid verify OTP response');
    }

    // 新用户：code=10017 → 需补全资料
    final code = body['code'];
    if (code == 10017) {
      final data = body['data'] as Map<String, dynamic>?;
      final token = data?['registration_token'] as String? ?? '';
      if (token.isEmpty) {
        throw Exception('Invalid verify OTP response');
      }
      return VerifyOtpNeedProfile(token);
    }

    // 老用户：code=0 → 登录
    return VerifyOtpLoggedIn(
      await _parseAuthResult(response, phone),
    );
  }

  /// 凭注册凭证补全年级+协议并建号，返回登录态。
  ///
  /// 仅新用户走此接口；registration_token 由 [verifyOtp] 在新用户分支返回，5 分钟有效。
  Future<AuthResult> register({
    required String registrationToken,
    required String grade,
    required bool agreementAccepted,
    String? nickname,
    String phone = '',
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.register,
        data: {
          'registration_token': registrationToken,
          'grade': grade,
          'agreement_accepted': agreementAccepted,
          if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        },
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on SocketException {
      throw const AuthNetworkException();
    }

    return _parseAuthResult(response, phone);
  }

  /// 解析后端登录态响应（code=0，data 含 user + access/refresh token）为 [AuthResult]，
  /// 并持久化 token。verifyOtp（老用户登录）与 register（建号）共用。
  Future<AuthResult> _parseAuthResult(
    Response<Map<String, dynamic>> response,
    String fallbackPhone,
  ) async {
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Invalid auth response');
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
      // 用用户输入的真实号，不用后端返回的掩码号（后端为隐私对 phone 做了 138****8000
      // 掩码）。客户端需要真实号用于：登录页重登预填、注销账号调 API 等。
      // 掩码号含 '*' 会原样发回后端导致短信 API 报错（500）。
      phone: fallbackPhone.isNotEmpty
          ? fallbackPhone
          : (userData?['phone'] as String? ?? ''),
      nickname: userData?['nickname'] as String? ?? '',
      grade: userData?['grade'] as String? ?? '',
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

  /// 把 DioException 映射成 AuthApiException / AuthNetworkException。
  ///
  /// 解析顺序：
  /// 1. 有 response → 尝试从 response.data 解析 {code, message}（兼容 Map /
  ///    JSON 字符串两种形态），抛 AuthApiException。解析失败时若 status 是
  ///    4xx 抛 AuthApiException(0, '请求失败')，否则（5xx）抛网络异常。
  /// 2. 无 response → 按 DioExceptionType 判断是否网络/超时错误，抛
  ///    AuthNetworkException；取消异常（cancel）原样抛出。
  ///
  /// 这样 AuthBloc 既能按 code 精准映射业务文案，又能识别网络错误给出
  /// "网络连接失败"兜底。
  Never _mapDioException(DioException e) {
    final resp = e.response;
    if (resp != null) {
      final parsed = _parseBusinessError(resp.data);
      if (parsed != null) {
        throw AuthApiException(parsed.$1, parsed.$2);
      }
      // 4xx 但拿不到业务体（如网关直接 4xx / response 非 JSON）
      if (resp.statusCode != null && resp.statusCode! >= 400 && resp.statusCode! < 500) {
        throw const AuthApiException(0, '请求失败');
      }
      // 5xx 等服务器错误，对用户表现为"网络/服务异常"
      throw const AuthNetworkException('服务暂时不可用，请稍后重试');
    }

    // 无 response：网络/超时/取消
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        throw const AuthNetworkException();
      case DioExceptionType.cancel:
        // 取消异常原样抛，让上层按需处理
        throw e;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        // badResponse 理论上 resp != null 已在上面处理；这里兜底为网络错误
        throw const AuthNetworkException();
    }
  }

  /// 从后端响应体解析 {code, message}。
  /// 兼容 data 为 Map 或 JSON 字符串两种形态。返回 (code, message) 或 null。
  (int, String)? _parseBusinessError(dynamic data) {
    Map<String, dynamic> body;
    if (data is Map<String, dynamic>) {
      body = data;
    } else if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is! Map<String, dynamic>) return null;
        body = decoded;
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }

    final rawCode = body['code'];
    int? code;
    if (rawCode is int) {
      code = rawCode;
    } else if (rawCode is num) {
      code = rawCode.toInt();
    } else if (rawCode is String) {
      code = int.tryParse(rawCode);
    }
    final message = body['message'] as String? ?? '';

    if (code == null && message.isEmpty) return null;
    return (code ?? 0, message);
  }

  /// 登出：通知后端撤销 refresh token 并把 access token 加入黑名单。
  ///
  /// 调用方（AuthBloc._onLogout）需在 try/catch 中调用，
  /// 失败不阻塞本地登出（网络不可达/后端 5xx 时仍清本地态）。
  /// 注意：必须在 ApiClient.clearTokens 之前调用，因为 /auth/logout 是
  /// 受保护接口，需要 access token 仍在本地。
  Future<void> logout() async {
    await _client.post(ApiEndpoints.logout);
  }
}

/// 验证 OTP 的返回结果
class AuthResult {
  const AuthResult({required this.user, required this.refreshToken});

  final AuthUser user;
  final String refreshToken;
}

/// verifyOtp 的密封结果：老用户已登录 / 新用户需补全资料。
sealed class VerifyOtpResult {
  const VerifyOtpResult();
}

/// 老用户：验证码通过，已签发登录态。
class VerifyOtpLoggedIn extends VerifyOtpResult {
  final AuthResult result;
  const VerifyOtpLoggedIn(this.result);
}

/// 新用户：验证码已通过，需前端补全年级+协议后调 register 建号。
class VerifyOtpNeedProfile extends VerifyOtpResult {
  final String registrationToken;
  const VerifyOtpNeedProfile(this.registrationToken);
}
