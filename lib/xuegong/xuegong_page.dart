import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import 'xuegong_service.dart';
import 'webview_xuegong_page.dart';
import 'xuegong_extract_page.dart';
import 'xuegong_http_test_page.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class XuegongPage extends StatelessWidget {
  final SharedHttpClient client;

  const XuegongPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('学工系统'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _yibinBlue.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _yibinBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded,
                          size: 28, color: _yibinBlue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '学生管理服务平台',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ybxyxsglxt.yibinu.edu.cn',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '说明',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '学工系统由于安全限制，无法直接通过 HTTP 请求获取数据。\n'
                  '已支持 CAS 单点登录（SSO），使用智慧校园的登录状态自动认证。\n\n'
                  '可查看：\n'
                  '• 个人信息（成长档案）\n'
                  '• 综合素质\n'
                  '• 家庭成员信息\n'
                  '• 教育经历\n'
                  '• 家庭经济情况\n'
                  '• 国家奖学金/励志奖学金\n'
                  '• 荣誉称号 等',
                  style: TextStyle(
                      fontSize: 14, height: 1.6, color: Colors.grey[700]),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.language_rounded, size: 20),
                label: const Text('在应用内打开（内置浏览器）'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _yibinBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openInApp(context),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.travel_explore_rounded, size: 20),
                label: const Text('后台提取数据'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal[700],
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openExtract(context),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.science_rounded, size: 20),
                label: const Text('HTTP 模式测试（实验性）'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange[800],
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openHttpTest(context),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_browser, size: 20),
                label: const Text('在外部浏览器中打开'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _yibinBlue,
                  side: BorderSide(color: _yibinBlue.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openBrowser(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInApp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebViewXuegongPage(client: client)),
    );
  }

  void _openHttpTest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => XuegongHttpTestPage(client: client)),
    );
  }

  void _openExtract(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => XuegongExtractPage(client: client)),
    );
  }

  Future<void> _openBrowser(BuildContext context) async {
    final service = XuegongService();
    final ok = await service.openInBrowser();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法打开浏览器，请手动访问:\n${service.portalUrl}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
