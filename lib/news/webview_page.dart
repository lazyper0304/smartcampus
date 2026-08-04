import 'package:flutter/material.dart';
import '../core/liquid_background.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// 通用 WebView 页面，用于加载外部链接
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, this.title = ''});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  bool _isLoading = true;
  double _progress = 0;
  InAppWebViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return LiquidBackground(
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
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: InAppWebView(
          onWebViewCreated: (controller) => _controller = controller,
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            useWideViewPort: true,
            supportZoom: true,
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
        ),
      ),
    
    ));
  }
}
