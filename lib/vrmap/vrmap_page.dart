import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// VR 地图页面 — 支持 A区 / 临港校区切换
class VrmapPage extends StatefulWidget {
  const VrmapPage({super.key});

  @override
  State<VrmapPage> createState() => _VrmapPageState();
}

/// 校区 VR 配置
class _CampusVr {
  final String name;
  final String url;

  const _CampusVr({required this.name, required this.url});
}

const _campuses = [
  _CampusVr(name: 'A区', url: 'https://vr.douhuiai.com/v/3jb8i06blq9kd5-1779006271.html'),
  _CampusVr(name: '临港', url: 'https://vr.douhuiai.com/v/jc4w9o1e6b5449-1779864933.html'),
];

class _VrmapPageState extends State<VrmapPage> {
  int _selectedIndex = 0;
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  _CampusVr get _currentCampus => _campuses[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('VR地图 · ${_currentCampus.name}'),
        centerTitle: true,
        actions: [
          PopupMenuButton<int>(
            child: const Text('切换校区'),
            onSelected: (index) {
              if (index != _selectedIndex) {
                setState(() {
                  _selectedIndex = index;
                  _isLoading = true;
                  _progress = 0;
                });
                _webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri(_currentCampus.url)),
                );
              }
            },
            itemBuilder: (context) => List.generate(
              _campuses.length,
              (i) => PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: i == _selectedIndex
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    Text(_campuses[i].name),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              initialUrlRequest: URLRequest(url: WebUri(_currentCampus.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useWideViewPort: true,
                supportZoom: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                setState(() {
                  _progress = progress / 100.0;
                  if (progress >= 100) _isLoading = false;
                });
              },
              onTitleChanged: (controller, title) {
                if (mounted) setState(() {});
              },
              onReceivedError: (ctrl, req, err) {
                if (!mounted) return;
                setState(() => _isLoading = false);
              },
            ),
    );
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }
}
