/// UserRemoteDataSource 单元测试
///
/// 守护修复 #6：注销账号对接真实接口
/// 1. sendDeactivateOtp 复用 /auth/otp/send，body 带 phone + scene
/// 2. deactivate 调用 /users/me/deactivate，body 带 phone + code + confirm:true
///
/// 用手写 FakeApiClient 喂空响应，与 question_remote_data_source_test.dart 风格一致。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/data/remote/api_client.dart';
import 'package:errorhunter_app/data/remote/api_endpoints.dart';
import 'package:errorhunter_app/data/remote/user_remote_data_source.dart';

/// 记录单条请求的快照（方法 + path + body）。
class RecordedCall {
  const RecordedCall(this.method, this.path, {this.body});

  final String method;
  final String path;
  final Object? body;
}

/// 可记录调用、按 path 返回预设 body 的假 ApiClient。
class FakeApiClient implements ApiClient {
  FakeApiClient(this._responses);

  final Map<String, dynamic?> _responses;
  final List<RecordedCall> calls = [];

  Response<T> _response<T>(String path) {
    final inner = _responses[path];
    return Response<T>(
      data: <String, dynamic>{'data': inner} as T?,
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
    return _response<T>(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeApiClient does not implement ${invocation.memberName}',
    );
  }
}

void main() {
  group('sendDeactivateOtp', () {
    test('调用 /auth/otp/send，body 带 phone + scene', () async {
      final client = FakeApiClient(const {});
      final ds = UserRemoteDataSource(client: client);

      await ds.sendDeactivateOtp('13812345678');

      final call = client.calls.last;
      expect(call.method, 'POST');
      expect(call.path, ApiEndpoints.sendOtp);
      expect(call.body, isA<Map<String, dynamic>>());
      final body = call.body as Map<String, dynamic>;
      expect(body['phone'], '13812345678');
      expect(body['scene'], isNotNull,
          reason: '后端 SendOTPRequest scene 字段 binding:required，必须传');
    });
  });

  group('deactivate', () {
    test('调用 /users/me/deactivate，body 带 phone + code + confirm:true', () async {
      final client = FakeApiClient(const {});
      final ds = UserRemoteDataSource(client: client);

      await ds.deactivate(phone: '13812345678', code: '888888');

      final call = client.calls.last;
      expect(call.method, 'POST');
      expect(call.path, ApiEndpoints.deactivate);
      expect(call.body, isA<Map<String, dynamic>>());
      final body = call.body as Map<String, dynamic>;
      expect(body['phone'], '13812345678');
      expect(body['code'], '888888');
      expect(body['confirm'], isTrue,
          reason: '后端 Deactivate 要求 confirm=true，否则拒绝注销');
    });
  });
}
