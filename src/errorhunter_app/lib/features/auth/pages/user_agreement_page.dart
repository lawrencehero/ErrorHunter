/// 错题猎手 - 用户协议页面
library;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../theme/theme_manager.dart';

class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.textColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '用户协议',
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
              '错题猎手用户服务协议',
              style: AppTypography.primary.h2.copyWith(color: tc.primary),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '最后更新日期：2024年1月1日\n生效日期：2024年1月1日',
              style: AppTypography.primary.caption.copyWith(color: tc.tertiary),
            ),
            SizedBox(height: AppSpacing.lg),
            _section(tc, '一、总则',
              '欢迎使用错题猎手（以下简称"本产品"）。本产品的目标是帮助小学3-6年级及初中学生进行错题管理和复习。使用本产品前，请仔细阅读本协议的全部内容。'),
            _section(tc, '二、服务内容',
              '本产品为用户提供错题拍照录入、错因分析、知识点归类、智能复习计划等功能。具体服务内容以产品实际提供的为准。'),
            _section(tc, '三、用户注册与账号安全',
              '用户应提供真实有效的手机号码进行注册。用户应妥善保管自己的账号信息，因用户个人原因导致的账号安全问题由用户自行承担。未成年人应在监护人的指导下使用本产品。'),
            _section(tc, '四、用户行为规范',
              '用户在使用本产品时应遵守国家法律法规，不得利用本产品从事违法违规活动。用户上传的内容应合法合规，不得包含不良信息。'),
            _section(tc, '五、知识产权',
              '本产品中的所有内容（包括但不限于文字、图片、软件、音频、视频等）的知识产权归本产品所有。用户上传的错题内容版权归用户所有。'),
            _section(tc, '六、免责声明',
              '本产品不对因不可抗力、系统维护等原因导致的服务中断承担责任。本产品提供的学习建议仅供参考，不构成教育指导。'),
            _section(tc, '七、协议修改',
              '我们有权根据需要修改本协议内容，修改后的协议将在产品上公布后立即生效。继续使用本产品即视为同意修改后的协议。'),
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
