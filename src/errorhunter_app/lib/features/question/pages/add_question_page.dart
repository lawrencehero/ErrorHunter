/// 错题猎手 - P4 错题录入页（三步流程）
/// Step1: 拍照裁剪 → Step2: 确认信息 → Step3: 选错因保存
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../router/app_router.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/knowledge_point_repository.dart';
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
import '../models/ocr_result.dart';
import '../widgets/step_indicator.dart';
import '../widgets/image_crop_section.dart';
import '../widgets/ocr_text_section.dart';
import '../widgets/math_text.dart' show normalizeMathText;
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
  String? _originalImagePath; // 保留原始图片路径用于裁剪
  Size? _originalImageSize; // 原始图片真实宽高（用于 BoxFit.contain 坐标转换）
  Rect _cropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
  bool _isCropping = false;

  // Step 2 data
  OcrStatus _ocrStatus = OcrStatus.loading;
  final _ocrController = TextEditingController();
  final _myAnswerController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  List<KnowledgePoint> _selectedKnowledgePoints = [];
  ErrorCategory? _recommendedCategory;

  // OCR 识别到的图形（已裁剪为 PNG bytes）；为空时展示原图
  List<Uint8List> _figureImages = [];

  // OCR 上传后的图片 URL（MinIO），保存错题时用它而非本地临时路径
  String _uploadedImageUrl = '';

  // 知识点（按年级从后端拉取）
  List<KnowledgePoint> _availablePoints = const [];
  List<KnowledgePoint> _recommendedPoints = const [];
  bool _kpLoading = true;
  String? _kpError;

  // Step 3 data
  ErrorCategory? _selectedErrorCategory;
  List<String> _selectedSubCategories = [];
  final List<String> _customTags = [];
  final _tagController = TextEditingController();

  final _subCategoriesMap = {
    ErrorCategory.knowledge: ['概念混淆', '公式记错', '知识点遗忘'],
    ErrorCategory.skill: ['运算顺序错误', '计算失误', '单位换算错误'],
    ErrorCategory.psychology: ['紧张焦虑', '漏做题', '时间不够'],
    ErrorCategory.habit: ['审题不清', '抄写错误', '答题不规范'],
  };

  @override
  void initState() {
    super.initState();
    // 延后一帧，待 BlocProvider/AuthBloc 可读后再按年级拉取知识点
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadKnowledgePoints());
  }

  @override
  void dispose() {
    _ocrController.dispose();
    _myAnswerController.dispose();
    _correctAnswerController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  /// 按当前用户年级从后端拉取知识点
  Future<void> _loadKnowledgePoints() async {
    final authState = context.read<AuthBloc>().state;
    final grade = authState is Authenticated ? authState.user.grade : '';
    if (grade.isEmpty) {
      if (mounted) setState(() => _kpLoading = false);
      return;
    }
    setState(() {
      _kpLoading = true;
      _kpError = null;
    });
    try {
      final all = await sl<KnowledgePointRepository>().getByGrade(grade: grade);
      if (!mounted) return;
      setState(() {
        _availablePoints = all;
        _recommendedPoints = all.where((p) => p.isRecommended).toList();
        _kpLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kpError = '知识点加载失败，请检查网络';
        _kpLoading = false;
      });
    }
  }

  bool get _canProceedStep2 => _imagePath != null;

  bool get _canProceedStep3 => _selectedKnowledgePoints.isNotEmpty;

  bool get _canSave => _selectedErrorCategory != null;

  Future<void> _pickImage(ImageSource source) async {
    // Web 环境：使用模拟流程
    if (kIsWeb) {
      setState(() {
        _imagePath = 'demo_question.jpg';
        _originalImagePath = 'demo_question.jpg';
        _cropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
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

    // 原生环境：先检查权限
    final permission = source == ImageSource.camera
        ? Permission.camera
        : Permission.photos;

    final status = await permission.status;
    if (status.isDenied) {
      // 首次请求权限
      final result = await permission.request();
      if (!result.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要相机/相册权限才能拍照或选择图片'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    } else if (status.isPermanentlyDenied) {
      // 用户已永久拒绝，引导去系统设置
      if (!mounted) return;
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要权限'),
          content: Text(
            source == ImageSource.camera
                ? '错题猎手需要相机权限来拍照录入错题，请在系统设置中开启。'
                : '错题猎手需要相册权限来选择图片，请在系统设置中开启。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await openAppSettings();
      }
      return;
    }

    // 权限已授予，执行拍照/选图
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1920);

      if (pickedFile == null) {
        // 用户取消了选择，不提示
        return;
      }

      if (!mounted) return;

      // 使用自研交互式裁剪框（替代 image_cropper，避免真机崩溃）
      // 裁剪在用户点击"下一步"时执行（见 _nextStep 方法）
      final imagePath = pickedFile.path;

      // 读取图片真实尺寸（用于 BoxFit.contain 坐标转换）
      final imageSize = await _getImageSize(imagePath);

      setState(() {
        _imagePath = imagePath;
        _originalImagePath = imagePath; // 保留原始路径用于裁剪
        _cropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90); // 重置裁剪框
        _originalImageSize = imageSize;
      });
      // OCR 在用户裁剪后点击"下一步"时触发（见 _nextStep）
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
        // 归一化度数符号：OCR 常把 ° 误识别为 ^{。}，这里还原为 °
        _ocrController.text = normalizeMathText(state.text);
        // AI recommends error category based on content
        _recommendedCategory = ErrorCategory.skill;
        _figureImages = [];
        _uploadedImageUrl = state.imageUrl;
      });
      // 裁剪图形区域用于展示
      _loadFigureImages(state.figures);
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

  /// 把 OCR 识别到的图形区域从原图裁剪出来供展示
  Future<void> _loadFigureImages(List<OcrFigure> figures) async {
    if (_imagePath == null || figures.isEmpty) {
      if (mounted) setState(() => _figureImages = []);
      return;
    }
    final results = <Uint8List>[];
    for (final f in figures) {
      final bytes = await _cropRegionToBytes(
          _imagePath!, f.x, f.y, f.width, f.height);
      if (bytes != null) results.add(bytes);
    }
    if (mounted) setState(() => _figureImages = results);
  }

  /// 按像素坐标从图片裁剪区域 → PNG bytes
  Future<Uint8List?> _cropRegionToBytes(
      String path, int x, int y, int w, int h) async {
    if (kIsWeb || path == 'demo_question.jpg') return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final rx = x.clamp(0, image.width);
      final ry = y.clamp(0, image.height);
      final rw = w.clamp(0, image.width - rx);
      final rh = h.clamp(0, image.height - ry);
      if (rw <= 0 || rh <= 0) {
        image.dispose();
        return null;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(rx.toDouble(), ry.toDouble(), rw.toDouble(), rh.toDouble()),
        Rect.fromLTWH(0, 0, rw.toDouble(), rh.toDouble()),
        Paint(),
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(rw, rh);
      final bd = await cropped.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      cropped.dispose();
      picture.dispose();
      if (bd == null) return null;
      return bd.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1 && _imagePath != null && _originalImagePath != null) {
      // Step1 → Step2: 执行图片裁剪
      if (_isCropping) return;
      setState(() => _isCropping = true);

      try {
        final croppedPath = await _cropImage(_originalImagePath!, _cropRect);
        if (!mounted) return;
        setState(() {
          _imagePath = croppedPath;
          _isCropping = false;
          _currentStep = 2;
          _ocrStatus = OcrStatus.loading;
        });
        // 裁剪完成后，对裁剪后的图片触发 OCR 识别
        if (mounted) {
          context.read<QuestionBloc>().add(OcrImage(croppedPath));
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isCropping = false);
        // 裁剪失败时使用原图继续
        setState(() {
          _imagePath = _originalImagePath;
          _currentStep = 2;
        });
      }
    } else if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  /// 读取图片真实尺寸
  Future<Size?> _getImageSize(String path) async {
    if (kIsWeb || path == 'demo_question.jpg') return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  /// 根据裁剪比例裁剪图片并保存到临时文件
  ///
  /// 修复 Bug #2：cropRatio 现在是**图片坐标**（0~1，相对于图片实际像素）
  /// InteractiveCropFrame 已经处理了 BoxFit.contain 的容器坐标 → 图片坐标转换
  Future<String> _cropImage(String inputPath, Rect cropRatio) async {
    // Web 环境不执行真实裁剪
    if (kIsWeb || inputPath == 'demo_question.jpg') {
      return inputPath;
    }

    final file = File(inputPath);
    if (!await file.exists()) return inputPath;

    // 读取并解码图片
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // cropRatio 已经是图片坐标（0~1），直接计算像素级裁剪区域
    final srcRect = Rect.fromLTWH(
      (cropRatio.left * image.width).roundToDouble(),
      (cropRatio.top * image.height).roundToDouble(),
      (cropRatio.width * image.width).roundToDouble(),
      (cropRatio.height * image.height).roundToDouble(),
    );

    // 确保裁剪区域有效
    if (srcRect.width <= 0 || srcRect.height <= 0) {
      image.dispose();
      return inputPath;
    }

    // 使用 Canvas 裁剪
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromLTWH(0, 0, srcRect.width, srcRect.height),
      Paint(),
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      srcRect.width.round(),
      srcRect.height.round(),
    );

    // 编码为 PNG
    final croppedBytes = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    croppedImage.dispose();
    picture.dispose();

    if (croppedBytes == null) return inputPath;

    // 保存到临时文件
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/cropped_$timestamp.png';
    await File(outputPath).writeAsBytes(croppedBytes.buffer.asUint8List());

    return outputPath;
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  void _save() {
    if (!_canSave) return;

    context.read<QuestionBloc>().add(AddQuestion(
          // 优先用上传到对象存储的 URL；OCR 未上传成功时回退本地路径
          imageUrl: _uploadedImageUrl.isNotEmpty ? _uploadedImageUrl : (_imagePath ?? ''),
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
    // 玻璃拟态主题：背景为深色渐变，蓝色 brandPrimary 对比度不足，
    // 改用暖琥珀色作强调色（与 question_list_page.dart / profile_page.dart 一致）。
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
    return BlocConsumer<QuestionBloc, QuestionState>(
      listener: (context, state) {
        _onOcrStateChanged(state);
        if (state is QuestionAdded) {
          _onQuestionAdded();
        } else if (state is QuestionAddFailed) {
          EHToast.show(context,
              message: state.message, type: EHToastType.error);
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
            // ✅ 修复 Bug #4：必须显式设为 false，否则 Flutter 会自动添加 back 行为
            // 导致自定义 leading 的 × 按钮行为错乱，跳转后显示空白页
            automaticallyImplyLeading: false,
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
                    onTap: _isCropping ? null : () {
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
                      child: _isCropping
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            )
                          : Text(
                              '下一步',
                              style: AppTypography.primary.button.copyWith(
                                color: _isCropping
                                    ? accentColor.withOpacity(0.4)
                                    : accentColor,
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
      imagePath: _originalImagePath ?? _imagePath, // 显示原始图片供裁剪
      imageSize: _originalImageSize, // 传给 InteractiveCropFrame 做 BoxFit.contain 坐标转换
      onTakePhoto: () => _pickImage(ImageSource.camera),
      onPickFromGallery: () => _pickImage(ImageSource.gallery),
      onCropChanged: (rect) {
        setState(() => _cropRect = rect);
      },
    );
  }

  // ─── Step 2: Confirm Info ──────────────────────────────────

  Widget _buildStep2({Key? key}) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
                  border: Border.all(
                      color: isGlass
                          ? Colors.white.withOpacity(0.25)
                          : AppColors.border,
                      width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Web 环境：显示 Mock 占位
                    if (kIsWeb || _imagePath == 'demo_question.jpg')
                      Container(
                        color: isGlass
                            ? Colors.white.withOpacity(0.12)
                            : AppColors.brandPrimaryPale,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined,
                                  size: 32, color: accentColor),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                '示例题目图片',
                                style: AppTypography.primary.body.copyWith(
                                  color: accentColor,
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
                          color: isGlass
                              ? Colors.white.withOpacity(0.12)
                              : AppColors.background,
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

          // 题目图形：OCR 识别到的图形区域裁剪展示；无图形坐标时展示原图
          if (_ocrStatus == OcrStatus.success) ...[
            SizedBox(height: AppSpacing.md),
            _buildFiguresSection(tc),
          ],

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

          // Knowledge points（按当前用户年级从后端拉取）
          if (_kpLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: accentColor,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_kpError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kpError!,
                  style: AppTypography.primary.caption
                      .copyWith(color: AppColors.danger),
                ),
                SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: _loadKnowledgePoints,
                  child: Text(
                    '重试',
                    style: AppTypography.primary.caption.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            KnowledgePointSelector(
              selectedPoints: _selectedKnowledgePoints,
              onChanged: (points) =>
                  setState(() => _selectedKnowledgePoints = points),
              recommendedPoints: _recommendedPoints,
              availablePoints: _availablePoints,
            ),

          SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ─── 题目图形展示 ─────────────────────────────────────────

  Widget _buildFiguresSection(dynamic tc) {
    final isGlass = context.themeExt.isDarkBackground;
    final borderColor =
        isGlass ? Colors.white.withOpacity(0.25) : AppColors.border;
    final labelStyle = AppTypography.primary.caption.copyWith(
      color: tc.secondary,
      fontWeight: FontWeight.w500,
    );
    // 有裁剪出的图形区域 → 展示
    if (_figureImages.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('题目图形', style: labelStyle),
          SizedBox(height: AppSpacing.xs),
          ..._figureImages.map((bytes) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: borderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              )),
        ],
      );
    }
    // 无图形坐标（线条几何图/坐标系等 OCR 无法定位）→ 展示原图供查看
    if (_imagePath != null &&
        _imagePath != 'demo_question.jpg' &&
        !kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('题目原图', style: labelStyle),
          SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(File(_imagePath!), fit: BoxFit.contain),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // ─── Step 3: Error Category & Save ─────────────────────────

  Widget _buildStep3(QuestionState state, {Key? key}) {
    final tc = context.textColors;
    final isGlass = context.themeExt.isDarkBackground;
    final accentColor =
        isGlass ? const Color(0xFFFFB74D) : AppColors.brandPrimary;
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
                          color: accentColor.withOpacity(isGlass ? 0.2 : 0.1),
                          borderRadius: AppRadius.radiusFull,
                          border: isGlass
                              ? Border.all(color: accentColor.withOpacity(0.5))
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tag,
                                style: AppTypography.primary.caption.copyWith(
                                  color: accentColor,
                                )),
                            SizedBox(width: AppSpacing.xs),
                            GestureDetector(
                              onTap: () => setState(() => _customTags.remove(tag)),
                              child: Icon(Icons.close, size: 14, color: accentColor),
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
                          border: Border.all(
                              color: isGlass
                                  ? Colors.white.withOpacity(0.25)
                                  : AppColors.border,
                              style: BorderStyle.solid),
                          color: isGlass
                              ? Colors.white.withOpacity(0.12)
                              : null,
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
