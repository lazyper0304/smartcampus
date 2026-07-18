import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'race.dart';

/// 学科竞赛服务
///
/// 使用 HeadlessInAppWebView 完整加载 scjx2 主应用，
/// CAS SSO → 主应用首页 → Vue Router 导航到竞赛模块 → 拦截 API
class RaceService {
  final SharedHttpClient _client;

  static const String baseUrl = 'https://scjx2.yibinu.edu.cn';

  RaceService({required SharedHttpClient client}) : _client = client;

  Future<RacePageResult> fetchCompetitions({
    int page = 1,
    int pageSize = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'race_list_${page}_$pageSize';
    if (!forceRefresh) {
      final cached = DataCache().get<RacePageResult>(cacheKey);
      if (cached != null) return cached;
    }

    await _injectCookies();
    final result = await _fetchViaWebView(page, pageSize);

    DataCache().set(cacheKey, result);
    return result;
  }

  Future<RacePageResult> _fetchViaWebView(int page, int pageSize) async {
    final completer = Completer<RacePageResult>();
    InAppWebViewController? controller;
    bool done = false;

    final headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$baseUrl/zxcas')), // 走 CAS SSO → 主应用
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/151.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (ctrl) {
        controller = ctrl;
      },
      onLoadStop: (ctrl, url) {
        final u = url?.toString() ?? '';
        debugPrint('WV: ${u.length > 80 ? u.substring(0, 80) : u}');
      },
    );

    await headlessWebView.run();

    try {
      // ---- CAS SSO ----
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final url = (await controller?.getUrl())?.toString() ?? '';
        if (url.contains('homeageStu')) {
          debugPrint('Login OK after ${i + 1}s');
          break;
        }
      }

      await Future.delayed(const Duration(seconds: 2));

      // ---- 搜索页面 HTTP 客户端 + 直接调 RACE API ----
      debugPrint('Searching HTTP client and calling API...');
      
      // 先搜索所有可能的 HTTP 客户端和签名函数
      final searchJs = '''
(function() {
  try {
    var results = [];
    // 1. 搜索 window 上所有对象，找有 post 方法的
    var checked = new Set();
    var queue = [window];
    while (queue.length > 0 && results.length < 10) {
      var cur = queue.shift();
      if (!cur || checked.has(cur)) continue;
      checked.add(cur);
      try {
        if (typeof cur.post === 'function' && typeof cur.interceptors !== 'undefined') {
          results.push('axios-like at window');
        }
        if (typeof cur.get === 'function' && typeof cur.post === 'function') {
          results.push('http-client at window');
          results.push('url:' + (cur.defaults ? (cur.defaults.baseURL || '') : ''));
        }
      } catch(e) {}
      // 只搜索几层
      if (checked.size > 500) break;
    }
    // 2. 检查 Vue 2
    var appEl = document.querySelector('#app');
    var vue2 = appEl ? (appEl.__vue__ || '') : '';
    if (vue2) {
      results.push('Vue2 found');
      // 在 Vue 实例中找 \$http
      if (vue2.\$http) results.push('has \$http');
      if (vue2.\$axios) results.push('has \$axios');
    }
    // 3. 找 fetch 拦截器
    if (window.fetch && window.fetch.toString && window.fetch.toString().indexOf('native code') < 0) {
      results.push('fetch monkeypatched');
    }
    // 4. 搜索 axios 实例常见位置
    var axiosCandidates = [
      window.axios, window.\$http, window.\$axios, window.http,
      window.Vue && window.Vue.http, window.Vue && window.Vue.axios
    ];
    for (var i = 0; i < axiosCandidates.length; i++) {
      if (axiosCandidates[i] && typeof axiosCandidates[i].post === 'function') {
        results.push('axios at index ' + i);
      }
    }
    return JSON.stringify(results);
  } catch(e) { return JSON.stringify(['error: ' + e.message]); }
})();
''';
      final search = await controller?.evaluateJavascript(source: searchJs);
      debugPrint('Search results: $search');

      // 不管找到没，直接用 window.fetch（如果被 SPA 覆写过就有拦截器）
      await controller?.evaluateJavascript(source: '''
(function() {
  window.__race = '';
  window.__fetchOrigin = window.fetch;
  // 包装 fetch 来捕获 RACE API 响应
  window.fetch = function() {
    var url = arguments[0] || '';
    var opts = arguments[1] || {};
    return window.__fetchOrigin.apply(this, arguments).then(function(resp) {
      try {
        if (resp && (url.indexOf('listStuRacePage') > -1 || url.indexOf('getStuMenus') > -1)) {
          resp.clone().text().then(function(t) {
            if (t && t.length > 0) window.__race = t;
          });
        }
      } catch(e) {}
      return resp;
    }).catch(function(e) { throw e; });
  };
  // 导航到 RACE 路由让 SPA 加载模块
  window.location.hash = '/9001/modules/sjjx/race/stu/race/stage/list';
  // 点击"学科竞赛"
  setTimeout(function() {
    try {
      var all = document.querySelectorAll('a, button, div, li, span, [role=button], .el-menu-item');
      for (var i = 0; i < all.length; i++) {
        if (all[i].textContent && all[i].textContent.trim() === '学科竞赛' && all[i].offsetParent !== null) {
          var evt = new MouseEvent('click', {bubbles: true, cancelable: true, view: window});
          all[i].dispatchEvent(evt);
          break;
        }
      }
    } catch(e) {}
  }, 3000);
})();
''');

      // ---- 等待 RACE 页面渲染完成 ----
      debugPrint('Waiting for RACE page to render...');
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final check = await controller?.evaluateJavascript(source: '''
(function() {
  try {
    var t = document.body ? document.body.innerText || '' : '';
    var hasTable = t.indexOf('竞赛名称') >= 0 || t.indexOf('学科竞赛信息列表') >= 0;
    return JSON.stringify({len: t.length, hasTable: hasTable, url: window.location.href});
  } catch(e) { return '{}'; }
})();
''');
        final ck = check?.toString() ?? '';
        if (ck.contains('"hasTable":true') || ck.contains('"len":')) {
          debugPrint('Page state at ${i + 1}s: $ck');
          if (ck.contains('"hasTable":true')) break;
        }
      }

      // ---- 从 DOM 提取竞赛列表 ----
      final extractJs = '''
(function() {
  try {
    // 查找所有表格行
    var rows = document.querySelectorAll('table tbody tr, .el-table__body tr, [class*="table"] tbody tr');
    var list = [];
    for (var r = 0; r < rows.length; r++) {
      var cells = rows[r].querySelectorAll('td');
      if (cells.length >= 3) {
        var name = (cells[0].textContent || '').trim();
        var dep = '';
        var teacher = '';
        if (cells.length >= 2) dep = (cells[1].textContent || '').trim();
        if (cells.length >= 3) teacher = (cells[2].textContent || '').trim();
        if (name && name.length > 4) {
          list.push({name: name, teacher_name: teacher, dep_name: dep});
        }
      }
    }
    if (list.length > 0) return JSON.stringify({source:'table', data: list});

    // 回退：按文本结构解析
    var text = document.body ? document.body.innerText || '' : '';
    var lines = text.split('\\n');
    var parsed = [];
    for (var i = 0; i < lines.length; i++) {
      // 匹配竞赛名称行（以年份开头）
      if (/^20\\d{2}/.test(lines[i].trim()) && lines[i].length > 10) {
        var name = lines[i].trim();
        var teacher = i + 2 < lines.length ? lines[i + 2].trim() : '';
        var dep = i + 1 < lines.length ? lines[i + 1].trim() : '';
        parsed.push({name: name, teacher_name: teacher, dep_name: dep});
      }
    }
    if (parsed.length > 0) return JSON.stringify({source:'text', data: parsed});

    return JSON.stringify({source:'raw', data: text.substring(0, 3000)});
  } catch(e) {
    return JSON.stringify({error: e.message});
  }
})();
''';
      final extracted = await controller?.evaluateJavascript(source: extractJs);
      final extStr = extracted?.toString() ?? '';
      debugPrint('Extracted (${extStr.length} chars): ${extStr.length > 300 ? "${extStr.substring(0, 300)}..." : extStr}');

      if (extracted is String && extracted.isNotEmpty) {
        final result = jsonDecode(extracted) as Map<String, dynamic>;
        if (result['error'] != null) {
          completer.completeError(Exception(result['error']));
        } else {
          final data = result['data'];
          if (data is List && data.isNotEmpty) {
            final competitions = <RaceCompetition>[];
            for (final item in data) {
              if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                competitions.add(RaceCompetition(
                  name: map['name']?.toString() ?? '',
                  teacherName: map['teacher_name']?.toString() ?? '',
                  depName: map['dep_name']?.toString() ?? '',
                  depCode: '', id: '',
                  rowId: competitions.length + 1,
                ));
              }
            }
            if (competitions.isNotEmpty) {
              completer.complete(RacePageResult(
                list: competitions,
                totalCount: competitions.length,
                totalPage: 1, currPage: 1,
                pageSize: competitions.length,
              ));
              done = true;
            }
          }
        }
      }

      if (!done) {
        completer.completeError(Exception('未能从页面提取竞赛数据'));
      }

      return await completer.future.timeout(const Duration(seconds: 90));
    } finally {
      await headlessWebView.dispose();
    }
  }

  Future<void> _injectCookies() async {
    try {
      final allCookies = _client.getAllCookies();
      final cm = CookieManager.instance();
      for (final domain in [
        'authserver.yibinu.edu.cn', 'scjx2.yibinu.edu.cn', 'yibinu.edu.cn',
      ]) {
        final cookies = allCookies[domain] ?? allCookies['.$domain'] ?? {};
        for (final entry in cookies.entries) {
          if (entry.value.isEmpty) continue;
          await cm.setCookie(
            url: WebUri('https://$domain/'),
            name: entry.key, value: entry.value,
            domain: domain, path: '/', isSecure: true,
          );
        }
      }
      final pc = allCookies['yibinu.edu.cn'];
      if (pc != null) {
        for (final entry in pc.entries) {
          if (entry.value.isEmpty) continue;
          await cm.setCookie(
            url: WebUri('https://yibinu.edu.cn/'),
            name: entry.key, value: entry.value,
            domain: '.yibinu.edu.cn', path: '/', isSecure: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Cookie injection error: $e');
    }
  }
}
