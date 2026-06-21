/// 错题猎手 - P9 PDF导出页
/// 流程：筛选 → 预览 → 生成 → 分享
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/buttons/primary_button.dart';
import '../../../widgets/common/cards/base_card.dart';
import '../../../widgets/common/dialogs/toast.dart';
import '../widgets/export_preview_card.dart';

/// 时间范围选项
enum _TimeRange { thisMonth, lastThreeMonths, all }

/// Mock 导出的错题数据
class _ExportQuestionItem {
  const _ExportQuestionItem({
    required this.id,
    required this.imageUrl,
    required this.errorCategory,
    required this.knowledgePoints,
    required this.createdAt,
    this.isOffline = false,
  });

  final String id;
  final String imageUrl;
  final String errorCategory;
  final List<String> knowledgePoints;
  final DateTime createdAt;
  final bool isOffline;
}

/// PDF导出页
class PdfExportPage extends StatefulWidget {
  const PdfExportPage({super.key});

  @override
  State<PdfExportPage> createState() => _PdfExportPageState();
}

class _PdfExportPageState extends State<PdfExportPage> {
  _TimeRange _selectedRange = _TimeRange.thisMonth;
  int _currentPage = 0;
  bool _isGenerating = false;
  late final PageController _pageController;

  // TODO: 替换为真实API调用 - 获取可导出的错题列表
  late final List<_ExportQuestionItem> _mockQuestions;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _mockQuestions = _generateMockData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_ExportQuestionItem> _generateMockData() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      return _ExportQuestionItem(
        id: 'q_${i + 1}',
        imageUrl: 'https://placeholder.com/question_${i + 1}.png',
        errorCategory: ['KNOWLEDGE', 'SKILL', 'PSYCHOLOGY', 'HABIT'][i % 4],
        knowledgePoints: [
          ['分数运算', '小数乘法', '几何面积', '方程求解'][i % 4],
          if (i % 3 == 0) '应用题',
        ],
        createdAt: now.subtract(Duration(days: i * 3)),
        isOffline: i == 2 || i == 7, // 模拟2道离线题
      );
    });
  }

  List<_ExportQuestionItem> get _filteredQuestions {
    final now = DateTime.now();
    switch (_selectedRange) {
      case _TimeRange.thisMonth:
        return _mockQuestions
            .where((q) =>
                q.createdAt.month == now.month &&
                q.createdAt.year == now.year)
            .toList();
      case _TimeRange.lastThreeMonths:
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        return _mockQuestions
            .where((q) => q.createdAt.isAfter(threeMonthsAgo))
            .toList();
      case _TimeRange.all:
        return _mockQuestions;
    }
  }

  int get _offlineCount => _filteredQuestions.where((q) => q.isOffline).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuestions;
    final totalPages = filtered.isEmpty ? 1 : filtered.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '导出PDF',
          style: AppTypography.primary.h3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 时间范围选择 ──────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.base,
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.sm,
              ),
              child: EHBaseCard(
                padding: AppSpacing.cardInnerPadding,
                child: Row(
                  children: _TimeRange.values.map((range) {
                    final isSelected = _selectedRange == range;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRange = range;
                          _currentPage = 0;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: AppRadius.radiusMd,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : AppColors.textTertiary,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                _rangeLabel(range),
                                style: AppTypography.primary.caption.copyWith(
                                  color: isSelected
                                      ? AppColors.brandPrimary
                                      : AppColors.textSecondary,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ─── 离线提示 ────────────────────────────────
            if (_offlineCount > 0)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingHorizontal,
                  vertical: AppSpacing.sm,
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: AppColors.warning),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '⚠️ $_offlineCount道题图片待同步，将显示占位图',
                          style: AppTypography.primary.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── 预览区 PageView ─────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 64, color: AppColors.textTertiary),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            '暂无错题可导出',
                            style: AppTypography.primary.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            itemCount: filtered.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            controller: _pageController,
                            itemBuilder: (context, index) {
                              final q = filtered[index];
                              return ExportPreviewCard(
                                imageUrl: q.imageUrl,
                                errorCategory: q.errorCategory,
                                knowledgePoints: q.knowledgePoints,
                                isOffline: q.isOffline,
                              );
                            },
                          ),
                        ),
                        // 页码指示器
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          child: Text(
                            'Page ${_currentPage + 1}/$totalPages',
                            style: AppTypography.primary.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // ─── 底部生成按钮 ────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.sm,
                AppSpacing.pagePaddingHorizontal,
                AppSpacing.base,
              ),
              child: _buildGenerateButton(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(List<_ExportQuestionItem> filtered) {
    // 0道时置灰
    if (filtered.isEmpty) {
      return EHPrimaryButton(
        text: '暂无错题可导出',
        onPressed: null,
        size: EHButtonSize.lg,
        fullWidth: true,
        enabled: false,
      );
    }

    // >50道提示
    if (filtered.length > 50) {
      return EHPrimaryButton(
        text: '最多选择50道',
        onPressed: () {
          EHToast.show(context,
              message: '一次最多导出50道错题，请缩小时间范围',
              type: EHToastType.warning);
        },
        size: EHButtonSize.lg,
        fullWidth: true,
        enabled: false,
      );
    }

    return EHPrimaryButton(
      text: '📄 生成PDF并分享',
      onPressed: _handleGenerate,
      size: EHButtonSize.lg,
      fullWidth: true,
      isLoading: _isGenerating,
    );
  }

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);

    // TODO: 替换为真实PDF生成逻辑
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isGenerating = false);

    if (!mounted) return;

    EHToast.show(context,
        message: 'PDF生成成功！正在打开分享...', type: EHToastType.success);

    // TODO: 调用 share_plus 唤起 Share Sheet
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _rangeLabel(_TimeRange range) {
    switch (range) {
      case _TimeRange.thisMonth:
        return '本月';
      case _TimeRange.lastThreeMonths:
        return '近3个月';
      case _TimeRange.all:
        return '全部';
    }
  }
}
