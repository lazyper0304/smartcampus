import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../core/http_client.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'bohrium_service.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 玻尔科研平台（yibinu.bohrium.com）内置 WebView 页面
///
/// 利用 CAS SSO：从 SharedHttpClient 提取已登录 ehall 时持久化的
/// authserver cookie（CASTGC），注入 WebView 后免密码直接通过学校
/// 统一认证，进入 Bohrium 平台。
///
/// 兜底：若 CASTGC 已在服务端过期（WebView 停在 CAS 登录页），
/// 用户可在页面内直接输账号密码登录，由服务端 Set-Cookie 建立真实会话。
class BohriumPage extends StatefulWidget {
  final SharedHttpClient client;

  const BohriumPage({super.key, required this.client});

  @override
  State<BohriumPage> createState() => _BohriumPageState();
}

class _BohriumPageState extends State<BohriumPage> {
  late final BohriumService _service;
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isLoading = false;
  bool _cookiesReady = false;
  bool _cookieInjectionFailed = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentTitle = '玻尔科研';
  bool _onCasLogin = false;

  @override
  void initState() {
    super.initState();
    _service = BohriumService(client: widget.client);
    _injectCookies();
  }

  /// 注入 CAS cookie 到 WebView，完成后加载平台首页
  Future<void> _injectCookies() async {
    final cookieManager = CookieManager.instance();
    final count = await _service.injectCasCookiesToWebView(cookieManager);
    if (!mounted) return;
    setState(() {
      _cookiesReady = true;
      _cookieInjectionFailed = count == 0;
    });
  }

  /// 判断当前 URL 是否落在 CAS 登录页（cookie 失效或未登录）
  bool _isCasLoginUrl(String url) {
    return url.contains('authserver.yibinu.edu.cn')
        && url.contains('login');
  }

  @override
  Widget build(BuildContext context) {
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
              onSelected: _handleMenuAction,
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
        body: _cookiesReady ? _buildWebView() : _buildLoading(),
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
                '未检测到学校统一认证会话，可能需要手动登录',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
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

        // ── CAS 登录提示条（cookie 失效时引导手动登录）──
        if (_onCasLogin)
          Material(
            color: accentColorNotifier.value.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: accentColorNotifier.value),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '登录状态已过期，请在页面内输入账号密码登录',
                      style: TextStyle(
                          fontSize: 12, color: accentColorNotifier.value),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── InAppWebView ──
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(BohriumService.baseUrl)),
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
              final u = url?.toString() ?? '';
              if (mounted && _isCasLoginUrl(u) != _onCasLogin) {
                setState(() => _onCasLogin = _isCasLoginUrl(u));
              }
              setState(() => _isLoading = true);
            },
            onLoadStop: (ctrl, url) async {
              _updateNavState(ctrl);
              final title = await ctrl.getTitle();
              if (title != null && title.isNotEmpty && mounted) {
                setState(() => _currentTitle = title);
              }
              if (mounted) setState(() => _isLoading = false);
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
            // 拦截 JS 弹窗（如 SSO 失败提示），静默关闭仅打日志
            onJsAlert: (ctrl, jsAlertRequest) async {
              debugPrint('Bohrium JS alert suppressed: ${jsAlertRequest.message}');
              return JsAlertResponse(
                action: JsAlertResponseAction.CONFIRM,
                message: '',
              );
            },
            onJsConfirm: (ctrl, jsConfirmRequest) async {
              return JsConfirmResponse(
                action: JsConfirmResponseAction.CONFIRM,
                message: '',
              );
            },
            onJsPrompt: (ctrl, jsPromptRequest) async {
              return JsPromptResponse(
                action: JsPromptResponseAction.CONFIRM,
                message: '',
              );
            },
            onReceivedError: (ctrl, req, err) {
              debugPrint('Bohrium WebView error: ${err.type} - ${err.description}');
            },
          ),
        ),

        // ── 底部工具栏 ──
        _buildBottomToolbar(),
      ],
    );
  }

  Widget _buildBottomToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? accentColorNotifier.value.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.92);

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
            onTap: () => _controller?.loadUrl(
              urlRequest: URLRequest(url: WebUri(BohriumService.baseUrl)),
            ),
          ),
          _ToolbarButton(
            icon: Icons.refresh_rounded,
            label: '刷新',
            enabled: true,
            onTap: () => _controller?.reload(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'open_browser':
        await _openInExternalBrowser();
      case 'clear_cache':
        await _clearCache();
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

  Future<void> _clearCache() async {
    await InAppWebViewController.clearAllCache(includeDiskFiles: true);
    // 清缓存后重注入 CAS cookie，避免把 SSO 会话也一起清掉
    final count = await _service.injectCasCookiesToWebView(CookieManager.instance());
    _controller?.reload();
    if (mounted) {
      _showSnackBar(count > 0 ? '缓存已清除' : '缓存已清除（未找到统一认证会话）');
    }
  }

  Future<void> _updateNavState(InAppWebViewController ctrl) async {
    final back = await ctrl.canGoBack();
    final forward = await ctrl.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

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
              Icon(icon, size: 20,
                  color: enabled ? accentColorNotifier.value : Colors.grey),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: enabled ? accentColorNotifier.value : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
