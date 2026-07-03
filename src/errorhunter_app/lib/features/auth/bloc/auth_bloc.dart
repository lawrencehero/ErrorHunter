/// 错题猎手 - Auth BLoC
/// 管理认证流程：Token 存储、登录状态判断、OTP 倒计时
library;

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../data/remote/auth_remote_data_source.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// SharedPreferences Keys
class _StorageKeys {
  static const token = 'auth_token';
  static const userId = 'auth_user_id';
  static const phone = 'auth_phone';
  static const nickname = 'auth_nickname';
  static const grade = 'auth_grade';
  static const hasOnboarded = 'has_onboarded';
}

/// ApiClient 持久化 token 的 key（与 api_client.dart 内部保持一致）
/// 用于登出时兜底清除，避免拦截器继续携带旧 token。
const String _kAccessTokenKey = 'auth_access_token';
const String _kRefreshTokenKey = 'auth_refresh_token';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SharedPreferences _prefs;
  final AuthRepository _authRepository;

  AuthBloc(this._prefs, this._authRepository) : super(const AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SendOtp>(_onSendOtp);
    on<VerifyOtp>(_onVerifyOtp);
    on<CompleteRegistration>(_onCompleteRegistration);
    on<SetNickname>(_onSetNickname);
    on<Logout>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  // ─── Check Auth Status ──────────────────────────────────────

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    await Future.delayed(const Duration(milliseconds: 200));

    final token = _prefs.getString(_StorageKeys.token);
    final userId = _prefs.getString(_StorageKeys.userId);
    final phone = _prefs.getString(_StorageKeys.phone) ?? '';
    final nickname = _prefs.getString(_StorageKeys.nickname) ?? '';
    final grade = _prefs.getString(_StorageKeys.grade) ?? '';

    if (token != null && token.isNotEmpty && userId != null) {
      final isValid = await _authRepository.validateToken(token);
      if (!isValid) {
        // 仅当 token 明确无效（401/403）时清掉 token
        // 保留 phone / nickname / grade 等用户偏好，下次重登无需重新填写
        await _prefs.remove(_StorageKeys.token);
        await _prefs.remove(_StorageKeys.userId);
        emit(const Unauthenticated());
        return;
      }

      emit(Authenticated(AuthUser.fromStorage(
        id: userId,
        phone: phone,
        nickname: nickname,
        grade: grade,
        token: token,
      )));
    } else {
      emit(const Unauthenticated());
    }
  }

  // ─── Send OTP ───────────────────────────────────────────────

  Future<void> _onSendOtp(SendOtp event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    try {
      await _authRepository.sendOtp(event.phone);

      final canResendAt = DateTime.now().add(const Duration(seconds: 60));
      emit(OtpSent(canResendAt));
    } catch (e) {
      emit(AuthError(_mapAuthError(e, isSendOtp: true)));
    }
  }

  // ─── Verify OTP ─────────────────────────────────────────────

  Future<void> _onVerifyOtp(VerifyOtp event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    try {
      final result = await _authRepository.verifyOtp(
        phone: event.phone,
        otp: event.otp,
      );

      switch (result) {
        case VerifyOtpNeedProfile(:final registrationToken):
          // 新用户：验证码已通过，进入年级+协议补全页
          emit(RegistrationRequired(
            registrationToken: registrationToken,
            phone: event.phone,
          ));
        case VerifyOtpLoggedIn(:final result):
          // 老用户：直接登录
          final user = result.user;
          await _prefs.setString(_StorageKeys.token, user.token);
          await _prefs.setString(_StorageKeys.userId, user.id);
          await _prefs.setString(_StorageKeys.phone, user.phone);
          await _prefs.setString(_StorageKeys.nickname, user.nickname);
          await _prefs.setString(_StorageKeys.grade, user.grade);
          emit(Authenticated(user));
      }
    } catch (e) {
      emit(AuthError(_mapAuthError(e, isSendOtp: false)));
    }
  }

  // ─── Complete Registration ──────────────────────────────────

  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final user = await _authRepository.register(
        registrationToken: event.registrationToken,
        grade: event.grade,
        agreementAccepted: event.agreementAccepted,
        nickname: event.nickname,
        phone: event.phone,
      );

      await _prefs.setString(_StorageKeys.token, user.token);
      await _prefs.setString(_StorageKeys.userId, user.id);
      await _prefs.setString(_StorageKeys.phone, user.phone);
      await _prefs.setString(_StorageKeys.nickname, user.nickname);
      await _prefs.setString(_StorageKeys.grade, user.grade);

      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(_mapAuthError(e, isSendOtp: false)));
    }
  }

  // ─── Set Nickname ───────────────────────────────────────────

  Future<void> _onSetNickname(
    SetNickname event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! Authenticated) return;
    try {
      await _authRepository.updateNickname(event.nickname);
      await _prefs.setString(_StorageKeys.nickname, event.nickname);

      emit(Authenticated(AuthUser(
        id: currentState.user.id,
        phone: currentState.user.phone,
        nickname: event.nickname,
        grade: currentState.user.grade,
        token: currentState.user.token,
      )));
    } catch (_) {
      // 昵称更新失败：保留原昵称；发出错误态供 UI 提示。
      // （随后若用户操作触发新事件会自然回到 Authenticated）
      emit(const AuthError('昵称更新失败，请稍后重试'));
      // 立即恢复 Authenticated，避免误被路由当作未登录
      emit(currentState);
    }
  }

  // ─── Logout ─────────────────────────────────────────────────

  Future<void> _onLogout(Logout event, Emitter<AuthState> emit) async {
    // 1. 先通知后端撤销 token（清 redis refresh token + access token 黑名单）。
    //    /auth/logout 是受保护接口，需 access token 仍在本地，故必须在清本地 token 之前调。
    //    失败不阻塞本地登出：网络不可达 / 后端 5xx 时仍清本地态，避免用户卡在登录中。
    try {
      await _authRepository.logout();
    } catch (_) {
      // 静默：本地登出仍要继续
    }

    // 2. 清本地存储（保留 phone，便于下次重登预填手机号——支付宝式体验）
    await _clearStorage();

    // 3. 同步清 ApiClient 持久化的 access/refresh token（拦截器读这两个 key）。
    //    Logout 事件是统一的登出入口（profile_page 退出登录 / 注销账号成功），
    //    这里负责清 access/refresh token，调用方无需再单独调 ApiClient.clearTokens。
    await _prefs.remove(_kAccessTokenKey);
    await _prefs.remove(_kRefreshTokenKey);

    emit(const Unauthenticated());
  }

  // ─── Session Expired ───────────────────────────────────────

  /// 会话过期处理 — refresh token 刷新失败时由 ApiClient.onSessionExpired
  /// 回调触发。
  ///
  /// 与 Logout 的区别：不调后端 /auth/logout（access token 已无效，调了也
  /// 是 401），直接清本地态并 emit Unauthenticated，路由 refreshListenable
  /// 自动 redirect 到 /login。
  ///
  /// 幂等：已是 Unauthenticated 时直接 return，不重复 emit。这样多个并发
  /// 401 触发的多次 AuthSessionExpired 不会造成状态抖动。
  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    // 幂等：已经未登录就不再重复处理
    if (state is Unauthenticated) return;

    // 清本地认证态（保留 phone，沿用 #2 已改的 _clearStorage，
    // 让用户跳到登录页时手机号已预填，免去重输 11 位）
    await _clearStorage();

    // 同步清 ApiClient 持久化的 access/refresh token（拦截器读这两个 key）
    await _prefs.remove(_kAccessTokenKey);
    await _prefs.remove(_kRefreshTokenKey);

    emit(const Unauthenticated());
  }

  // ─── Helpers ────────────────────────────────────────────────

  /// 把数据层抛出的异常映射成用户可读的错误文案。
  ///
  /// 优先级：
  /// 1. AuthApiException → 按 code 映射业务文案（10002/10007/10014/10005/10010）
  ///    命中时直接用；code 未命中且 message 非空则用 message；
  /// 2. AuthNetworkException / SocketException / Timeout → 网络文案；
  /// 3. 兜底：toString 关键字匹配（保留昨晚 Auth agent 的逻辑，
  ///    兼容 Mock 数据源 / 旧异常路径，确保不回归）；
  /// 4. 通用兜底文案。
  ///
  /// isSendOtp 区分发送/验证场景的限流文案（发送用"次数上限"，验证用"频繁"）。
  String _mapAuthError(Object e, {required bool isSendOtp}) {
    // 1. 业务错误（后端 4xx + {code,message}）
    if (e is AuthApiException) {
      switch (e.code) {
        case 10002:
          return '验证码错误或已过期';
        case 10007:
          return isSendOtp
              ? '今日验证码发送次数已达上限，请稍后再试'
              : '操作过于频繁，请稍后再试';
        case 10014:
          return '该账号已注销，请联系客服';
        case 10005:
          return '该手机号尚未注册，请先注册';
        case 10010:
          return '昵称长度应为2-12个字符';
        case 10018:
          return '注册凭证已失效，请重新获取验证码';
        case 10019:
          return '请阅读并同意用户协议与隐私政策';
      }
      // code 未命中但有后端文案 → 透传后端中文（比通用兜底更友好）
      if (e.message.isNotEmpty) return e.message;
      return isSendOtp ? '发送验证码失败，请稍后重试' : '操作失败，请稍后重试';
    }

    // 2. 网络错误
    if (e is AuthNetworkException) {
      return e.message;
    }
    final msg = e.toString();
    if (e is SocketException ||
        e is TimeoutException ||
        msg.contains('SocketException') ||
        msg.contains('TimeoutException') ||
        msg.contains('Failed host') ||
        msg.contains('Network')) {
      return '网络连接失败，请检查网络后重试';
    }

    // 3. 关键字兜底（兼容 Mock / 旧异常路径，保留昨晚逻辑不回归）
    if (isSendOtp) {
      if (msg.contains('频繁') || msg.contains('上限') || msg.contains('10007')) {
        return '今日验证码发送次数已达上限，请稍后再试';
      }
      return '发送验证码失败，请稍后重试';
    }
    if (msg.contains('验证码') || msg.contains('10002')) {
      return '验证码错误或已过期';
    }
    if (msg.contains('频繁') || msg.contains('上限') || msg.contains('10007')) {
      return '操作过于频繁，请稍后重试';
    }
    if (msg.contains('已注销') || msg.contains('10014')) {
      return '该账号已注销，请联系客服';
    }
    if (msg.contains('未注册') || msg.contains('10005')) {
      return '该手机号尚未注册，请先注册';
    }
    if (msg.contains('昵称') || msg.contains('10010')) {
      return '昵称长度应为2-12个字符';
    }
    if (msg.contains('凭证') || msg.contains('10018')) {
      return '注册凭证已失效，请重新获取验证码';
    }
    if (msg.contains('协议') || msg.contains('10019')) {
      return '请阅读并同意用户协议与隐私政策';
    }
    return '操作失败，请稍后重试';
  }

  /// 清本地认证态。
  ///
  /// 设计取舍（支付宝/微信式体验）：
  /// - 清：token / userId / nickname / grade（用户业务态，重登后会从后端重新拉取）
  /// - 留：phone（手机号，用于登录页预填，免去用户重复输入 11 位手机号）
  /// - hasOnboarded（引导页只展示一次，登出不应重置）
  Future<void> _clearStorage() async {
    await _prefs.remove(_StorageKeys.token);
    await _prefs.remove(_StorageKeys.userId);
    await _prefs.remove(_StorageKeys.nickname);
    await _prefs.remove(_StorageKeys.grade);
    // 保留 _StorageKeys.phone：登录页预填用
  }

  /// 检查是否已完成引导页
  bool get hasOnboarded => _prefs.getBool(_StorageKeys.hasOnboarded) ?? false;

  /// 标记已完成引导页
  Future<void> markOnboarded() async {
    await _prefs.setBool(_StorageKeys.hasOnboarded, true);
  }
}
