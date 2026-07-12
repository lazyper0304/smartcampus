import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../news/webview_page.dart';
import '../core/navigation.dart';
import '../core/theme_utils.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const Color _accentGreen = Color.fromRGBO(46, 125, 50, 1);
const Color _accentOrange = Color.fromRGBO(230, 126, 34, 1);

class NetworkServiceItem {
  final IconData icon;
  final String name;
  final String? detail;
  final String? url;
  final Color? color;

  const NetworkServiceItem({
    required this.icon,
    required this.name,
    this.detail,
    this.url,
    this.color,
  });
}

class NetworkServicePage extends StatelessWidget {
  const NetworkServicePage({super.key});

  static final _services = [
    _Category('校园网 & 教室多媒体', Icons.wifi_rounded, accentColorNotifier.value, [
      NetworkServiceItem(
        icon: Icons.school_rounded,
        name: '校园网服务',
        detail: '临港一期 0831-3583376\n临港二期 0831-8235303\nA区一平台 0831-3545009\nA区二、三平台 0831-3530932\nB区 0831-3545323',
        url: 'https://nm.yibinu.edu.cn/xywfw.htm',
      ),
      NetworkServiceItem(
        icon: Icons.meeting_room_rounded,
        name: '多媒体服务',
        detail: '教室多媒体设备与系统软件维护',
        url: 'https://nm.yibinu.edu.cn/dmtjsfw.htm',
      ),
    ]),
    _Category('智慧校园 & 网络安全', Icons.security_rounded, _accentGreen, [
      NetworkServiceItem(
        icon: Icons.dashboard_customize_rounded,
        name: '智慧校园平台',
        url: 'https://ehall.yibinu.edu.cn/',
      ),
      NetworkServiceItem(
        icon: Icons.vpn_key_rounded,
        name: 'VPN 服务',
        detail: '服务电话 0831-8227212',
        url: 'https://nm.yibinu.edu.cn/VPNfw.htm',
      ),
      NetworkServiceItem(
        icon: Icons.alternate_email_rounded,
        name: '电子邮箱',
        detail: 'mail.yibinu.edu.cn',
        url: 'http://mail.yibinu.edu.cn/',
      ),
      NetworkServiceItem(
        icon: Icons.document_scanner_rounded,
        name: 'OA 办公系统',
        url: 'https://oa.yibinu.edu.cn/',
      ),
      NetworkServiceItem(
        icon: Icons.cloud_rounded,
        name: '虚拟机服务',
        url: 'https://nm.yibinu.edu.cn/xnjfw.htm',
      ),
    ]),
    _Category('网站服务', Icons.language_rounded, Colors.purple, [
      NetworkServiceItem(
        icon: Icons.web_rounded,
        name: '网站服务',
        detail: '新建网站、样式改动、栏目调整、账号密码修改等\n服务电话 0831-2201506',
        url: 'https://nm.yibinu.edu.cn/wzfw.htm',
      ),
      NetworkServiceItem(
        icon: Icons.admin_panel_settings_rounded,
        name: '网站管理平台',
        url: 'https://web.yibinu.edu.cn/system/login.jsp',
      ),
    ]),
    _Category('一卡通 & 正版软件', Icons.credit_card_rounded, _accentOrange, [
      NetworkServiceItem(
        icon: Icons.credit_card_rounded,
        name: '校园一卡通',
        detail: '新办、补办、挂失、解冻\nA区、B区 0831-3556904\n临港校区 0831-3583788',
        url: 'https://nm.yibinu.edu.cn/yktzzfw1.htm',
      ),
      NetworkServiceItem(
        icon: Icons.download_rounded,
        name: '正版软件平台',
        detail: 'Office / Windows 正版下载与激活',
        url: 'https://ms.yibinu.edu.cn/',
      ),
      NetworkServiceItem(
        icon: Icons.ondemand_video_rounded,
        name: '智慧教学平台',
        url: 'https://mooc.yibinu.edu.cn/',
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('网络服务'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            for (final cat in _services) ...[
              _buildCategory(context, cat),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColorNotifier.value.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded,
                  color: accentColorNotifier.value, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('信息中心网络服务一览表',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('宜宾学院信息中心',
                      style: TextStyle(
                          fontSize: 12, color: textSecondary(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, _Category cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: cat.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(cat.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cat.color)),
            ],
          ),
        ),
        ...cat.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildServiceCard(context, item, cat.color),
            )),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, NetworkServiceItem item, Color categoryColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: categoryColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (item.url == null || item.url!.isEmpty) return;
          if (item.url!.contains('yibinu.edu.cn') &&
              !item.url!.contains('ms.yibinu') &&
              !item.url!.contains('mail.yibinu') &&
              !item.url!.contains('vpn.yibinu') &&
              !item.url!.contains('oa.yibinu') &&
              !item.url!.contains('web.yibinu')) {
            pushPage(
              context,
              WebViewPage(url: item.url!, title: '网络服务'));
          } else {
            launchUrl(Uri.parse(item.url!),
                mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (item.color ?? categoryColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon,
                    size: 20,
                    color: item.color ?? categoryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    if (item.detail != null) ...[
                      const SizedBox(height: 4),
                      Text(item.detail!,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary(context),
                            height: 1.4,
                          )),
                    ],
                  ],
                ),
              ),
              if (item.url != null)
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: textHint(context)),
            ],
          ),
        ),
      ),
    );
  }

}

class _Category {
  final String name;
  final IconData icon;
  final Color color;
  final List<NetworkServiceItem> items;

  const _Category(this.name, this.icon, this.color, this.items);
}
