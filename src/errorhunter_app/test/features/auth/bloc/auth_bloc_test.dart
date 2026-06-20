/// Auth BLoC 单元测试
/// 覆盖：登录/登出事件、状态流转、Token 持久化

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:errorhunter_app/features/auth/bloc/auth_bloc.dart';
import 'package:errorhunter_app/features/auth/bloc/auth_event.dart';
import 'package:errorhunter_app/features/auth/bloc/auth_state.dart';
import 'package:errorhunter_app/domain/repositories/auth_repository.dart';

// ─── Mock AuthRepository ──────────────────────────────────────

class MockAuthRepository implements AuthRepository {
  bool shouldValidateSucceed = true;
  bool shouldSendOtpSucceed = true;
  bool shouldVerifyOtpSucceed = true;
  AuthUser? verifyOtpResult;

  @override
  Future<bool> validateToken(String token) async {
    return shouldValidateSucceed;
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (!shouldSendOtpSucceed) {
      throw Exception('发送失败');
    }
  }

  @override
  Future<AuthUser> verifyOtp({
    required String phone,
    required String otp,
    required String grade,
  }) async {
    if (!shouldVerifyOtpSucceed) {
      throw Exception('验证失败');
    }
    return verifyOtpResult ??
        AuthUser(
          id: 'user_001',
          phone: phone,
          nickname: '测试用户',
          grade: grade,
          token: 'mock_token_abc123',
        );
  }

  @override
  Future<void> updateNickname(String nickname) async {}
}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    mockRepo = MockAuthRepository();
    authBloc = AuthBloc(prefs, mockRepo);
  });

  tearDown(() async {
    await authBloc.close();
  });

  // ─── CheckAuthStatus Tests ──────────────────────────────────

  group('CheckAuthStatus', () {
    test('无本地Token时 → Unauthenticated', () async {
      authBloc.add(const CheckAuthStatus());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Unauthenticated>(),
        ]),
      );
    });

    test('有有效Token时 → Authenticated', () async {
      // 预置 Token
      SharedPreferences.setMockInitialValues({
        'auth_token': 'valid_token',
        'auth_user_id': 'user_001',
        'auth_phone': '138****5678',
        'auth_nickname': '小明',
        'auth_grade': '31',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);

      bloc.add(const CheckAuthStatus());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Authenticated>(),
        ]),
      );

      await bloc.close();
    });

    test('Token验证失败时 → Unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'expired_token',
        'auth_user_id': 'user_001',
      });
      final prefs = await SharedPreferences.getInstance();
      mockRepo.shouldValidateSucceed = false;
      final bloc = AuthBloc(prefs, mockRepo);

      bloc.add(const CheckAuthStatus());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Unauthenticated>(),
        ]),
      );

      await bloc.close();
    });
  });

  // ─── SendOtp Tests ──────────────────────────────────────────

  group('SendOtp', () {
    test('发送成功 → OtpSent', () async {
      authBloc.add(const SendOtp('13812345678'));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<OtpSent>(),
        ]),
      );
    });

    test('发送失败 → AuthError', () async {
      mockRepo.shouldSendOtpSucceed = false;
      authBloc.add(const SendOtp('13812345678'));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthError>(),
        ]),
      );
    });
  });

  // ─── VerifyOtp Tests ────────────────────────────────────────

  group('VerifyOtp', () {
    test('验证成功 → Authenticated', () async {
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '123456',
        grade: '31',
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Authenticated>(),
        ]),
      );
    });

    test('验证失败 → AuthError', () async {
      mockRepo.shouldVerifyOtpSucceed = false;
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
        grade: '31',
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthError>(),
        ]),
      );
    });
  });

  // ─── Logout Tests ───────────────────────────────────────────

  group('Logout', () {
    test('登出 → Unauthenticated', () async {
      // 先登录
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '123456',
        grade: '31',
      ));

      // 等待登录完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 再登出
      authBloc.add(const Logout());

      await expectLater(
        authBloc.stream,
        emits(isA<Unauthenticated>()),
      );
    });
  });

  // ─── AuthUser Model Tests ───────────────────────────────────

  group('AuthUser', () {
    test('fromStorage 正确重建', () {
      final user = AuthUser.fromStorage(
        id: 'u1',
        phone: '138****5678',
        nickname: '小明',
        grade: '31',
        token: 'tok_abc',
      );

      expect(user.id, 'u1');
      expect(user.phone, '138****5678');
      expect(user.nickname, '小明');
      expect(user.grade, '31');
      expect(user.token, 'tok_abc');
      expect(user.isFirstLogin, false);
    });

    test('Equatable 相等性', () {
      const a = AuthUser(
        id: 'u1',
        phone: '138',
        nickname: 'test',
        grade: '31',
        token: 't1',
      );
      const b = AuthUser(
        id: 'u1',
        phone: '138',
        nickname: 'test',
        grade: '31',
        token: 't1',
      );
      const c = AuthUser(
        id: 'u2',
        phone: '139',
        nickname: 'other',
        grade: '32',
        token: 't2',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ─── AuthState Tests ────────────────────────────────────────

  group('AuthState', () {
    test('初始状态为 AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    test('AuthError 携带消息', () {
      const error = AuthError('网络错误');
      expect(error.message, '网络错误');
      expect(error.props, contains('网络错误'));
    });

    test('OtpSent 携带重发时间', () {
      final now = DateTime.now();
      final state = OtpSent(now);
      expect(state.canResendAt, now);
    });
  });
}
