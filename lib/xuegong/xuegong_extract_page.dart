import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import 'xuegong_data_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

/// 学工系统数据提取测试页面
///
/// 使用 HeadlessInAppWebView 后台自动登录并提取页面内容。
class XuegongExtractPage extends StatefulWidget {
  final SharedHttpClient client;

  const XuegongExtractPage({super.key, required this.client});

  @override
  State<XuegongExtractPage> createState() => _XuegongExtractPageState();
}

class _XuegongExtractPageState extends State<XuegongExtractPage> {
  bool _running = false;
  String _result = '';
  String? _error;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('数据提取'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _yibinBlue.withValues(alpha: 0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _yibinBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.travel_explore_rounded, size: 18, color: _yibinBlue),
                        ),
                        const SizedBox(width: 10),
                        const Text('后台 WebView 提取',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        '使用 HeadlessInAppWebView 在后台加载学工系统，\n'
                        '自动注入 SSO Cookie → JavaScript 自动登录\n'
                        '→ 导航到目标页面 → 注入 JS 提取 HTML',
                        style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 目标 URL 按钮
              const Text('目标页面', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildTargetButton('个人信息',
                  'https://ybxyxsglxt.yibinu.edu.cn/syt/xsinfo/stuinfo.htm'),
              const SizedBox(height: 6),
              _buildTargetButton('综合素质',
                  'https://ybxyxsglxt.yibinu.edu.cn/syt/xsinfo/zhsz.htm'),

              const SizedBox(height: 20),

              // 状态和按钮
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_status,
                      style: TextStyle(fontSize: 13, color: _yibinBlue)),
                ),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  icon: _running
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(_running ? '提取中…' : '开始提取'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _yibinBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _running ? null : () => _extract(),
                ),
              ),

              // 错误
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(_error!,
                            style: const TextStyle(fontSize: 12, color: Colors.red, fontFamily: 'monospace')),
                      ),
                    ]),
                  ),
                ),
              ],

              // 结果
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 4, height: 16,
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  const Text('提取数据',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: _yibinBlue.withValues(alpha: 0.1)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _result,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetButton(String label, String url) {
    return InkWell(
      onTap: () => _extract(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _yibinBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _yibinBlue.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _yibinBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 10, color: _yibinBlue, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(url, style: TextStyle(fontSize: 10, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  Future<void> _extract([String? url]) async {
    setState(() {
      _running = true;
      _result = '';
      _error = null;
      _status = '注入 Cookie…';
    });

    try {
      final service = XuegongDataService(widget.client);
      final targetUrl = url ?? 'https://ybxyxsglxt.yibinu.edu.cn/syt/xsinfo/stuinfo.htm';

      setState(() => _status = '后台 WebView 加载中（SSO 自动登录…）…');
      final data = await service.extractStructuredData(targetUrl);

      // 格式化为可读文本
      final buf = StringBuffer();
      for (final section in data.entries) {
        if (section.key.startsWith('_')) continue; // 跳过元数据
        buf.writeln('━━━ ${section.key} ━━━');
        if (section.value is Map) {
          for (final field in (section.value as Map).entries) {
            final val = field.value.toString();
            if (val.isNotEmpty && val != 'null') {
              buf.writeln('  ${field.key}: $val');
            }
          }
        }
        buf.writeln();
      }
      // 照片信息
      if (data['_photoUrl'] != null && (data['_photoUrl'] as String).isNotEmpty) {
        buf.writeln('━━━ 照片 ━━━');
        buf.writeln('  头像URL: ${data['_photoUrl']}');
        final bytes = data['_photoBytes'] as List<int>?;
        if (bytes != null && bytes.isNotEmpty) {
          buf.writeln('  头像大小: ${bytes.length} 字节（下载成功）');
        }
        buf.writeln();
      }

      if (mounted) {
        setState(() {
          _result = buf.toString();
          _running = false;
          _status = '提取完成';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _running = false;
          _status = '提取失败';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
