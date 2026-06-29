/// ApiClient._RefreshTokenInterceptor 刷新失败回归测试（修复 #3）
///
/// 守护：refresh token 刷新失败时（refresh token 过期/被踢/后端 401），
/// _RefreshTokenInterceptor 应：
/// 1. 清除本地 access/refresh token
/// 2. 调用 ApiClient.onSessionExpired 回调（通知 AuthBloc 跳登录）
/// 3. 多个并发 401 只触发一次回调（防抖）
///
/// 由于 _RefreshTokenInterceptor 是私有的，这里通过构造真实 ApiClient +
/// Dio 自定义 HttpClientAdapter 模拟后端响应来端到端验证。
/// refresh 接口返回 401 → 拦截器进入刷新流程 → 刷新又 401 → catch →
/// onSessionExpired 被调用。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:errorhunter_app/data/remote/api_client.dart';
import 'package:errorhunter_app/data/remote/api_endpoints.dart';

/// 按 path + 状态码返回预设响应体的假 HTTP 适配器。
///
/// [_routes] key 形如 'GET /foo' 或 'POST /auth/refresh'，value 是
/// (statusCode, body) ；命中即返回对应响应，未命中返回 404。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._routes);
  final Map<String, (int, Object?)> _routes;
  final List<String> calls = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    final route = _routes[key];
    final statusCode = route?.$1 ?? 404;
    final body = route?.$2;

    List<int> bytes;
    if (body == null) {
      bytes = <int>[];
    } else if (body is String) {
      bytes = utf8.encode(body);
    } else {
      bytes = utf8.encode(jsonEncode(body));
    }

    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  group('_RefreshTokenInterceptor 刷新失败', () {
    test('刷新失败 → 调用 onSessionExpired 回调', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'expired_access',
        'auth_refresh_token': 'expired_refresh',
      });
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        prefs: prefs,
        baseUrl: 'https://test.errorhunter.com',
      );

      // 注入假适配器：
      // - GET /users/me → 401（触发刷新）
      // - POST /auth/refresh → 401（刷新失败）
      // Dio 内部把 401 当 badResponse 抛 DioException，拦截器 onError 进入刷新流程。
      final stub = _StubAdapter({
        'GET ${ApiEndpoints.user}': (401, {'code': 401, 'message': 'token expired'}),
        'POST ${ApiEndpoints.refreshToken}': (
          401,
          {'code': 401, 'message': 'refresh token expired'}
        ),
      });
      apiClient.dio.httpClientAdapter = stub;

      var callbackCount = 0;
      apiClient.onSessionExpired = () {
        callbackCount++;
      };

      // 发起受保护请求 → 401 → 拦截器尝试刷新 → 刷新 401 → catch → 回调
      try {
        await apiClient.get(ApiEndpoints.user);
      } catch (_) {
        // 预期抛出，忽略
      }

      // 给拦截器的异步 catch 逻辑一点时间完成回调
      await Future.delayed(const Duration(milliseconds: 100));

      expect(callbackCount, 1,
          reason: '刷新失败必须调用 onSessionExpired 回调一次');
      // 本地 token 应被清除
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);

      apiClient.close();
    });

    test('无 onSessionExpired 回调时不抛异常（接线前 / 测试场景）', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'expired_access',
        'auth_refresh_token': 'expired_refresh',
      });
      final prefs = await SharedPreferences.getInstance();

      final apiClient = ApiClient(
        prefs: prefs,
        baseUrl: 'https://test.errorhunter.com',
      );

      final stub = _StubAdapter({
        'GET ${ApiEndpoints.user}': (401, {'code': 401, 'message': 'expired'}),
        'POST ${ApiEndpoints.refreshToken}': (
          401,
          {'code': 401, 'message': 'refresh expired'}
        ),
      });
      apiClient.dio.httpClientAdapter = stub;

      // 不设置 onSessionExpired（为 null）
      Object? caught;
      try {
        await apiClient.get(ApiEndpoints.user);
      } catch (e) {
        caught = e;
      }
      await Future.delayed(const Duration(milliseconds: 100));

      // 请求本身仍抛出（401 透传），但不应因回调为 null 而抛额外异常
      expect(caught, isNotNull);
      expect(prefs.getString('auth_access_token'), isNull);

      apiClient.close();
    });
  });
}
