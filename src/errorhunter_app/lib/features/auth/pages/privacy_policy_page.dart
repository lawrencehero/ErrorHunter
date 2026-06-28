/// 错题猎手 - 隐私政策页面
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '隐私政策',
          style: AppTypography.primary.h3.copyWith(color: tc.primary),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO: 替换为正式法律文本
            Text(
              '错题猎手隐私政策',
              style: AppTypography.primary.h2.copyWith(color: tc.primary),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '最后更新日期：2024年1月1日\n生效日期：2024年1月1日',
              style: AppTypography.primary.caption.copyWith(color: tc.tertiary),
            ),
            SizedBox(height: AppSpacing.lg),
            _section(tc, '一、信息收集',
              '我们仅收集提供服务所必需的信息，包括：手机号码（用于注册登录）、年级信息（用于个性化推荐）、错题图片和文字内容（用于错题管理功能）。'),
            _section(tc, '二、信息使用',
              '我们收集的信息仅用于以下目的：提供错题录入和管理服务、生成个性化复习计划、改善产品体验。我们不会将用户信息用于任何商业营销目的。'),
            _section(tc, '三、未成年人保护',
              '本产品主要面向未成年学生。我们高度重视未成年人个人信息保护。未成年用户应在监护人的指导下使用本产品。监护人有权随时查看、修改或删除被监护人的个人信息。'),
            _section(tc, '四、信息安全',
              '我们采取合理的技术和管理措施保护用户信息安全，包括但不限于数据加密传输、访问控制、定期安全审计等。'),
            _section(tc, '五、信息共享',
              '未经用户或监护人同意，我们不会向第三方共享用户个人信息，法律法规另有规定的除外。'),
            _section(tc, '六、用户权利',
              '用户及其监护人有权查看、修改、删除个人信息，也有权注销账号。如需行使上述权利，请通过应用内"账号管理"功能操作或联系客服。'),
            _section(tc, '七、联系方式',
              '如对本隐私政策有任何疑问，请通过应用内的意见反馈功能联系我们。'),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _section(AppTextThemeColors tc, String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.primary.h3.copyWith(color: tc.primary),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: AppTypography.primary.body.copyWith(color: tc.secondary),
          ),
        ],
      ),
    );
  }
}
