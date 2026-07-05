import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 通用 WebView 页面，用于加载外部链接
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({
    super.key,
    required this.url,
    this.title = '',
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
    );
  }
}
