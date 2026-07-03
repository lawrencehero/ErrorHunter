/// 错题猎手 - 补全注册资料页
/// 新用户验证码通过后进入：选择年级 + 勾选协议 → 完成注册。
/// 老用户不进入此页（直接登录）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/grade_selector.dart';

class ProfileCompletionPage extends StatefulWidget {
  final String registrationToken;
  final String phone;

  const ProfileCompletionPage({
    super.key,
    required this.registrationToken,
    required this.phone,
  });

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  String? _selectedGrade;
  bool _agreedToTerms = false;
  bool _isSubmitting = false;

  bool get _canSubmit => _selectedGrade != null && _agreedToTerms;

  Future<void> _onSelectGrade() async {
    final code = await GradeSelector.show(context);
    if (code != null && mounted) {
      setState(() => _selectedGrade = code);
    }
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
    return map[code] ?? '选择年级';
  }

  void _onSubmit() {
    if (!_canSubmit || _isSubmitting) return;
    if (widget.registrationToken.isEmpty) {
      // 凭证缺失（异常进入），退回登录页重新获取
      EHSnackbar.show(
        context,
        message: '注册凭证已失效，请重新获取验证码',
        icon: Icons.error_outline_rounded,
      );
      context.go(Routes.login);
      return;
    }
    setState(() => _isSubmitting = true);
    context.read<AuthBloc>().add(CompleteRegistration(
          registrationToken: widget.registrationToken,
          phone: widget.phone,
          grade: _selectedGrade!,
          agreementAccepted: _agreedToTerms,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // router redirect 自动跳 /home
        } else if (state is AuthError) {
          EHSnackbar.show(
            context,
            message: state.message,
            icon: Icons.error_outline_rounded,
          );
        }
        if (state is! AuthLoading) {
          if (_isSubmitting) {
            setState(() => _isSubmitting = false);
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
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) context.go(Routes.login);
              },
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: AppSpacing.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: AppSpacing.xxxl),

                      // ─── Logo + Title ─────────────────────────
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),
                      Text(
                        '完善资料',
                        style: AppTypography.primary.h1.copyWith(color: tc.primary),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        '选择年级并同意协议，即可完成注册',
                        style: AppTypography.primary.body.copyWith(color: tc.secondary),
                      ),
                      SizedBox(height: AppSpacing.xxl),

                      // ─── Grade Selector ───────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '年级',
                          style: AppTypography.primary.caption.copyWith(
                            color: tc.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.base),
                      GestureDetector(
                        onTap: _onSelectGrade,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
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
                                color: _selectedGrade != null ? accent : tc.tertiary,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _selectedGrade != null
                                      ? _gradeLabel(_selectedGrade!)
                                      : '选择年级',
                                  style: AppTypography.primary.body.copyWith(
                                    color: _selectedGrade != null ? tc.primary : tc.tertiary,
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

                      // ─── Agreement Checkbox ───────────────────
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
                                  color: _agreedToTerms ? accent : Colors.transparent,
                                  borderRadius: AppRadius.radiusSm,
                                  border: Border.all(
                                    color: _agreedToTerms ? accent : tc.tertiary,
                                  ),
                                ),
                                child: _agreedToTerms
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: AppTypography.primary.caption
                                    .copyWith(color: tc.secondary),
                                children: [
                                  const TextSpan(text: '我已阅读并同意 '),
                                  TextSpan(
                                    text: '《用户协议》',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push(Routes.userAgreement),
                                  ),
                                  const TextSpan(text: ' 和 '),
                                  TextSpan(
                                    text: '《隐私政策》',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context.push(Routes.privacyPolicy),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xl),

                      // ─── Submit Button ────────────────────────
                      EHPrimaryButton(
                        text: '完成注册',
                        size: EHButtonSize.lg,
                        fullWidth: true,
                        enabled: _canSubmit,
                        isLoading: _isSubmitting,
                        onPressed: _onSubmit,
                      ),
                      SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
