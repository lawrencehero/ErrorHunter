/// 错题猎手 - 注册/登录页 (P2)
/// 手机号 + OTP + 年级选择 + 家长同意
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../di/injection.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/dialogs/snackbar.dart';
import '../../../widgets/common/inputs/phone_input.dart';
import 'package:flutter/services.dart';
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
  /// 正在提交注册（验证 OTP）——仅注册按钮转圈
  bool _isVerifying = false;
  /// 正在发送验证码——仅"获取验证码"按钮转圈
  bool _isSendingOtp = false;

  // OTP 倒计时
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  /// 登录页手机号预填 key（与 AuthBloc._StorageKeys.phone 保持一致）
  static const _kPhoneKey = 'auth_phone';

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  /// 预填上次登录的手机号（登出时保留 phone，支付宝式体验）。
  /// 注册页预填同样合理：用户登出后可能想换号注册，但更多场景是同一手机号重登。
  void _prefillPhone() {
    final prefs = sl<SharedPreferences>();
    final phone = prefs.getString(_kPhoneKey) ?? '';
    if (phone.length == 11) {
      final formatted = '${phone.substring(0, 3)} ${phone.substring(3, 7)} ${phone.substring(7)}';
      _phoneController.text = formatted;
      _phoneDigits = phone;
    }
  }

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
    // 防止重复点击触发多次发送验证码（多发短信）
    if (_isVerifying || _isSendingOtp) return;

    setState(() => _isSendingOtp = true);
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
    if (_isVerifying || _isSendingOtp) return;

    setState(() => _isVerifying = true);
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
        // 离开 AuthLoading 后复位各自的 loading 标志
        if (state is! AuthLoading) {
          if (_isSendingOtp || _isVerifying) {
            setState(() {
              _isSendingOtp = false;
              _isVerifying = false;
            });
          }
        }
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
                    '欢迎来到错题猎手',
                    style: AppTypography.primary.h1.copyWith(
                      color: tc.primary,
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
                              borderSide: BorderSide(color: accent, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (v) => setState(() => _otpCode = v),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      // 获取验证码按钮
                      GestureDetector(
                        onTap: _isPhoneValid && _countdownSeconds == 0 && !_isSendingOtp
                            ? _onSendOtp
                            : null,
                        child: Container(
                          height: 52,
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: _isPhoneValid && _countdownSeconds == 0 && !_isSendingOtp
                                ? accent
                                : accent.withOpacity(0.3),
                            borderRadius: AppRadius.radiusMd,
                          ),
                          alignment: Alignment.center,
                          child: _isSendingOtp
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withOpacity(0.8)),
                                  ),
                                )
                              : Text(
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
                        color: isGlass
                            ? Colors.white.withOpacity(0.12)
                            : Colors.white,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(
                          color: _selectedGrade != null
                              ? accent
                              : (isGlass
                                  ? Colors.white.withOpacity(0.25)
                                  : AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 20,
                            color: _selectedGrade != null
                                ? accent
                                : tc.tertiary,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _selectedGrade != null
                                  ? _gradeLabel(_selectedGrade!)
                                  : '选择年级',
                              style: AppTypography.primary.body.copyWith(
                                color: _selectedGrade != null
                                    ? tc.primary
                                    : tc.tertiary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: tc.tertiary,
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
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(left: 14, top: 2),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _agreedToTerms
                                  ? accent
                                  : Colors.transparent,
                              borderRadius: AppRadius.radiusSm,
                              border: Border.all(
                                color: _agreedToTerms
                                    ? accent
                                    : tc.tertiary,
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
                              color: tc.secondary,
                            ),
                            children: [
                              const TextSpan(text: '我已阅读并同意 '),
                              TextSpan(
                                text: '《用户协议》',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push(Routes.userAgreement);
                                  },
                              ),
                              const TextSpan(text: ' 和 '),
                              TextSpan(
                                text: '《隐私政策》',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push(Routes.privacyPolicy);
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
                    text: '注册',
                    size: EHButtonSize.lg,
                    fullWidth: true,
                    enabled: _canSubmit,
                    isLoading: _isVerifying,
                    onPressed: _onSubmit,
                  ),
                  SizedBox(height: AppSpacing.lg),

                  // ─── Already have account ──────────────────
                  // 用 go 替换当前页，避免 register↔login 互相 push 堆积无法返回
                  GestureDetector(
                    onTap: () => context.go(Routes.login),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.primary.caption.copyWith(
                          color: tc.secondary,
                        ),
                        children: [
                          const TextSpan(text: '已有账号？'),
                          TextSpan(
                            text: '快速登录',
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
