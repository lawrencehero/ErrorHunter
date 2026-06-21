/// 错题猎手 - P4 错题录入页（三步流程）
/// Step1: 拍照裁剪 → Step2: 确认信息 → Step3: 选错因保存
library;

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../router/app_router.dart';
import '../../../theme/theme_manager.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/buttons/secondary_button.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../../../widgets/common/inputs/text_field.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import '../models/question_model.dart';
import '../models/knowledge_point_model.dart';
import '../widgets/step_indicator.dart';
import '../widgets/image_crop_section.dart';
import '../widgets/ocr_text_section.dart';
import '../widgets/error_category_selector.dart';
import '../widgets/knowledge_point_selector.dart';
import '../widgets/image_preview.dart';

/// 错题录入页
class AddQuestionPage extends StatefulWidget {
  const AddQuestionPage({super.key});

  @override
  State<AddQuestionPage> createState() => _AddQuestionPageState();
}

class _AddQuestionPageState extends State<AddQuestionPage> {
  int _currentStep = 1;

  // Step 1 data
  String? _imagePath;

  // Step 2 data
  OcrStatus _ocrStatus = OcrStatus.loading;
  final _ocrController = TextEditingController();
  final _myAnswerController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  List<KnowledgePoint> _selectedKnowledgePoints = [];
  ErrorCategory? _recommendedCategory;

  // Step 3 data
  ErrorCategory? _selectedErrorCategory;
  List<String> _selectedSubCategories = [];
  final List<String> _customTags = [];
  final _tagController = TextEditingController();

  // Mock data for knowledge points
  final _recommendedPoints = const [
    KnowledgePoint(id: 'kp01', name: '四则运算', subject: '数学', isRecommended: true),
    KnowledgePoint(id: 'kp02', name: '运算顺序', subject: '数学', isRecommended: true),
  ];
  final _availablePoints = const [
    KnowledgePoint(id: 'kp03', name: '分数化简', subject: '数学'),
    KnowledgePoint(id: 'kp04', name: '有余数的除法', subject: '数学'),
    KnowledgePoint(id: 'kp05', name: '长方形周长与面积', subject: '数学'),
    KnowledgePoint(id: 'kp06', name: '病句辨析', subject: '语文'),
  ];

  final _subCategoriesMap = {
    ErrorCategory.knowledge: ['概念混淆', '公式记错', '知识点遗忘'],
    ErrorCategory.skill: ['运算顺序错误', '计算失误', '单位换算错误'],
    ErrorCategory.psychology: ['紧张焦虑', '漏做题', '时间不够'],
    ErrorCategory.habit: ['审题不清', '抄写错误', '答题不规范'],
  };

  @override
  void dispose() {
    _ocrController.dispose();
    _myAnswerController.dispose();
    _correctAnswerController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _canProceedStep2 => _imagePath != null;

  bool get _canProceedStep3 => _selectedKnowledgePoints.isNotEmpty;

  bool get _canSave => _selectedErrorCategory != null;

  Future<void> _pickImage(ImageSource source) async {
    // Web 环境：使用模拟流程
    if (kIsWeb) {
      setState(() {
        _imagePath = 'demo_question.jpg';
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _ocrStatus = OcrStatus.success;
          _ocrController.text = '计算 1/2 + 1/3 = ?\n\nA. 2/5    B. 5/6    C. 1/6    D. 2/6';
          _recommendedCategory = ErrorCategory.skill;
        });
      }
      return;
    }

    // 原生环境：拍照/选择图片
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1920);

      if (pickedFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法访问相册/相机，请在系统设置中开启权限'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      if (!mounted) return;

      // 跳过裁剪步骤（image_cropper 在部分真机上会崩溃）
      // 直接使用原始图片，后续版本可替换为内置裁剪组件
      final imagePath = pickedFile.path;

      setState(() {
        _imagePath = imagePath;
        _ocrStatus = OcrStatus.loading;
      });

      // 触发 Mock OCR 识别
      if (mounted) {
        context.read<QuestionBloc>().add(OcrImage(imagePath));
      }
    } on PlatformException catch (e) {
      if (e.code == 'cancelled' || e.code == 'canceled') return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片处理失败，请重试'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片处理失败，请重试'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onOcrStateChanged(QuestionState state) {
    if (state is OcrCompleted) {
      setState(() {
        _ocrStatus = OcrStatus.success;
        _ocrController.text = state.text;
        // AI recommends error category based on content
        _recommendedCategory = ErrorCategory.skill;
      });
    } else if (state is OcrFailed) {
      setState(() {
        _ocrStatus = OcrStatus.failed;
      });
    } else if (state is OcrProcessing) {
      setState(() {
        _ocrStatus = OcrStatus.loading;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  void _save() {
    if (!_canSave) return;

    context.read<QuestionBloc>().add(AddQuestion(
          imageUrl: _imagePath ?? '',
          ocrText: _ocrController.text.isEmpty ? null : _ocrController.text,
          myAnswer: _myAnswerController.text.isEmpty
              ? null
              : _myAnswerController.text,
          correctAnswer: _correctAnswerController.text.isEmpty
              ? null
              : _correctAnswerController.text,
          errorCategory: _selectedErrorCategory!,
          subCategories: _selectedSubCategories,
          knowledgePoints: _selectedKnowledgePoints,
          customTags: _customTags,
        ));
  }

  void _onQuestionAdded() {
    EHToast.show(context, message: '保存成功，已加入复习计划 🎯', type: EHToastType.success);
    // 使用 GoRouter 导航回首页
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return BlocConsumer<QuestionBloc, QuestionState>(
      listener: (context, state) {
        _onOcrStateChanged(state);
        if (state is QuestionAdded) {
          _onQuestionAdded();
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.go(Routes.home);
          },
          child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => context.go(Routes.home),
              child: Icon(Icons.close_rounded, color: tc.secondary),
            ),
            title: Text(
              '拍照录入',
              style: AppTypography.primary.h3.copyWith(
                color: tc.primary,
              ),
            ),
            centerTitle: true,
            actions: [
              if (_currentStep < 3)
                Padding(
                  padding: EdgeInsets.only(right: AppSpacing.base),
                  child: GestureDetector(
                    onTap: () {
                      if (_currentStep == 1 && !_canProceedStep2) {
                        EHToast.show(context, message: '请先拍照或选择图片', type: EHToastType.warning);
                        return;
                      }
                      if (_currentStep == 2 && !_canProceedStep3) {
                        EHToast.show(context, message: '请至少选择1个知识点', type: EHToastType.warning);
                        return;
                      }
                      _nextStep();
                    },
                    child: Center(
                      child: Text(
                        '下一步',
                        style: AppTypography.primary.button.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Step indicator
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: StepIndicator(currentStep: _currentStep),
              ),
              // Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(state),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildStepContent(QuestionState state) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(key: const ValueKey('step1'));
      case 2:
        return _buildStep2(key: const ValueKey('step2'));
      case 3:
        return _buildStep3(state, key: const ValueKey('step3'));
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Photo & Crop ──────────────────────────────────

  Widget _buildStep1({Key? key}) {
    final tc = context.textColors;
    return ImageCropSection(
      key: key,
      imagePath: _imagePath,
      onTakePhoto: () => _pickImage(ImageSource.camera),
      onPickFromGallery: () => _pickImage(ImageSource.gallery),
    );
  }

  // ─── Step 2: Confirm Info ──────────────────────────────────

  Widget _buildStep2({Key? key}) {
    final tc = context.textColors;
    return SingleChildScrollView(
      key: key,
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question image thumbnail
          if (_imagePath != null) ...[
            GestureDetector(
              onTap: () {
                // Bug #40: 使用 ImagePreview 全屏预览
                if (!kIsWeb && _imagePath != 'demo_question.jpg') {
                  ImagePreview.show(context, _imagePath!);
                }
              },
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Web 环境：显示 Mock 占位
                    if (kIsWeb || _imagePath == 'demo_question.jpg')
                      Container(
                        color: AppColors.brandPrimaryPale,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined, size: 32, color: AppColors.brandPrimary),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                '示例题目图片',
                                style: AppTypography.primary.body.copyWith(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Image.file(
                        File(_imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.background,
                          child: Center(
                            child: Icon(Icons.image, color: tc.tertiary),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('点击放大', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
          ],

          // OCR text section
          OcrTextSection(
            status: _ocrStatus,
            controller: _ocrController,
            onTextChanged: (v) {},
            onRetry: () {
              if (_imagePath != null) {
                context.read<QuestionBloc>().add(OcrImage(_imagePath!));
              }
            },
          ),

          SizedBox(height: AppSpacing.lg),

          // My wrong answer
          EHTextField(
            controller: _myAnswerController,
            label: '我的错误答案（选填）',
            hintText: '输入你的错误答案...',
            maxLines: 2,
          ),

          SizedBox(height: AppSpacing.md),

          // Correct answer
          EHTextField(
            controller: _correctAnswerController,
            label: '正确答案（选填）',
            hintText: '输入正确答案...',
            maxLines: 2,
          ),

          SizedBox(height: AppSpacing.lg),

          // Knowledge points
          KnowledgePointSelector(
            selectedPoints: _selectedKnowledgePoints,
            onChanged: (points) => setState(() => _selectedKnowledgePoints = points),
            recommendedPoints: _recommendedPoints,
            availablePoints: _availablePoints,
          ),

          SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ─── Step 3: Error Category & Save ─────────────────────────

  Widget _buildStep3(QuestionState state, {Key? key}) {
    final tc = context.textColors;
    final isSaving = state is QuestionAdding;
    final subCats = _selectedErrorCategory != null
        ? _subCategoriesMap[_selectedErrorCategory] ?? []
        : <String>[];

    return SingleChildScrollView(
      key: key,
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error category selector
          ErrorCategorySelector(
            selected: _selectedErrorCategory,
            onSelected: (cat) {
              setState(() {
                _selectedErrorCategory = cat;
                _selectedSubCategories.clear();
              });
            },
            recommendedCategory: _recommendedCategory,
            showUnknown: _shouldShowUnknown(),
            subCategories: subCats,
            selectedSubCategories: _selectedSubCategories,
            onSubCategoryChanged: (subs) =>
                setState(() => _selectedSubCategories = subs),
          ),

          SizedBox(height: AppSpacing.xl),

          // Custom tags
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '自定义标签（选填，最多5个）',
                style: AppTypography.primary.caption.copyWith(
                  color: tc.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ..._customTags.map((tag) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withOpacity(0.1),
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tag,
                                style: AppTypography.primary.caption.copyWith(
                                  color: AppColors.brandPrimary,
                                )),
                            SizedBox(width: AppSpacing.xs),
                            GestureDetector(
                              onTap: () => setState(() => _customTags.remove(tag)),
                              child: Icon(Icons.close, size: 14, color: AppColors.brandPrimary),
                            ),
                          ],
                        ),
                      )),
                  if (_customTags.length < 5)
                    GestureDetector(
                      onTap: _showAddTagDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: tc.secondary),
                            SizedBox(width: AppSpacing.xs),
                            Text('添加',
                                style: AppTypography.primary.caption.copyWith(
                                  color: tc.secondary,
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xxxl),

          // Save button
          EHPrimaryButton(
            text: '保存并加入复习计划 🎯',
            onPressed: _save,
            fullWidth: true,
            isLoading: isSaving,
            enabled: _canSave,
            size: EHButtonSize.lg,
          ),

          SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// 根据用户年级决定是否显示"不确定"选项
  /// 小学 (31-36): 显示; 初中 (71-73): 不显示
  bool _shouldShowUnknown() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final grade = authState.user.grade;
      // 初中年级 (71, 72, 73) 不显示"不确定"
      if (grade.startsWith('7')) return false;
    }
    // 默认显示（小学或未获取到年级时）
    return true;
  }

  void _showAddTagDialog() {
    final tc = context.textColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加标签', style: AppTypography.primary.h3),
        content: TextField(
          controller: _tagController,
          autofocus: true,
          maxLength: 10,
          decoration: InputDecoration(
            hintText: '输入标签名称',
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: tc.secondary)),
          ),
          TextButton(
            onPressed: () {
              final tagText = _tagController.text.trim();
              if (tagText.isNotEmpty) {
                // Bug #39: 检查标签是否已存在（trim 后比较）
                final isDuplicate = _customTags.any(
                  (t) => t.toLowerCase() == tagText.toLowerCase(),
                );
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('该标签已存在'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(ctx);
                  return;
                }
                setState(() {
                  _customTags.add(tagText);
                });
                _tagController.clear();
              }
              Navigator.pop(ctx);
            },
            child: Text('添加', style: TextStyle(color: AppColors.brandPrimary)),
          ),
        ],
      ),
    );
  }
}
