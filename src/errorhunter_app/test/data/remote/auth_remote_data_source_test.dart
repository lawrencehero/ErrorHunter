/// AuthRemoteDataSource / AuthRepositoryImpl 单元测试
///
/// 守护修复：
/// #5：登出调服务端 /auth/logout 清 redis token
/// #4：sendOtp/verifyOtp 4xx 时解析后端 {code,message} 抛 AuthApiException；
///     网络错误抛 AuthNetworkException，让 AuthBloc 能精准映射文案。
///
/// 用手写 FakeApiClient 喂预设响应/异常，与 review_remote_data_source_test.dart 风格一致。
library;

import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/data/remote/api_client.dart';
import 'package:errorhunter_app/data/remote/api_endpoints.dart';
import 'package:errorhunter_app/data/remote/auth_remote_data_source.dart';
import 'package:errorhunter_app/data/repositories/auth_repository_impl.dart';

class RecordedCall {
  const RecordedCall(this.method, this.path, {this.body});
  final String method;
  final String path;
  final Object? body;
}

/// 可记录调用、按 path 返回预设 body 或抛预设异常的假 ApiClient。
///
/// - [_responses] 命中 path → 返回 200 + {"data": inner}
/// - [_exceptions] 命中 path → 抛该异常（模拟 4xx DioException / 网络错误等）
/// 命中异常优先于命中响应。
class FakeApiClient implements ApiClient {
  FakeApiClient({
    Map<String, Object?>? responses,
    Map<String, Object>? exceptions,
    Map<String, int>? codes,
  })  : _responses = responses ?? const {},
        _exceptions = exceptions ?? const {},
        _codes = codes ?? const {};

  final Map<String, Object?> _responses;
  final Map<String, Object> _exceptions;
  final Map<String, int> _codes;
  final List<RecordedCall> calls = [];

  Response<T> _response<T>(String path) {
    final inner = _responses[path];
    return Response<T>(
      data: <String, dynamic>{
        'code': _codes[path] ?? 0,
        'data': inner,
      } as T?,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(RecordedCall('POST', path, body: data));
    final err = _exceptions[path];
    if (err != null) throw err;
    return _response<T>(path);
  }

  /// verifyOtp 成功路径会调用 saveTokens 持久化 token，测试里 no-op 即可。
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeApiClient does not implement ${invocation.memberName}',
    );
  }
}

/// 构造一个 4xx DioException，response.data 为给定 body（Map 或 JSON 字符串）。
DioException _dioError4xx(
  int statusCode,
  Object body, {
  String path = ApiEndpoints.verifyOtp,
}) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    response: Response(
      statusCode: statusCode,
      data: body,
      requestOptions: RequestOptions(path: path),
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  // ─── #5 守护：登出 ──────────────────────────────────────────

  group('AuthRemoteDataSource.logout', () {
    test('调用 POST /auth/logout', () async {
      final client = FakeApiClient();
      final ds = AuthRemoteDataSource(client: client);

      await ds.logout();

      expect(client.calls, hasLength(1));
      expect(client.calls.last.method, 'POST');
      expect(client.calls.last.path, ApiEndpoints.logout);
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('委托给 AuthRemoteDataSource.logout', () async {
      final client = FakeApiClient();
      final ds = AuthRemoteDataSource(client: client);
      final repo = AuthRepositoryImpl(dataSource: ds);

      await repo.logout();

      expect(client.calls, hasLength(1),
          reason: 'AuthRepositoryImpl.logout 必须调用数据源，最终命中 /auth/logout');
      expect(client.calls.last.path, ApiEndpoints.logout);
    });
  });

  // ─── #4 守护：4xx → AuthApiException 携带 code/message ─────

  group('sendOtp 4xx → AuthApiException', () {
    test('response.data 为 Map → 抛 AuthApiException 携带 code/message', () async {
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.sendOtp: _dioError4xx(400, {
          'code': 10007,
          'message': '今日验证码发送次数已达上限',
        }, path: ApiEndpoints.sendOtp),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.sendOtp('13812345678'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 10007)
            .having((e) => e.message, 'message', '今日验证码发送次数已达上限')),
      );
    });

    test('response.data 为 JSON 字符串 → 同样解析出 code/message', () async {
      // 某些网关/拦截器会把 body 转成字符串，需兼容
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.sendOtp: _dioError4xx(
          400,
          '{"code":10002,"message":"验证码错误或已过期"}',
          path: ApiEndpoints.sendOtp,
        ),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.sendOtp('13812345678'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 10002)
            .having((e) => e.message, 'message', '验证码错误或已过期')),
      );
    });

    test('code 为 num 类型（如 10007.0）→ 正确转 int', () async {
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.sendOtp: _dioError4xx(400, {
          'code': 10007.0,
          'message': '频繁',
        }, path: ApiEndpoints.sendOtp),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.sendOtp('13812345678'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 10007)),
      );
    });
  });

  group('verifyOtp 4xx → AuthApiException', () {
    test('10014 已注销 → 抛 AuthApiException(10014, ...)', () async {
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.verifyOtp: _dioError4xx(403, {
          'code': 10014,
          'message': '该账号已注销',
        }),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.verifyOtp(phone: '13812345678', otp: '000000'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 10014)
            .having((e) => e.message, 'message', '该账号已注销')),
      );
    });

    test('5xx 但带业务体 → 仍抛 AuthApiException（透传后端文案）', () async {
      // 后端有时用 500 + {code,message} 表达业务错误，数据源应解析出业务体
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.verifyOtp: _dioError4xx(500, {
          'code': 10010,
          'message': '昵称长度应为2-12个字符',
        }),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.verifyOtp(phone: '13812345678', otp: '000000'),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 10010)),
      );
    });
  });

  // ─── #4 守护：网络错误 → AuthNetworkException ──────────────

  group('网络错误识别', () {
    test('connectionTimeout → AuthNetworkException', () async {
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.sendOtp: DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.sendOtp),
          type: DioExceptionType.connectionTimeout,
        ),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.sendOtp('13812345678'),
        throwsA(isA<AuthNetworkException>()),
      );
    });

    test('connectionError（DNS 失败）→ AuthNetworkException', () async {
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.sendOtp: DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.sendOtp),
          type: DioExceptionType.connectionError,
          error: const SocketException('Failed host lookup'),
        ),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.sendOtp('13812345678'),
        throwsA(isA<AuthNetworkException>()),
      );
    });

    test('SocketException 直接抛出 → AuthNetworkException', () async {
      final client = FakeApiClient(exceptions: {
        ApiEndpoints.sendOtp: const SocketException('Failed host lookup'),
      });
      final ds = AuthRemoteDataSource(client: client);

      await expectLater(
        ds.sendOtp('13812345678'),
        throwsA(isA<AuthNetworkException>()),
      );
    });
  });

  // ─── 成功路径回归 ──────────────────────────────────────────

  group('verifyOtp 成功', () {
    test('老用户 code=0 → VerifyOtpLoggedIn 并保存 token', () async {
      final client = FakeApiClient(responses: {
        ApiEndpoints.verifyOtp: <String, dynamic>{
          'user': {
            'id': 42,
            'phone': '13812345678',
            'nickname': '小明',
            'grade': '31',
          },
          'access_token': 'access_abc',
          'refresh_token': 'refresh_xyz',
        },
      });
      final ds = AuthRemoteDataSource(client: client);

      final result = await ds.verifyOtp(
        phone: '13812345678',
        otp: '123456',
      );

      expect(result, isA<VerifyOtpLoggedIn>());
      final ar = (result as VerifyOtpLoggedIn).result;
      expect(ar.user.id, '42');
      expect(ar.user.phone, '13812345678');
      expect(ar.user.nickname, '小明');
      expect(ar.user.grade, '31');
      expect(ar.user.token, 'access_abc');
      expect(ar.refreshToken, 'refresh_xyz');
    });

    test('后端返回掩码号 138****5678 → 用用户输入的真实号，不用掩码号', () async {
      // 后端 toUserInfo 对 phone 做了掩码（138****5678）。
      // 客户端必须用用户输入的真实号，否则重登预填/注销会拿到含 * 的号导致后端 500。
      final client = FakeApiClient(responses: {
        ApiEndpoints.verifyOtp: <String, dynamic>{
          'user': {
            'id': 42,
            'phone': '138****5678', // 后端掩码号
            'nickname': '小明',
            'grade': '31',
          },
          'access_token': 'access_abc',
          'refresh_token': 'refresh_xyz',
        },
      });
      final ds = AuthRemoteDataSource(client: client);

      final result = await ds.verifyOtp(
        phone: '13812345678', // 用户输入的真实号
        otp: '123456',
      );

      final ar = (result as VerifyOtpLoggedIn).result;
      expect(ar.user.phone, '13812345678', reason: '应存真实号而非掩码号');
      expect(ar.user.phone, isNot(contains('*')));
    });

    test('新用户 code=10017 → VerifyOtpNeedProfile(registration_token)', () async {
      final client = FakeApiClient(
        responses: {
          ApiEndpoints.verifyOtp: <String, dynamic>{
            'is_new_user': true,
            'registration_token': 'reg_tok_abc',
          },
        },
        codes: {ApiEndpoints.verifyOtp: 10017},
      );
      final ds = AuthRemoteDataSource(client: client);

      final result = await ds.verifyOtp(
        phone: '13812345678',
        otp: '123456',
      );

      expect(result, isA<VerifyOtpNeedProfile>());
      expect((result as VerifyOtpNeedProfile).registrationToken, 'reg_tok_abc');
    });
  });
}
