/// 错题猎手 - 注册/登录页 (P2)
/// 手机号 + OTP + 年级选择 + 家长同意
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/dialogs/snackbar.dart';
import '../../../widgets/common/inputs/otp_input.dart';
import '../../../widgets/common/inputs/phone_input.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/grade_selector.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneController = TextEditingController();
  final _otpFirstFocusNode = FocusNode();
  String _phoneDigits = '';
  String _otpCode = '';
  String? _selectedGrade;
  bool _agreedToTerms = false;
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

  // ─── Validation ──────────────────────────────────────────────

  bool get _isPhoneValid => _phoneDigits.length == 11;
  bool get _isOtpValid => _otpCode.length == 6;
  bool get _isGradeSelected => _selectedGrade != null;
  bool get _canSubmit =>
      _isPhoneValid && _isOtpValid && _isGradeSelected && _agreedToTerms;

  // ─── Handlers ────────────────────────────────────────────────

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

  void _onSelectGrade() async {
    final grade = await GradeSelector.show(context);
    if (grade != null) {
      setState(() => _selectedGrade = grade);
    }
  }

  void _onSubmit() {
    if (!_agreedToTerms) {
      EHSnackbar.show(
        context,
        message: '请先勾选家长同意',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    if (!_canSubmit) return;

    context.read<AuthBloc>().add(VerifyOtp(
          phone: _phoneDigits,
          otp: _otpCode,
          grade: _selectedGrade!,
        ));
  }

  String _gradeLabel(String code) {
    const map = {
      '31': '三年级',
      '32': '四年级',
      '33': '五年级',
      '34': '六年级',
      '71': '七年级',
      '72': '八年级',
      '73': '九年级',
    };
    return map[code] ?? code;
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
          context.go(Routes.home);
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
        return Scaffold(
          backgroundColor: AppColors.background,
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
                      color: AppColors.brandPrimary,
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
                    '欢迎来到错题猎手',
                    style: AppTypography.primary.h1.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxl),

                  // ─── Phone Input ───────────────────────────
                  EHPhoneInput(
                    controller: _phoneController,
                    onChanged: (digits) {
                      setState(() => _phoneDigits = digits);
                      // 手机号满 11 位后自动聚焦到 OTP 输入框
                      if (digits.length == 11) {
                        _otpFirstFocusNode.requestFocus();
                      }
                    },
                  ),
                  SizedBox(height: AppSpacing.base),

                  // ─── OTP Input + Send Button ───────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: EHOtpInput(
                          onCompleted: (code) =>
                              setState(() => _otpCode = code),
                          autoFocus: false,
                          firstFocusNode: _otpFirstFocusNode,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      // 获取验证码按钮
                      GestureDetector(
                        onTap: _onSendOtp,
                        child: Container(
                          height: 52,
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: _isPhoneValid && _countdownSeconds == 0
                                ? AppColors.brandPrimary
                                : AppColors.brandPrimary.withOpacity(0.3),
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
                  SizedBox(height: AppSpacing.base),

                  // ─── Grade Selector ────────────────────────
                  GestureDetector(
                    onTap: _onSelectGrade,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(
                          color: _selectedGrade != null
                              ? AppColors.brandPrimary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 20,
                            color: _selectedGrade != null
                                ? AppColors.brandPrimary
                                : AppColors.textTertiary,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _selectedGrade != null
                                  ? _gradeLabel(_selectedGrade!)
                                  : '选择年级',
                              style: AppTypography.primary.body.copyWith(
                                color: _selectedGrade != null
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),

                  // ─── Agreement Checkbox ────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _agreedToTerms = !_agreedToTerms),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: 14, top: 14),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _agreedToTerms
                                  ? AppColors.brandPrimary
                                  : Colors.transparent,
                              borderRadius: AppRadius.radiusSm,
                              border: Border.all(
                                color: _agreedToTerms
                                    ? AppColors.brandPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            child: _agreedToTerms
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: AppTypography.primary.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: '我已阅读并同意 '),
                              TextSpan(
                                text: '《用户协议》',
                                style: TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // TODO: 打开用户协议页面
                                  },
                              ),
                              const TextSpan(text: ' 和 '),
                              TextSpan(
                                text: '《隐私政策》',
                                style: TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // TODO: 打开隐私政策页面
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl),

                  // ─── Submit Button ─────────────────────────
                  EHPrimaryButton(
                    text: '注册 / 登录',
                    size: EHButtonSize.lg,
                    fullWidth: true,
                    enabled: _canSubmit,
                    isLoading: _isLoading,
                    onPressed: _onSubmit,
                  ),
                  SizedBox(height: AppSpacing.lg),

                  // ─── Already have account ──────────────────
                  GestureDetector(
                    onTap: () {
                      // 当前版本注册和登录合一，此链接保留用于未来扩展
                    },
                    child: Text(
                      '已有账号？直接登录',
                      style: AppTypography.primary.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w500,
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
