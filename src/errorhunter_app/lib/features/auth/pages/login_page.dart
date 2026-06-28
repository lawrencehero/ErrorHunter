/// 错题猎手 - 登录页
/// 已注册用户快捷入口：只填手机号 + 验证码（无需选年级 / 勾协议）
/// 底部"暂无账号？快速注册"链接跳转到注册页
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/dialogs/snackbar.dart';
import '../../../widgets/common/inputs/phone_input.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _otpFirstFocusNode = FocusNode();
  String _phoneDigits = '';
  String _otpCode = '';
  bool _isLoading = false;

  // OTP 倒计时
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpFirstFocusNode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool get _isPhoneValid => _phoneDigits.length == 11;
  bool get _isOtpValid => _otpCode.length == 6;
  bool get _canSubmit => _isPhoneValid && _isOtpValid;

  void _onSendOtp() {
    if (!_isPhoneValid) return;
    if (_countdownSeconds > 0) return;
    context.read<AuthBloc>().add(SendOtp(_phoneDigits));
  }

  void _startCountdown() {
    setState(() => _countdownSeconds = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) timer.cancel();
      });
    });
  }

  void _onSubmit() {
    if (!_canSubmit) return;
    context.read<AuthBloc>().add(VerifyOtp(
          phone: _phoneDigits,
          otp: _otpCode,
          // ✅ 登录场景：grade 传 null，后端按手机号识别已有用户
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is OtpSent) {
          _startCountdown();
          EHSnackbar.show(
            context,
            message: '验证码已发送',
            icon: Icons.check_circle_outline_rounded,
          );
        } else if (state is Authenticated) {
          // router redirect 会自动跳到 /home
        } else if (state is AuthError) {
          EHSnackbar.show(
            context,
            message: state.message,
            icon: Icons.error_outline_rounded,
          );
        }
        _isLoading = state is AuthLoading;
      },
      builder: (context, state) {
        final tc = context.textColors;
        final isGlass = context.themeExt.isDarkBackground;
        final accent = isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: AppSpacing.xxxl),

                    // ─── Logo + Welcome ────────────────────────
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    Text(
                      '欢迎回来',
                      style: AppTypography.primary.h1.copyWith(
                        color: tc.primary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      '输入手机号快速登录',
                      style: AppTypography.primary.body.copyWith(
                        color: tc.secondary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    // ─── Phone Input ───────────────────────────
                    EHPhoneInput(
                      controller: _phoneController,
                      onChanged: (digits) {
                        setState(() => _phoneDigits = digits);
                        if (digits.length == 11) {
                          _otpFirstFocusNode.requestFocus();
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.base),

                    // ─── OTP Input + Send Button ───────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _otpFirstFocusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: AppTypography.primary.h2.copyWith(
                              color: tc.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '请输入验证码',
                              hintStyle: AppTypography.primary.body.copyWith(
                                color: tc.tertiary,
                                letterSpacing: 0,
                              ),
                              filled: true,
                              fillColor: isGlass
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.radiusMd,
                                borderSide: BorderSide(
                                  color: isGlass
                                      ? Colors.white.withOpacity(0.25)
                                      : AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusMd,
                                borderSide: BorderSide(
                                  color: isGlass
                                      ? Colors.white.withOpacity(0.25)
                                      : AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusMd,
                                borderSide: BorderSide(
                                    color: accent, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (v) => setState(() => _otpCode = v),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        GestureDetector(
                          onTap: _isPhoneValid && _countdownSeconds == 0
                              ? _onSendOtp
                              : null,
                          child: Container(
                            height: 52,
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: _isPhoneValid && _countdownSeconds == 0
                                  ? accent
                                  : accent.withOpacity(0.3),
                              borderRadius: AppRadius.radiusMd,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _countdownSeconds > 0
                                  ? '${_countdownSeconds}s'
                                  : '获取验证码',
                              style: AppTypography.primary.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    // ─── Login Button ─────────────────────────
                    EHPrimaryButton(
                      text: '登录',
                      size: EHButtonSize.lg,
                      fullWidth: true,
                      enabled: _canSubmit,
                      isLoading: _isLoading,
                      onPressed: _onSubmit,
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // ─── Switch to Register ────────────────────
                    GestureDetector(
                      onTap: () => context.push(Routes.register),
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.primary.caption.copyWith(
                            color: tc.secondary,
                          ),
                          children: [
                            const TextSpan(text: '暂无账号？'),
                            TextSpan(
                              text: '快速注册',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
