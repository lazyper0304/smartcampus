import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'student_info_manager.dart';

/// 综合素质测评数据
class ZhszRecord {
  final String semester;
  final double score;
  final String grade;
  final int schoolRank;
  final double schoolRankPct;
  final int majorRank;
  final double majorRankPct;
  final int classRank;
  final double classRankPct;
  final int gradeRank;
  final double gradeRankPct;

  ZhszRecord({
    required this.semester,
    required this.score,
    required this.grade,
    required this.schoolRank,
    required this.schoolRankPct,
    required this.majorRank,
    required this.majorRankPct,
    required this.classRank,
    required this.classRankPct,
    required this.gradeRank,
    required this.gradeRankPct,
  });

  factory ZhszRecord.fromJson(Map<String, dynamic> json) => ZhszRecord(
        semester: json['cpnf']?.toString() ?? '',
        score: (json['score'] ?? 0).toDouble(),
        grade: json['cjdj']?.toString() ?? '',
        schoolRank: int.tryParse(json['cppm']?.toString() ?? '0') ?? 0,
        schoolRankPct: _pct(json['cppmbfb']),
        majorRank: int.tryParse(json['zypm']?.toString() ?? '0') ?? 0,
        majorRankPct: _pct(json['zypmbfb']),
        classRank: int.tryParse(json['bjpm']?.toString() ?? '0') ?? 0,
        classRankPct: _pct(json['bjpmbfb']),
        gradeRank: int.tryParse(json['njpm']?.toString() ?? '0') ?? 0,
        gradeRankPct: _pct(json['njpmbfb']),
      );

  static double _pct(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
}

/// 综合素质服务 - 通过 HeadlessInAppWebView 加载页面后提取 JSON 数据
class ZhszService {
  final SharedHttpClient _client;

  ZhszService(this._client);

  Future<List<ZhszRecord>> fetchRecords() async {
    // 1. 注入 SSO Cookie 到系统 WebView 存储
    await _injectCookies();

    // 2. 创建后台 WebView 自动登录
    final completer = Completer<List<ZhszRecord>>();
    InAppWebViewController? controller;

    final headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('https://ybxyxsglxt.yibinu.edu.cn/wiseduIndex.jsp'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (ctrl) {
        controller = ctrl;
      },
    );

    await headlessWebView.run();

    try {
      // 3. 等待自动登录完成（轮询 URL）
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final url = await controller?.getUrl();
        if (url != null && url.toString().contains('toIndex.htm')) break;
      }

      // 4. 导航到综合素质页面
      await controller?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(
              'https://ybxyxsglxt.yibinu.edu.cn/syt/zhcp/xscj/index.htm'),
        ),
      );

      // 5. 等待页面加载 + MiniUI 数据请求完成
      await Future.delayed(const Duration(seconds: 5));

      // 6. 注入 JS 直接从 MiniUI grid 获取数据
      final js = '''
(function() {
  var grids = document.querySelectorAll('.mini-datagrid');
  for (var i = 0; i < grids.length; i++) {
    var gridId = grids[i].id;
    if (window.mini && mini.get) {
      var grid = mini.get(gridId);
      if (grid && grid.getData) {
        var data = grid.getData();
        if (data && data.length > 0) {
          return JSON.stringify(data);
        }
      }
    }
  }
  // 如果没有 MiniUI grid，尝试找页面中隐藏的数据
  var scripts = document.querySelectorAll('script');
  for (var s = 0; s < scripts.length; s++) {
    var text = scripts[s].textContent || '';
    if (text.indexOf('"data"') > -1 && text.indexOf('"cpnf"') > -1) {
      var match = text.match(/\\{[^]*"data"\\s*:\\s*\\[([^]*?)\\][^]*\\}/);
      if (match) return match[0];
    }
  }
  return '';
})();
''';

      final result = await controller?.evaluateJavascript(source: js);
      if (result is String && result.isNotEmpty) {
        try {
          final jsonData = jsonDecode(result) as List<dynamic>;
          final records = jsonData
              .map((e) => ZhszRecord.fromJson(e as Map<String, dynamic>))
              .toList();
          completer.complete(records);
        } catch (_) {
          // 尝试作为整体 JSON 解析
          final obj = jsonDecode(result) as Map<String, dynamic>?;
          if (obj != null && obj.containsKey('data')) {
            final list = obj['data'] as List<dynamic>;
            completer.complete(
                list.map((e) => ZhszRecord.fromJson(e as Map<String, dynamic>)).toList());
          } else {
            completer.completeError(Exception('数据格式异常'));
          }
        }
      } else {
        completer.completeError(Exception('未获取到数据'));
      }

      return await completer.future.timeout(const Duration(seconds: 20));
    } finally {
      await headlessWebView.dispose();
    }
  }

  Future<void> _injectCookies() async {
    try {
      final allCookies = _client.getAllCookies();
      final cm = CookieManager.instance();
      for (final domain in ['authserver.yibinu.edu.cn', 'ybxyxsglxt.yibinu.edu.cn']) {
        final cookies = allCookies[domain];
        if (cookies != null) {
          for (final entry in cookies.entries) {
            await cm.setCookie(
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
      final yibinuCookies = allCookies['yibinu.edu.cn'];
      if (yibinuCookies != null && yibinuCookies.isNotEmpty) {
        for (final entry in yibinuCookies.entries) {
          await cm.setCookie(
            url: WebUri('https://yibinu.edu.cn/'),
            name: entry.key,
            value: entry.value,
            domain: '.yibinu.edu.cn',
            path: '/',
            isSecure: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Cookie injection error: $e');
    }
  }
}
