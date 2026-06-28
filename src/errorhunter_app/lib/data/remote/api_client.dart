/// 错题猎手 - Dio HTTP 客户端配置
/// 包含 Auth / RefreshToken / Retry / Logging 四个拦截器
library;

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_endpoints.dart';

/// API 客户端 — 封装 Dio，提供统一的请求入口
class ApiClient {
  ApiClient({
    required SharedPreferences prefs,
    String? baseUrl,
  })  : _prefs = prefs,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://api.errorhunter.com/v1',
          ),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _setupInterceptors();
  }

  final Dio _dio;
  final SharedPreferences _prefs;

  // ─── Token Keys ──────────────────────────────────────────
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  // ─── Interceptor Setup ──────────────────────────────────
  void _setupInterceptors() {
    _dio.interceptors.addAll([
      _AuthInterceptor(_prefs),
      _RefreshTokenInterceptor(_prefs, _dio),
      _RetryInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
    ]);
  }

  // ─── Convenience Methods ────────────────────────────────

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// 上传文件（Multipart）
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
  }

  // ─── Token Management ───────────────────────────────────

  /// 保存 Token 对
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_accessTokenKey, accessToken);
    await _prefs.setString(_refreshTokenKey, refreshToken);
  }

  /// 获取 Access Token
  String? getAccessToken() => _prefs.getString(_accessTokenKey);

  /// 获取 Refresh Token
  String? getRefreshToken() => _prefs.getString(_refreshTokenKey);

  /// 清除 Token（登出时调用）
  Future<void> clearTokens() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
  }

  /// 是否已登录
  bool get isLoggedIn => getAccessToken() != null;

  /// 关闭 Dio 实例
  void close() => _dio.close();
}

// ═══════════════════════════════════════════════════════════
// Interceptors
// ═══════════════════════════════════════════════════════════

/// Auth 拦截器 — 自动附加 Authorization Header
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._prefs);

  final SharedPreferences _prefs;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _prefs.getString('auth_access_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// RefreshToken 拦截器 — 401 时自动刷新 Token 并重放请求
class _RefreshTokenInterceptor extends Interceptor {
  _RefreshTokenInterceptor(this._prefs, this._dio);

  final SharedPreferences _prefs;
  final Dio _dio;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;

    // 仅处理 401 且非 refresh 接口本身的错误
    if (statusCode != 401 ||
        err.requestOptions.path == ApiEndpoints.refreshToken) {
      handler.next(err);
      return;
    }

    // 如果正在刷新，将请求加入等待队列
    if (_isRefreshing) {
      final completer = Completer<Response<dynamic>>();
      _pendingRequests.add(_PendingRequest(
        requestOptions: err.requestOptions,
        completer: completer,
        handler: handler,
      ));

      try {
        final response = await completer.future;
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = _prefs.getString('auth_refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token available');
      }

      // 使用新的 Dio 实例避免循环拦截
      final refreshDio = Dio(_dio.options);
      final response = await refreshDio.post<Map<String, dynamic>>(
        '${_dio.options.baseUrl}${ApiEndpoints.refreshToken}',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;
      // ✅ 修复：后端响应结构是 {"code":0,"message":"success","data":{...}}
      // 之前直接读 data['access_token'] 永远 null，因为 token 在嵌套的 data['data'] 里
      Map<String, dynamic>? respData;
      if (data is Map<String, dynamic>) {
        respData = data['data'] as Map<String, dynamic>?;
      }
      if (respData != null) {
        final newAccessToken = respData['access_token'] as String?;
        final newRefreshToken = respData['refresh_token'] as String?;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _prefs.setString('auth_access_token', newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _prefs.setString('auth_refresh_token', newRefreshToken);
          }

          // 重放原始请求
          final retryResponse = await _retryRequest(err.requestOptions);
          handler.resolve(retryResponse);

          // 重放等待队列中的请求
          for (final pending in _pendingRequests) {
            try {
              final resp = await _retryRequest(pending.requestOptions);
              pending.completer.complete(resp);
            } catch (e) {
              pending.completer.completeError(e);
            }
          }
        } else {
          throw Exception('Refresh response missing access_token');
        }
      } else {
        throw Exception('Refresh response missing data field');
      }
    } catch (e, stack) {
      // ✅ 修复：记录日志便于排查（之前 catch (_) 把错误吞了）
      debugPrint('[RefreshToken] failed: $e\n$stack');
      // 刷新失败 → 清除 Token，通知上层重新登录
      await _prefs.remove('auth_access_token');
      await _prefs.remove('auth_refresh_token');

      for (final pending in _pendingRequests) {
        pending.completer.completeError(err);
      }
      handler.next(err);
    } finally {
      _isRefreshing = false;
      _pendingRequests.clear();
    }
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) {
    final newOptions = Options(
      method: options.method,
      headers: {
        ...options.headers,
        'Authorization':
            'Bearer ${_prefs.getString("auth_access_token") ?? ""}',
      },
    );

    return _dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: newOptions,
    );
  }
}

/// 等待刷新的挂起请求
class _PendingRequest {
  const _PendingRequest({
    required this.requestOptions,
    required this.completer,
    required this.handler,
  });

  final RequestOptions requestOptions;
  final Completer<Response<dynamic>> completer;
  final ErrorInterceptorHandler handler;
}

/// Retry 拦截器 — 网络错误自动重试 3 次，指数退避
class _RetryInterceptor extends Interceptor {
  static const int _maxRetries = 3;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retries = (err.requestOptions.extra['_retryCount'] as int?) ?? 0;

    // 仅对连接/超时错误重试，不对业务错误重试
    final isRetryable = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;

    if (!isRetryable || retries >= _maxRetries) {
      handler.next(err);
      return;
    }

    // 指数退避：1s, 2s, 4s
    final delay = Duration(seconds: 1 << retries);
    await Future.delayed(delay);

    err.requestOptions.extra['_retryCount'] = retries + 1;

    try {
      final response = await Dio().fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Logging 拦截器 — 开发模式打印请求/响应日志
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌─── REQUEST ───────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('│ Body: ${options.data}');
    }
    debugPrint('└───────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('┌─── RESPONSE ──────────────────────────────');
    debugPrint('│ ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('│ Data: ${response.data}');
    debugPrint('└───────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌─── ERROR ─────────────────────────────────');
    debugPrint('│ ${err.type} ${err.requestOptions.uri}');
    debugPrint('│ Message: ${err.message}');
    if (err.response != null) {
      debugPrint('│ Status: ${err.response!.statusCode}');
      debugPrint('│ Data: ${err.response!.data}');
    }
    debugPrint('└───────────────────────────────────────────');
    handler.next(err);
  }
}
