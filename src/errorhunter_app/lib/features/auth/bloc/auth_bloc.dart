/// 错题猎手 - Auth BLoC
/// 管理认证流程：Token 存储、登录状态判断、OTP 倒计时
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/auth_repository.dart';
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

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SharedPreferences _prefs;
  final AuthRepository _authRepository;

  AuthBloc(this._prefs, this._authRepository) : super(const AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SendOtp>(_onSendOtp);
    on<VerifyOtp>(_onVerifyOtp);
    on<SetNickname>(_onSetNickname);
    on<Logout>(_onLogout);
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
        await _clearStorage();
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
      emit(AuthError('发送验证码失败，请稍后重试'));
    }
  }

  // ─── Verify OTP ─────────────────────────────────────────────

  Future<void> _onVerifyOtp(VerifyOtp event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    try {
      final user = await _authRepository.verifyOtp(
        phone: event.phone,
        otp: event.otp,
        grade: event.grade,
      );

      // 持久化存储
      await _prefs.setString(_StorageKeys.token, user.token);
      await _prefs.setString(_StorageKeys.userId, user.id);
      await _prefs.setString(_StorageKeys.phone, user.phone);
      await _prefs.setString(_StorageKeys.nickname, user.nickname);
      await _prefs.setString(_StorageKeys.grade, user.grade);

      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError('验证失败，请检查验证码'));
    }
  }

  // ─── Set Nickname ───────────────────────────────────────────

  Future<void> _onSetNickname(
    SetNickname event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is Authenticated) {
      await _authRepository.updateNickname(event.nickname);
      await _prefs.setString(_StorageKeys.nickname, event.nickname);

      emit(Authenticated(AuthUser(
        id: currentState.user.id,
        phone: currentState.user.phone,
        nickname: event.nickname,
        grade: currentState.user.grade,
        token: currentState.user.token,
      )));
    }
  }

  // ─── Logout ─────────────────────────────────────────────────

  Future<void> _onLogout(Logout event, Emitter<AuthState> emit) async {
    await _clearStorage();
    emit(const Unauthenticated());
  }

  // ─── Helpers ────────────────────────────────────────────────

  Future<void> _clearStorage() async {
    await _prefs.remove(_StorageKeys.token);
    await _prefs.remove(_StorageKeys.userId);
    await _prefs.remove(_StorageKeys.phone);
    await _prefs.remove(_StorageKeys.nickname);
    await _prefs.remove(_StorageKeys.grade);
  }

  /// 检查是否已完成引导页
  bool get hasOnboarded => _prefs.getBool(_StorageKeys.hasOnboarded) ?? false;

  /// 标记已完成引导页
  Future<void> markOnboarded() async {
    await _prefs.setBool(_StorageKeys.hasOnboarded, true);
  }
}
