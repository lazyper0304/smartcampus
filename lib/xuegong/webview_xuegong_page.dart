import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../core/http_client.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


/// 内置浏览器学工系统页面
///
/// 利用 CAS SSO 机制：从 SharedHttpClient 获取已有的 authserver cookie (CASTGC)，
/// 注入 WebView 的 cookie 存储，实现免重新输入密码的单点登录。
class WebViewXuegongPage extends StatefulWidget {
  final SharedHttpClient client;

  const WebViewXuegongPage({super.key, required this.client});

  @override
  State<WebViewXuegongPage> createState() => _WebViewXuegongPageState();
}

class _WebViewXuegongPageState extends State<WebViewXuegongPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isLoading = false;
  bool _cookiesReady = false;
  bool _cookieInjectionFailed = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentTitle = '学工系统';

  // ── 快速导航地址 ──
  static const String _baseUrl = 'https://ybxyxsglxt.yibinu.edu.cn';
  static const String _loginUrl = '$_baseUrl/wiseduIndex.jsp';
  static const String _stuInfoUrl = '$_baseUrl/syt/xsinfo/stuinfo.htm';
  static const String _zhszUrl = '$_baseUrl/syt/xsinfo/zhsz.htm';

  @override
  void initState() {
    super.initState();
    _injectCookies();
  }

  /// 从 SharedHttpClient 获取 CAS cookie 并注入 WebView cookie 存储
  Future<void> _injectCookies() async {
    try {
      final allCookies = widget.client.getAllCookies();
      final cookieManager = CookieManager.instance();

      // 注入主要域的 cookie
      for (final domain in [
        'authserver.yibinu.edu.cn',
        'ybxyxsglxt.yibinu.edu.cn',
      ]) {
        final cookies = allCookies[domain];
        if (cookies != null && cookies.isNotEmpty) {
          for (final entry in cookies.entries) {
            await cookieManager.setCookie(
              url: WebUri('https://$domain/'),
              name: entry.key,
              value: entry.value,
              domain: domain,
              path: '/',
              isSecure: true,
            );
          }
        }
      }

      // 也注入 yibinu.edu.cn 父域的 cookie（如 CASTGC 等）
      final yibinuCookies = allCookies['yibinu.edu.cn'];
      if (yibinuCookies != null && yibinuCookies.isNotEmpty) {
        for (final entry in yibinuCookies.entries) {
          await cookieManager.setCookie(
            url: WebUri('https://yibinu.edu.cn/'),
            name: entry.key,
            value: entry.value,
            domain: '.yibinu.edu.cn',
            path: '/',
            isSecure: true,
          );
        }
      }

      if (mounted) {
        setState(() => _cookiesReady = true);
      }
    } catch (e) {
      debugPrint('Cookie injection error: $e');
      if (mounted) {
        setState(() {
          _cookieInjectionFailed = true;
          _cookiesReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentTitle.length > 15
                ? '${_currentTitle.substring(0, 15)}…'
                : _currentTitle,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller?.reload(),
              tooltip: '刷新',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => _handleMenuAction(v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'open_browser',
                  child: ListTile(
                    leading: Icon(Icons.open_in_browser, size: 20),
                    title: Text('在外部浏览器打开'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'extract_page',
                  child: ListTile(
                    leading: Icon(Icons.data_exploration_rounded, size: 20),
                    title: Text('提取当前页面数据'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_cache',
                  child: ListTile(
                    leading: Icon(Icons.cleaning_services_rounded, size: 20),
                    title: Text('清除缓存'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _cookiesReady ? _buildWebView(isDark) : _buildLoading(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(accentColorNotifier.value),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _cookieInjectionFailed ? '加载中…' : '同步登录状态…',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          if (_cookieInjectionFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Cookie 注入失败，可能需要手动登录',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebView(bool isDark) {
    return Column(
      children: [
        // ── 加载进度条 ──
        if (_isLoading)
          SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: accentColorNotifier.value.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentColorNotifier.value),
            ),
          ),

        // ── InAppWebView ──
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_loginUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useWideViewPort: true,
              supportZoom: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/120.0.0.0 Safari/537.36',
            ),
            onWebViewCreated: (ctrl) => _controller = ctrl,
            onLoadStart: (ctrl, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (ctrl, url) async {
              _updateNavState(ctrl);
              final title = await ctrl.getTitle();
              if (title != null && title.isNotEmpty && mounted) {
                setState(() => _currentTitle = title);
              }
              setState(() => _isLoading = false);
            },
            onProgressChanged: (ctrl, p) {
              setState(() => _progress = p / 100.0);
            },
            onTitleChanged: (ctrl, t) {
              if (t != null && t.isNotEmpty && mounted) {
                setState(() => _currentTitle = t);
              }
            },
            shouldOverrideUrlLoading: (ctrl, navAction) async {
              return NavigationActionPolicy.ALLOW;
            },
            onPermissionRequest: (ctrl, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onReceivedError: (ctrl, req, err) {
              debugPrint('WebView error: ${err.type} - ${err.description}');
            },
          ),
        ),

        // ── 底部工具栏 ──
        _buildBottomToolbar(isDark),
      ],
    );
  }

  Widget _buildBottomToolbar(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E1E32) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.15)),
        ),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            icon: Icons.arrow_back_ios_rounded,
            label: '后退',
            enabled: _canGoBack,
            onTap: () => _controller?.goBack(),
          ),
          _ToolbarButton(
            icon: Icons.arrow_forward_ios_rounded,
            label: '前进',
            enabled: _canGoForward,
            onTap: () => _controller?.goForward(),
          ),
          _ToolbarButton(
            icon: Icons.home_rounded,
            label: '首页',
            enabled: true,
            onTap: () => _loadUrl(_loginUrl),
          ),
          _ToolbarButton(
            icon: Icons.person_rounded,
            label: '个人信息',
            enabled: true,
            onTap: () => _loadUrl(_stuInfoUrl),
          ),
          _ToolbarButton(
            icon: Icons.star_rounded,
            label: '综合素质',
            enabled: true,
            onTap: () => _loadUrl(_zhszUrl),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'open_browser':
        _openInExternalBrowser();
      case 'extract_page':
        _extractPageData();
      case 'clear_cache':
        _clearCache();
    }
  }

  Future<void> _openInExternalBrowser() async {
    if (_controller == null) return;
    final url = await _controller!.getUrl();
    if (url != null) {
      try {
        await url_launcher.launchUrl(
          url as Uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      } catch (_) {
        if (mounted) _showSnackBar('请在外部浏览器手动访问此页面');
      }
    }
  }

  Future<void> _extractPageData() async {
    if (_controller == null) return;

    final js = '''
(function() {
  var tables = document.querySelectorAll('table');
  var result = [];
  for (var t = 0; t < tables.length; t++) {
    var rows = tables[t].querySelectorAll('tr');
    var tableData = [];
    for (var r = 0; r < rows.length; r++) {
      var cells = rows[r].querySelectorAll('td, th');
      var rowData = [];
      for (var c = 0; c < cells.length; c++) {
        rowData.push(cells[c].textContent.trim());
      }
      if (rowData.length > 0) tableData.push(rowData);
    }
    if (tableData.length > 0) result.push(tableData);
  }
  var contentDivs = document.querySelectorAll('.content, .main, .info, #content, #main, .article, .detail');
  var texts = [];
  for (var i = 0; i < contentDivs.length; i++) {
    var clone = contentDivs[i].cloneNode(true);
    var scripts = clone.querySelectorAll('script, style');
    for (var s = 0; s < scripts.length; s++) scripts[s].remove();
    texts.push(clone.textContent.trim().replace(/\\\\s+/g, ' '));
  }
  return JSON.stringify({ title: document.title || '', url: location.href, tables: result, texts: texts });
})();
''';

    try {
      final raw = await _controller!.evaluateJavascript(source: js);
      if (raw is String && mounted) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _showExtractedData(data);
      } else {
        _showSnackBar('未能提取到数据，页面可能未完全加载');
      }
    } catch (e) {
      _showSnackBar('提取数据失败: $e');
    }
  }

  void _showExtractedData(Map<String, dynamic> data) {
    if (!mounted) return;
    final title = data['title'] as String? ?? '页面数据';
    final tables = data['tables'] as List? ?? [];
    final texts = data['texts'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: accentColorNotifier.value.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.data_exploration_rounded, size: 18, color: accentColorNotifier.value),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title.length > 30 ? '${title.substring(0, 30)}…' : title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  const Spacer(),
                  Text('${tables.length} 个表格', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ]),
                const SizedBox(height: 16),
                Expanded(child: ListView(controller: scrollCtrl, children: [
                  if (texts.isNotEmpty) ...[
                    _sectionHeader('文本内容'), const SizedBox(height: 8),
                    ...texts.take(3).map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08))),
                      child: Padding(padding: const EdgeInsets.all(12), child: Text(t.toString(), style: const TextStyle(fontSize: 13, height: 1.5))),
                    ))),
                    const SizedBox(height: 16),
                  ],
                  if (tables.isNotEmpty) ...[
                    _sectionHeader('表格数据'), const SizedBox(height: 8),
                    ...tables.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final rows = entry.value as List;
                      return Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08))),
                        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('表格 $idx（${rows.length} 行）', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ...rows.take(15).map((row) {
                            final cells = row as List<dynamic>;
                            return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(cells.join('  |  '), style: const TextStyle(fontSize: 12, fontFamily: 'monospace')));
                          }),
                          if (rows.length > 15) Padding(padding: const EdgeInsets.only(top: 4),
                              child: Text('… 还有 ${rows.length - 15} 行', style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
                        ])),
                      ));
                    }),
                  ],
                  if (tables.isEmpty && texts.isEmpty)
                    Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Column(children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('未提取到结构化数据', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                      Text('请在登录后访问个人信息或综合素质页面再提取', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ]))),
                ])),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(color: accentColorNotifier.value, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }

  Future<void> _clearCache() async {
    await InAppWebViewController.clearAllCache(includeDiskFiles: true);
    if (mounted) _showSnackBar('缓存已清除');
  }

  Future<void> _updateNavState(InAppWebViewController ctrl) async {
    final back = await ctrl.canGoBack();
    final forward = await ctrl.canGoForward();
    if (mounted) setState(() { _canGoBack = back; _canGoForward = forward; });
  }

  void _loadUrl(String url) => _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// ── 底部工具栏按钮 ──
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: accentColorNotifier.value.withValues(alpha: enabled ? 0.08 : 0.03),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: enabled ? accentColorNotifier.value : Colors.grey),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: enabled ? accentColorNotifier.value : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
