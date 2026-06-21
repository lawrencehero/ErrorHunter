/// 错题猎手 - 注销账号页（3步流程）
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/danger_button.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/buttons/secondary_button.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../../../widgets/common/divider.dart';

/// 注销步骤
enum _DeactivateStep { explanation, verification, confirmation }

/// 注销账号页
class DeactivatePage extends StatefulWidget {
  const DeactivatePage({super.key});

  @override
  State<DeactivatePage> createState() => _DeactivatePageState();
}

class _DeactivatePageState extends State<DeactivatePage> {
  _DeactivateStep _currentStep = _DeactivateStep.explanation;
  bool _isProcessing = false;

  // Step 2 验证字段
  final _phoneController = TextEditingController(text: '138****8888');
  final _codeController = TextEditingController();
  bool _codeSent = false;
  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () {
            if (_currentStep == _DeactivateStep.explanation) {
              context.pop();
            } else {
              setState(() {
                _currentStep = _DeactivateStep.values[
                    _currentStep.index - 1];
              });
            }
          },
        ),
        title: Text(
          '注销账号',
          style: AppTypography.primary.h3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.base),
          child: Column(
            children: [
              // ─── 步骤指示器 ──────────────────────────
              _buildStepIndicator(),
              SizedBox(height: AppSpacing.xl),
              // ─── 步骤内容 ────────────────────────────
              Expanded(child: _buildStepContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: _DeactivateStep.values.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isActive = step.index <= _currentStep.index;
        final isCurrent = step == _currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.danger
                        : AppColors.border,
                    borderRadius: AppRadius.radiusFull,
                  ),
                ),
              ),
              if (index < _DeactivateStep.values.length - 1)
                SizedBox(width: AppSpacing.xs),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _DeactivateStep.explanation:
        return _buildExplanationStep();
      case _DeactivateStep.verification:
        return _buildVerificationStep();
      case _DeactivateStep.confirmation:
        return _buildConfirmationStep();
    }
  }

  // ─── Step 1: 注销说明 ────────────────────────────────
  Widget _buildExplanationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EHBaseCard(
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 24, color: AppColors.danger),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    '注销须知',
                    style: AppTypography.primary.h3.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                '注销账号后，以下数据将被永久删除且无法恢复：',
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              ..._deletionItems.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('❌ ', style: TextStyle(fontSize: 14)),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTypography.primary.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.base),
        EHBaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 22, color: AppColors.brandSecondary),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    '7天冷静期',
                    style: AppTypography.primary.h3.copyWith(
                      color: AppColors.brandSecondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                '提交注销申请后有7天冷静期。在此期间重新登录即可撤销注销申请。冷静期结束后账号将被永久删除。',
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        EHDangerButton(
          text: '我要注销',
          onPressed: () => setState(
              () => _currentStep = _DeactivateStep.verification),
          size: EHButtonSize.lg,
          fullWidth: true,
        ),
        SizedBox(height: AppSpacing.sm),
        Center(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              '我再想想',
              style: AppTypography.primary.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> get _deletionItems => [
        '所有错题记录和复习历史',
        '个人学习数据和统计报告',
        '上传的题目图片和OCR识别结果',
        '成就、打卡记录和个人设置',
        '与账号关联的所有信息',
      ];

  // ─── Step 2: 身份验证 ────────────────────────────────
  Widget _buildVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '为了确认是您本人操作，请验证手机号',
          style: AppTypography.primary.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        // 手机号
        EHBaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '绑定手机号',
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _phoneController,
                enabled: false,
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.base),
        // 验证码
        EHBaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '验证码',
                style: AppTypography.primary.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: AppTypography.primary.body.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入验证码',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusMd,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 4,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: _countdownSeconds > 0 ? null : _sendCode,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                      decoration: BoxDecoration(
                        color: _countdownSeconds > 0
                            ? AppColors.textTertiary.withOpacity(0.2)
                            : AppColors.brandPrimary.withOpacity(0.1),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Text(
                        _countdownSeconds > 0
                            ? '重新发送 (${_countdownSeconds}s)'
                            : '获取验证码',
                        style: AppTypography.primary.caption.copyWith(
                          color: _countdownSeconds > 0
                              ? AppColors.textTertiary
                              : AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        EHPrimaryButton(
          text: '下一步',
          onPressed: _handleVerify,
          size: EHButtonSize.lg,
          fullWidth: true,
          isLoading: _isProcessing,
        ),
      ],
    );
  }

  void _sendCode() {
    // TODO: 调用发送验证码API
    setState(() {
      _codeSent = true;
      _countdownSeconds = 60;
    });
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
    EHToast.show(context,
        message: '验证码已发送', type: EHToastType.success);
  }

  void _handleVerify() {
    if (_codeController.text.length != 6) {
      EHToast.show(context,
          message: '请输入6位验证码', type: EHToastType.warning);
      return;
    }
    setState(() => _isProcessing = true);
    // TODO: 调用验证API
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStep = _DeactivateStep.confirmation;
      });
    });
  }

  // ─── Step 3: 确认注销 ────────────────────────────────
  Widget _buildConfirmationStep() {
    return Column(
      children: [
        EHBaseCard(
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          backgroundColor: AppColors.danger.withOpacity(0.03),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.danger),
              SizedBox(height: AppSpacing.md),
              Text(
                '最终确认',
                style: AppTypography.primary.h2.copyWith(
                  color: AppColors.danger,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                '您即将注销账号「小明同学」\n此操作不可逆，请再次确认',
                textAlign: TextAlign.center,
                style: AppTypography.primary.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        EHDangerButton(
          text: '确认注销',
          onPressed: _handleFinalDeactivate,
          size: EHButtonSize.lg,
          fullWidth: true,
          isLoading: _isProcessing,
        ),
        SizedBox(height: AppSpacing.sm),
        EHSecondaryButton(
          text: '取消',
          onPressed: () => context.pop(),
          fullWidth: true,
        ),
      ],
    );
  }

  void _handleFinalDeactivate() {
    setState(() => _isProcessing = true);
    // TODO: 调用注销API
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      EHToast.show(context,
          message: '注销申请已提交，7天后生效', type: EHToastType.info);
      context.go(Routes.login);
    });
  }
}
