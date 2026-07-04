import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import 'xuegong_service.dart';
import 'webview_xuegong_page.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class StuInfoPage extends StatelessWidget {
  final SharedHttpClient client;

  const StuInfoPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('个人信息'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _yibinBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 40, color: _yibinBlue),
                ),
                const SizedBox(height: 24),
                const Text(
                  '个人信息需在学工系统中查看',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  '请在学工系统中登录后查看个人信息（成长档案）',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.language_rounded, size: 20),
                    label: const Text('在应用内打开'),
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

  Future<void> _openBrowser(BuildContext context) async {
    final service = XuegongService();
    final ok = await service.openInBrowser();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器，请手动访问学工系统')),
      );
    }
  }
}
