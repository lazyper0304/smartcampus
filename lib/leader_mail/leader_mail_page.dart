import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class _Mailbox {
  final String name;
  final String email;
  const _Mailbox(this.name, this.email);
}

/// 领导信箱：书记信箱 / 院长信箱
/// 校领导联系渠道。点击卡片复制邮箱地址，点击右侧按钮唤起邮件客户端发送。
const List<_Mailbox> _mailboxes = [
  _Mailbox('书记信箱', 'shuji@yibinu.edu.cn'),
  _Mailbox('院长信箱', 'yuanzhang@yibinu.edu.cn'),
];

class LeaderMailPage extends StatelessWidget {
  const LeaderMailPage({super.key});

  /// 复制邮箱并提示（同步，无 async gap）
  void _copyAndNotify(BuildContext context, String email) {
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制邮箱地址：$email'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // 无可用邮件客户端：复制邮箱并下一帧提示
    Clipboard.setData(ClipboardData(text: email));
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制邮箱地址：$email'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('领导信箱'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            for (final m in _mailboxes) ...[
              _buildMailCard(context, m),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              child: Icon(Icons.mark_email_unread_rounded,
                  color: accentColorNotifier.value, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('校领导信箱',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('欢迎来信反映问题、提出意见建议',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMailCard(BuildContext context, _Mailbox m) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copyAndNotify(context, m.email),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColorNotifier.value.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    m.name[0],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: accentColorNotifier.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(m.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              IconButton(
                tooltip: '发送邮件',
                onPressed: () => _sendMail(context, m.email),
                icon: Icon(Icons.send_rounded,
                    size: 20, color: accentColorNotifier.value),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
