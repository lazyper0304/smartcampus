import 'package:flutter/material.dart';

import '../core/theme_utils.dart';
import '../core/version.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 隐私协议页面 — 说明本应用如何收集、存储与使用用户数据
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: const Text('隐私协议')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildIntro(context),
            const SizedBox(height: 16),
            _buildSection(context, '一、我们收集的信息', [
              '学号/工号与密码：用于通过学校统一身份认证（CAS）登录，以访问课表、成绩、学科竞赛等学校官方服务。',
              '会话凭证（Cookie / Token）：登录后由学校系统下发，保存在本机用于维持登录状态、避免重复输入账号密码。',
            ]),
            _buildSection(context, '二、信息的存储', [
              '您的账号与密码仅保存在本机沙盒存储（LocalStorage）中，不会上传至开发者或任何第三方服务器。',
              '仅当您在登录页勾选「记住密码」时，账号密码才会被本地留存；未勾选则退出后不保留。',
              '您可随时在「设置 → 账号 → 退出登录」中清除全部本地登录信息与会话凭证。',
            ]),
            _buildSection(context, '三、信息的使用', [
              '账号密码仅用于向学校统一认证系统发起登录请求，凭据本身不会离开您的设备。',
              '会话凭证仅用于访问学校官方接口（如教务、学工、学科竞赛系统等），以获取您本人授权的数据。',
              '我们不会将您的个人信息用于广告、营销或与本应用功能无关的任何用途。',
            ]),
            _buildSection(context, '四、数据来源与版权', [
              '课表、成绩、竞赛等数据均来自宜宾学院官方系统，数据的版权归学校所有。',
              '本应用为第三方非官方客户端，与学校无任何隶属或合作关系，仅供学习交流使用。',
            ]),
            _buildSection(context, '五、您的权利', [
              '您可随时退出登录以清除本地会话；卸载应用将一并删除本机所有相关数据。',
              '如对本协议或数据处理有任何疑问，可通过应用「关于 → 作者」联系开发者。',
            ]),
            _buildSection(context, '六、免责声明', [
              '使用本应用所产生的任何风险由用户自行承担；因学校系统变动、网络或账号问题导致的服务异常，开发者不承担责任。',
              '本协议随应用版本更新可能调整，最新条款以本页面为准。',
            ]),
            const SizedBox(height: 12),
            Center(
              child: Text('当前版本 v$appVersion',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Card(
      elevation: 0,
      // color 不传：跟随全局 cardTheme 静态玻璃（半透明白/深灰）
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.privacy_tip_outlined,
                color: accentColorNotifier.value, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '我们重视您的隐私。本应用仅在本地处理登录所需的信息，不会将您的账号密码上传至任何外部服务器。',
                style: TextStyle(fontSize: 13, height: 1.5, color: textSecondary(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> paragraphs) {
    return Card(
      elevation: 0,
      // color 不传：跟随全局 cardTheme 静态玻璃（半透明白/深灰）
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...paragraphs.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('· $p',
                      style: TextStyle(
                          fontSize: 13, height: 1.6, color: textSecondary(context))),
                )),
          ],
        ),
      ),
    );
  }
}
