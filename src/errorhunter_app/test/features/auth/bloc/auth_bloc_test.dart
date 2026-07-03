/// Auth BLoC 单元测试
/// 覆盖：登录/登出事件、状态流转、Token 持久化
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:errorhunter_app/data/remote/auth_remote_data_source.dart';
import 'package:errorhunter_app/features/auth/bloc/auth_bloc.dart';
import 'package:errorhunter_app/features/auth/bloc/auth_event.dart';
import 'package:errorhunter_app/features/auth/bloc/auth_state.dart';
import 'package:errorhunter_app/domain/repositories/auth_repository.dart';

// ─── Mock AuthRepository ──────────────────────────────────────

class MockAuthRepository implements AuthRepository {
  bool shouldValidateSucceed = true;
  bool shouldSendOtpSucceed = true;
  bool shouldVerifyOtpSucceed = true;
  VerifyOtpResult? verifyOtpResult;
  /// 发送验证码抛出的异常（非空时优先于 shouldSendOtpSucceed）
  Object? sendOtpError;
  /// 验证 OTP 抛出的异常（非空时优先于 shouldVerifyOtpSucceed）
  Object? verifyOtpError;
  /// register 抛出的异常
  Object? registerError;
  /// register 返回的用户（默认构造一个）
  AuthUser? registerResult;
  /// 更新昵称是否抛出异常
  bool shouldUpdateNicknameFail = false;
  /// 登出抛出的异常（非空时模拟后端 /auth/logout 失败）
  Object? logoutError;
  /// 登出被调用次数（用于断言 /auth/logout 是否被调用）
  int logoutCallCount = 0;

  @override
  Future<bool> validateToken(String token) async {
    return shouldValidateSucceed;
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (sendOtpError != null) throw sendOtpError!;
    if (!shouldSendOtpSucceed) {
      throw Exception('发送失败');
    }
  }

  @override
  Future<VerifyOtpResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    if (verifyOtpError != null) throw verifyOtpError!;
    if (!shouldVerifyOtpSucceed) {
      throw Exception('验证失败');
    }
    return verifyOtpResult ??
        VerifyOtpLoggedIn(AuthResult(
          user: AuthUser(
            id: 'user_001',
            phone: phone,
            nickname: '测试用户',
            grade: '',
            token: 'mock_token_abc123',
          ),
          refreshToken: 'mock_refresh',
        ));
  }

  @override
  Future<AuthUser> register({
    required String registrationToken,
    required String grade,
    required bool agreementAccepted,
    String? nickname,
    String phone = '',
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult ??
        AuthUser(
          id: 'user_new',
          phone: phone,
          nickname: '新用户',
          grade: grade,
          token: 'mock_token_new',
        );
  }

  @override
  Future<void> updateNickname(String nickname) async {
    if (shouldUpdateNicknameFail) throw Exception('network error');
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    if (logoutError != null) throw logoutError!;
  }
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

    test('发送频率超限(10007) → 友好限流文案', () async {
      mockRepo.sendOtpError = Exception('今日验证码发送次数已达上限 (code=10007)');

      final future = authBloc.stream
          .take(2)
          .toList();
      authBloc.add(const SendOtp('13812345678'));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('上限'));
    });

    test('网络错误 → 网络连接失败文案', () async {
      mockRepo.sendOtpError = Exception('SocketException: Failed host lookup');

      final future = authBloc.stream
          .take(2)
          .toList();
      authBloc.add(const SendOtp('13812345678'));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('网络'));
    });
  });

  // ─── VerifyOtp Tests ────────────────────────────────────────

  group('VerifyOtp', () {
    test('验证成功 → Authenticated', () async {
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '123456',
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
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthError>(),
        ]),
      );
    });

    test('验证码错误(10002) → 验证码错误文案', () async {
      mockRepo.verifyOtpError = Exception('验证码错误或已过期 (code=10002)');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '验证码错误或已过期');
    });

    test('账号已注销(10014) → 已注销文案', () async {
      mockRepo.verifyOtpError = Exception('该账号已注销 (code=10014)');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('已注销'));
    });

    test('网络错误 → 网络连接失败文案', () async {
      mockRepo.verifyOtpError =
          Exception('SocketException: Failed host lookup');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('网络'));
    });

    test('未知错误 → 通用兜底文案', () async {
      mockRepo.verifyOtpError = Exception('something weird');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '操作失败，请稍后重试');
    });
  });

  // ─── CompleteRegistration Tests（新用户补全资料）─────────

  group('CompleteRegistration', () {
    test('注册成功 → Authenticated', () async {
      authBloc.add(const CompleteRegistration(
        registrationToken: 'reg_tok',
        phone: '13812345678',
        grade: '33',
        agreementAccepted: true,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Authenticated>(),
        ]),
      );
    });

    test('协议未勾选(10019) → 协议文案', () async {
      mockRepo.registerError = const AuthApiException(10019, '请勾选协议');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const CompleteRegistration(
        registrationToken: 'reg_tok',
        phone: '13812345678',
        grade: '33',
        agreementAccepted: false,
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '请阅读并同意用户协议与隐私政策');
    });

    test('注册凭证失效(10018) → 凭证失效文案', () async {
      mockRepo.registerError = const AuthApiException(10018, '凭证过期');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const CompleteRegistration(
        registrationToken: 'reg_tok',
        phone: '13812345678',
        grade: '33',
        agreementAccepted: true,
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '注册凭证已失效，请重新获取验证码');
    });
  });

  // ─── AuthApiException code 映射回归（修复 #4）─────────────
  // 数据源现在能把后端 {code,message} 透传成 AuthApiException，
  // AuthBloc._mapAuthError 按 code 精准命中业务文案，不再依赖 toString 关键字。

  group('AuthApiException code 映射', () {
    test('verifyOtp code=10002 → 验证码错误或已过期', () async {
      mockRepo.verifyOtpError = const AuthApiException(10002, '验证码错误');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '验证码错误或已过期');
    });

    test('verifyOtp code=10007 → 操作过于频繁', () async {
      mockRepo.verifyOtpError = const AuthApiException(10007, '发送频繁');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '操作过于频繁，请稍后再试');
    });

    test('verifyOtp code=10014 → 已注销文案', () async {
      mockRepo.verifyOtpError = const AuthApiException(10014, '账号已注销');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('已注销'));
    });

    test('verifyOtp code=10005 → 未注册文案', () async {
      mockRepo.verifyOtpError = const AuthApiException(10005, '手机号未注册');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('尚未注册'));
    });

    test('verifyOtp code=10010 → 昵称非法文案', () async {
      mockRepo.verifyOtpError = const AuthApiException(10010, '昵称非法');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
        // nickname 在 VerifyOtp 事件里没字段，但 _mapAuthError 按 code 命中
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '昵称长度应为2-12个字符');
    });

    test('verifyOtp 未知 code + 后端 message → 透传后端文案', () async {
      // code 未命中映射但有后端中文文案 → 透传，比通用兜底更友好
      mockRepo.verifyOtpError =
          const AuthApiException(99999, '后端新增的未知业务错误');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, '后端新增的未知业务错误');
    });

    test('sendOtp code=10007 → 发送次数上限文案', () async {
      mockRepo.sendOtpError =
          const AuthApiException(10007, '今日发送已达上限');

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const SendOtp('13812345678'));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('上限'));
    });

    test('AuthNetworkException → 网络连接失败文案', () async {
      mockRepo.verifyOtpError = const AuthNetworkException();

      final future = authBloc.stream.take(2).toList();
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '000000',
      ));
      final states = await future;

      expect(states.last, isA<AuthError>());
      expect((states.last as AuthError).message, contains('网络'));
    });
  });

  // ─── AuthSessionExpired Tests（修复 #3）──────────────────────
  // refresh token 刷新失败 → ApiClient.onSessionExpired 回调 →
  // AuthBloc 收到 AuthSessionExpired → 清本地态（保留 phone）→ Unauthenticated

  group('AuthSessionExpired', () {
    test('收到事件 → Unauthenticated', () async {
      // 先登录到 Authenticated
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'auth_user_id': 'u1',
        'auth_access_token': 'a',
        'auth_refresh_token': 'r',
        'auth_phone': '13812345678',
        'auth_nickname': '小明',
        'auth_grade': '31',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);
      // 状态先为 AuthInitial；注入事件
      expect(bloc.state, isA<AuthInitial>());

      final done = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const AuthSessionExpired());
      await done;

      expect(bloc.state, isA<Unauthenticated>());

      await bloc.close();
    });

    test('清本地 token/userId/nickname/grade，保留 phone（沿用 #2）', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'auth_user_id': 'u1',
        'auth_access_token': 'a',
        'auth_refresh_token': 'r',
        'auth_phone': '13812345678',
        'auth_nickname': '小明',
        'auth_grade': '31',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);

      final done = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const AuthSessionExpired());
      await done;

      // 业务态清除
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_user_id'), isNull);
      expect(prefs.getString('auth_nickname'), isNull);
      expect(prefs.getString('auth_grade'), isNull);
      // ApiClient token 清除
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
      // phone 保留（登录页预填）
      expect(prefs.getString('auth_phone'), '13812345678');

      await bloc.close();
    });

    test('幂等：连续两次 AuthSessionExpired 不重复 emit / 不抛异常', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'auth_user_id': 'u1',
        'auth_access_token': 'a',
        'auth_refresh_token': 'r',
        'auth_phone': '13812345678',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);

      // 第一次
      final done1 = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const AuthSessionExpired());
      await done1;
      expect(bloc.state, isA<Unauthenticated>());

      // 第二次（已 Unauthenticated，应静默忽略，不 emit）
      bloc.add(const AuthSessionExpired());
      await Future.delayed(const Duration(milliseconds: 50));

      // 仍是 Unauthenticated，无异常
      expect(bloc.state, isA<Unauthenticated>());

      await bloc.close();
    });
  });

  // ─── Logout Tests ───────────────────────────────────────────

  group('Logout', () {
    test('登出 → Unauthenticated', () async {
      // 先登录
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '123456',
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

    test('登出应同时清除 ApiClient 的 access/refresh token', () async {
      // 预置两套 token（AuthBloc 自己的 + ApiClient 的）
      SharedPreferences.setMockInitialValues({
        'auth_token': 'auth_token_value',
        'auth_user_id': 'u1',
        'auth_access_token': 'access_value',
        'auth_refresh_token': 'refresh_value',
        'auth_phone': '13812345678',
        'auth_nickname': '小明',
        'auth_grade': '31',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);

      // 订阅 stream 以等待 Unauthenticated 终态（此时 _clearStorage 已执行完）
      final done = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const Logout());
      await done;

      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_user_id'), isNull);
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(bloc.state, isA<Unauthenticated>());

      await bloc.close();
    });

    // 回归 #5：登出时应先调用后端 /auth/logout 撤销 redis token
    test('登出应调用 AuthRepository.logout() 通知后端撤销 token', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'auth_user_id': 'u1',
        'auth_access_token': 'a',
        'auth_refresh_token': 'r',
        'auth_phone': '13812345678',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);

      final done = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const Logout());
      await done;

      expect(mockRepo.logoutCallCount, 1,
          reason: '登出必须调用后端 /auth/logout 撤销 redis token');

      await bloc.close();
    });

    // 回归 #5：后端 /auth/logout 失败时不应阻塞本地登出
    test('后端 logout 失败时仍应清本地态并 emit Unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'auth_user_id': 'u1',
        'auth_access_token': 'a',
        'auth_refresh_token': 'r',
        'auth_phone': '13812345678',
        'auth_nickname': '小明',
        'auth_grade': '31',
      });
      final prefs = await SharedPreferences.getInstance();
      mockRepo.logoutError = Exception('SocketException: network down');
      final bloc = AuthBloc(prefs, mockRepo);

      final done = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const Logout());
      await done;

      // 本地态仍被清掉
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_access_token'), isNull);
      expect(bloc.state, isA<Unauthenticated>());

      await bloc.close();
    });

    // 回归 #2：登出应保留 phone（供登录页预填），清掉业务态
    test('登出应保留 phone，清除 nickname/grade（支付宝式重登预填）', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 't',
        'auth_user_id': 'u1',
        'auth_access_token': 'a',
        'auth_refresh_token': 'r',
        'auth_phone': '13812345678',
        'auth_nickname': '小明',
        'auth_grade': '31',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = AuthBloc(prefs, mockRepo);

      final done = bloc.stream.firstWhere((s) => s is Unauthenticated);
      bloc.add(const Logout());
      await done;

      // phone 保留
      expect(prefs.getString('auth_phone'), '13812345678',
          reason: '登出应保留手机号供登录页预填');
      // 业务态清除
      expect(prefs.getString('auth_nickname'), isNull);
      expect(prefs.getString('auth_grade'), isNull);
      // token 类清除
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_user_id'), isNull);
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);

      await bloc.close();
    });
  });

  // ─── SetNickname Tests ─────────────────────────────────────

  group('SetNickname', () {
    test('成功 → Authenticated 携带新昵称并持久化', () async {
      // 先登录
      final future0 = authBloc.stream.firstWhere((s) => s is Authenticated);
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '123456',
      ));
      await future0;
      final before = authBloc.state as Authenticated;

      // 再改昵称
      final future = authBloc.stream.firstWhere(
        (s) => s is Authenticated && s.user.nickname == '新昵称',
      );
      authBloc.add(const SetNickname('新昵称'));
      final after = await future;

      expect((after as Authenticated).user.nickname, '新昵称');
      // id/phone/grade/token 不应被改
      expect(after.user.id, before.user.id);
      expect(after.user.phone, before.user.phone);
      expect(after.user.grade, before.user.grade);
    });

    test('失败 → 发出 AuthError 并恢复 Authenticated，昵称不变', () async {
      // 先登录
      final future0 = authBloc.stream.firstWhere((s) => s is Authenticated);
      authBloc.add(const VerifyOtp(
        phone: '13812345678',
        otp: '123456',
      ));
      await future0;

      mockRepo.shouldUpdateNicknameFail = true;

      // 收集 SetNickname 之后的所有状态
      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);
      authBloc.add(const SetNickname('新昵称'));
      // 处理器为 async，等待其完成 emit 序列
      await Future.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      // 应至少出现一次 AuthError，且最终回到 Authenticated
      expect(states.any((s) => s is AuthError), isTrue);
      expect(authBloc.state, isA<Authenticated>());
      // 昵称未被更新（仍是登录时的默认昵称"测试用户"）
      expect((authBloc.state as Authenticated).user.nickname, '测试用户');
    });

    test('未登录时调用 → 静默忽略不抛异常', () async {
      // 未登录直接发 SetNickname，不应抛异常也不应改状态
      expect(authBloc.state, isA<AuthInitial>());
      authBloc.add(const SetNickname('新昵称'));
      await Future.delayed(const Duration(milliseconds: 50));
      // 状态仍为初始/未认证，无 Authenticated
      expect(authBloc.state, isNot(isA<Authenticated>()));
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
