import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../core/cas_webview.dart';
import '../core/crash_log.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../core/webview2_check.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// 通用 WebView 页面，用于加载外部链接
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  /// WebView 创建后、加载 [url] 前执行的回调（如注入 SSO cookie）。
  /// 为空时不等待，创建后直接加载。
  final Future<void> Function(InAppWebViewController controller)?
      onWebViewReady;

  /// 使用桌面版 Chrome User-Agent 加载页面。
  ///
  /// 部分资源站点（如知网 CNKI、CARSI 联盟资源）对移动/WebView UA
  /// 返回精简页面甚至拒绝服务（「来源应用不正确」/ JS 库未注入），
  /// 需伪装桌面浏览器访问。
  final bool desktopUserAgent;

  /// 页面顶部提示条文案（标题下方），非空时显示，如知网
  /// 「只支持查找，不支持在线阅读和下载」。
  final String? notice;

  const WebViewPage({
    super.key,
    required this.url,
    this.title = '',
    this.onWebViewReady,
    this.desktopUserAgent = false,
    this.notice,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  bool _isLoading = true;
  double _progress = 0;
  InAppWebViewController? _controller;

  /// Windows 上 WebView2 Runtime 可用性（缺失时显示引导页，避免 native 闪退）
  bool _webView2Ok = true;

  /// Windows 上页面与 CookieManager 共享的 WebView2 环境
  /// （避免页面环境 + CookieManager 默认环境同 userDataFolder 并发崩溃）
  WebViewEnvironment? _env;

  @override
  void initState() {
    super.initState();
    _checkWebView2();
    if (!kIsWeb && Platform.isWindows) _initSharedEnv();
  }

  /// Windows：创建/获取全局共享 WebView2 环境（注入类页面必需）
  Future<void> _initSharedEnv() async {
    try {
      final env = await ensureSharedCasEnvironment();
      if (!mounted) return;
      setState(() => _env = env);
    } catch (e) {
      CrashLog.write('WebViewPage WebViewEnvironment.create error: $e');
      if (!mounted) return;
      // 环境创建失败 → 引导页兜底（不创建无环境 WebView）
      setState(() => _webView2Ok = false);
    }
  }

  Future<void> _checkWebView2() async {
    final ok = await WebView2Check.available();
    CrashLog.write(
        'WebViewPage 打开 ${widget.title} → WebView2 可用: $ok (url: ${widget.url})');
    if (!mounted) return;
    setState(() => _webView2Ok = ok);
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: PopScope(
      canPop: false,
      // 系统返回手势/返回键：优先回退 WebView 浏览历史，
      // 仅当已到首页（无可后退）时才退出页面
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title.isNotEmpty ? widget.title : '加载中...'),
          centerTitle: true,
          // 左上角返回按钮：直接退出页面返回应用页（不走 PopScope 历史回退；
          // 手势/系统返回键才走 onPopInvokedWithResult 回退 WebView 历史）
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          // 标题下方：加载进度条（可选）+ 顶部提示条（notice 非空时）
          bottom: (_isLoading || widget.notice != null)
              ? PreferredSize(
                  preferredSize: Size.fromHeight(
                      (_isLoading ? 2 : 0) + (widget.notice != null ? 34.0 : 0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        LinearProgressIndicator(
                          value: _progress,
                          minHeight: 2,
                        ),
                      if (widget.notice != null)
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFC2410C)
                              .withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 15, color: Color(0xFFC2410C)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.notice!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFC2410C)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : null,
        ),
        body: _webView2Ok ? _buildWebView() : _buildWebView2Missing(),
      ),
    ));
  }
  Widget _buildWebView2Missing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.memory_rounded, size: 56, color: textSecondary(context)),
            const SizedBox(height: 16),
            const Text(
              '缺少 WebView2 运行时',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '内置网页功能需要 Microsoft Edge WebView2 Runtime。\n'
              '请安装后重新打开（重新安装本应用也会自动安装）。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary(context)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('前往安装 WebView2'),
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://developer.microsoft.com/microsoft-edge/webview2/'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WebView2 Runtime 缺失时的引导页（替代 native 崩溃闪退）
  Widget _buildWebView() {
    // Windows：环境创建完成前先不建 WebView（短暂空白），
    // 创建完成后 setState 重建；失败已由 _initSharedEnv 转引导页
    if (!kIsWeb && Platform.isWindows && _env == null) {
      return const SizedBox.shrink();
    }
    return InAppWebView(
          webViewEnvironment: !kIsWeb && Platform.isWindows ? _env : null,
          onWebViewCreated: (controller) async {
            _controller = controller;
            // 可选的预加载回调（如注入 SSO cookie），完成后手动加载初始 URL，
            // 保证注入先于页面加载
            final ready = widget.onWebViewReady;
            if (ready != null) {
              try {
                // ⚠️ 超时保护：Windows 网络差时 onWebViewReady 里的
                // ensureFreshSession（真实 CAS 登录）可能长时间阻塞，导致
                // WebView 创建回调挂起、页面空白甚至异常
                await ready(controller)
                    .timeout(const Duration(seconds: 30));
              } catch (e) {
                CrashLog.write('WebViewPage onWebViewReady error: $e');
              }
            }
            try {
              await controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(widget.url)),
              );
            } catch (e) {
              CrashLog.write('WebViewPage loadUrl error: $e');
            }
          },
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            useWideViewPort: true,
            supportZoom: true,
            // ⚠️ 必须开启多窗口支持，否则 Android WebView 会**静默忽略**
            // window.open()（知网等资源站点下载/阅读必用）→ 页面无响应 /
            // 「来源应用不正确」。开启后新窗口请求进入 onCreateWindow 回调，
            // 由我们在当前 WebView 内加载。
            supportMultipleWindows: true,
            javaScriptCanOpenWindowsAutomatically: true,
            // 空 allow-list = 所有请求不发送 X-Requested-With 头（部分 WebView
            // 版本会带应用包名，暴露"应用内浏览器"身份，知网据此拒绝服务）
            requestedWithHeaderOriginAllowList: const <String>{},
            // 桌面 UA 伪装：知网等 CARSI 资源站点对移动/WebView UA
            // 返回精简页面或拒绝服务（来源应用不正确）
            userAgent: widget.desktopUserAgent
                ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                    'AppleWebKit/537.36 (KHTML, like Gecko) '
                    'Chrome/120.0.0.0 Safari/537.36'
                : null,
          ),
          onProgressChanged: (controller, progress) {
            setState(() {
              _progress = progress / 100.0;
              if (progress >= 100) _isLoading = false;
            });
          },
          onTitleChanged: (controller, title) {
            if (title != null && mounted) {
              setState(() {});
            }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final url = navigationAction.request.url;
            if (url == null) return NavigationActionPolicy.ALLOW;
            final scheme = url.scheme.toLowerCase();
            // 拦截非 http(s) 的自定义协议（如 mqqapi:// 拉起 QQ 客户端），
            // 交由系统调起对应 App，避免 WebView 因无法解析该协议而报错
            if (scheme != 'http' && scheme != 'https') {
              try {
                await launchUrl(
                  Uri.parse(url.toString()),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                // 设备无对应 App 处理该协议时静默忽略
              }
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          // 资源站点（知网等）常用 JS 弹窗交互，WebView 默认弹原生对话框
          // 会阻塞页面（尤其自动触发 confirm 时无法点击），统一自动确认
          onJsAlert: (controller, jsAlertRequest) async {
            return JsAlertResponse(
              action: JsAlertResponseAction.CONFIRM,
              message: '',
            );
          },
          onJsConfirm: (controller, jsConfirmRequest) async {
            return JsConfirmResponse(
              action: JsConfirmResponseAction.CONFIRM,
              message: '',
            );
          },
          onJsPrompt: (controller, jsPromptRequest) async {
            return JsPromptResponse(
              action: JsPromptResponseAction.CONFIRM,
              message: '',
            );
          },
          // 资源站点新窗口打开（target=_blank / window.open）：
          // 全部在当前 WebView 内加载，避免丢失会话或新窗口无响应。
          // ⚠️ 知网等站点校验新窗口 Referer（来源应用不正确），手动 loadUrl
          // 默认不带 Referer，必须显式补上当前页 URL。
          onCreateWindow: (controller, createWindowAction) async {
            final url = createWindowAction.request.url;
            if (url != null) {
              String? referer;
              try {
                referer = (await controller.getUrl())?.toString();
              } catch (_) {}
              await controller.loadUrl(
                urlRequest: URLRequest(
                  url: url,
                  headers: referer != null && referer.isNotEmpty
                      ? {'Referer': referer}
                      : null,
                ),
              );
            }
            return false;
          },
        );
  }
}
