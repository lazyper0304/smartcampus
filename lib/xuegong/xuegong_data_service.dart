import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as html_parser;

import '../core/http_client.dart';
import 'dorm_info.dart';

/// 学工系统数据提取服务
///
/// 使用 HeadlessInAppWebView 后台加载学工系统页面，
/// SSO Cookie 注入 → JS 自动登录 → 导航目标页 → JS 提取 HTML。
///
/// ⚠️ 会话边界：WebView 完成 SSO 后，学工域的 JSESSIONID 只存在于
/// **WebView 自己的 Cookie 存储**里，并不会回流到 SharedHttpClient。
/// 因此凡是需要学工会话的后续接口（如住宿信息），都必须在同一 WebView
/// 会话内用页面内 XHR 完成；用 HttpClient 直连会缺 JSESSIONID，
/// 服务端返回登录页而非 JSON。
class XuegongDataService {
  final SharedHttpClient _client;
  InAppWebViewController? _controller;

  XuegongDataService(this._client);

  /// 在同一个学工会话内执行任务，负责后台 WebView 的创建与释放
  ///
  /// 抽出来的目的是让「抓 HTML」与「取住宿信息」共用一次 SSO 登录，
  /// 避免为住宿信息再开一个 WebView（一次 SSO 约 10~20s，代价很高）。
  Future<T> _withSession<T>(
      Future<T> Function(InAppWebViewController controller) task) async {
    await _injectCookies();

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
        _controller = ctrl;
      },
      onLoadStop: (ctrl, u) {
        final s = u?.toString() ?? '';
        debugPrint('HeadlessWebView loaded: ${s.length > 80 ? s.substring(0, 80) : s}');
      },
      onTitleChanged: (ctrl, t) {
        debugPrint('HeadlessWebView title: $t');
      },
      // 拦截 JS 弹窗（SSO 失败时「用户已停用或不存在」alert），静默关闭
      onJsAlert: (ctrl, jsAlertRequest) async {
        debugPrint('HeadlessWebView alert suppressed: ${jsAlertRequest.message}');
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
    );

    await headlessWebView.run();

    try {
      final controller = _controller;
      if (controller == null) throw Exception('后台 WebView 初始化失败');
      // 整体兜底超时，避免会话内任一环节卡死导致调用方永久挂起
      return await task(controller).timeout(const Duration(seconds: 150));
    } finally {
      await headlessWebView.dispose();
      _controller = null;
    }
  }

  /// 获取学工系统指定页面的 HTML 内容
  Future<String> extractPageHtml(String url) =>
      _withSession((controller) => _loadAndExtractHtml(controller, url));

  /// 等待 SSO 自动登录 → 导航目标页 → 等待渲染 → 提取 HTML
  Future<String> _loadAndExtractHtml(
      InAppWebViewController controller, String url) async {
    // 等待 JS 自动登录完成（轮询 URL 变化）
    // wiseduIndex.jsp → JavaScript 自动登录 → 跳转到 toIndex.htm
    String? currentUrl;
    for (int i = 0; i < 45; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      final pageUrl = await controller.getUrl();
      currentUrl = pageUrl?.toString() ?? '';

      if (currentUrl.contains('toIndex.htm')) {
        debugPrint('Auto-login detected, navigating to target after ${(i * 0.4).toStringAsFixed(1)}s');
        break;
      }
    }

    if (currentUrl == null || !currentUrl.contains('toIndex.htm')) {
      // SSO 自动登录未完成，直接尝试用 cookie 加载目标页面
      debugPrint('SSO auto-login not detected, loading target directly');
    }

    // 导航到目标页面
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );

    // 等待目标页面加载 + JS 渲染完成。
    // 轮询个人信息区块（.minemine）出现，最多 10 秒——比固定等待更可靠，
    // 页面渲染慢（学工页有 JS 错误 onLoadAction is not defined）时显著提高成功率。
    var rendered = false;
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final ready = await controller.evaluateJavascript(
          source: "document.querySelectorAll('.minemine').length > 0",
        );
        if (ready == true || ready == 'true') {
          rendered = true;
          break;
        }
      } catch (_) {}
    }
    debugPrint('Target page rendered: $rendered');
    if (!rendered) {
      // 区块未出现：兜底再等一轮完整渲染
      await Future.delayed(const Duration(seconds: 4));
    }

    // 提取 HTML（最多重试 3 次，间隔 5 秒）
    String? html;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final raw = await controller.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        if (raw is String && raw.isNotEmpty) {
          html = raw;
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 5));
    }

    if (html != null && html.isNotEmpty) return html;
    throw Exception('无法提取页面内容');
  }

  /// 获取学工系统页面并解析为结构化数据
  /// （学籍照片不再从学工系统下载，改由 ehall 学籍照片接口获取，见 StudentAvatar）
  ///
  /// [fallbackStudentId]：个人信息页解析不出学号时的兜底学号（登录账号），
  /// 用于住宿信息查询。住宿数据会并入结果，键名为「住宿信息」。
  Future<Map<String, dynamic>> extractStructuredData(String url,
      {String? fallbackStudentId}) {
    return _withSession((controller) async {
      final html = await _loadAndExtractHtml(controller, url);
      final data = _parseStudentInfoHtml(html);

      // 住宿信息：复用当前已登录会话，页面内同源 XHR 拉取。
      // 学号优先取个人信息页解析结果（不假设类型，避免异常拖垮整次拉取）
      final basicSection = data['基本信息'];
      final parsedXh = basicSection is Map
          ? (basicSection['学号']?.toString().trim() ?? '')
          : '';
      final xh = parsedXh.isNotEmpty ? parsedXh : (fallbackStudentId ?? '').trim();
      if (xh.isNotEmpty) {
        final dorm = await fetchDormInfo(controller, xh);
        if (dorm != null && dorm.isNotEmpty) {
          data['住宿信息'] = dorm.toSection();
        }
      } else {
        debugPrint('Dorm fetch skipped: 学号为空');
      }
      return data;
    });
  }

  /// 查询住宿信息（学工系统 `//syt/sgxt/bed/querylist.htm`，type=ZSXX）
  ///
  /// 必须在已登录学工会话的页面上下文调用（同源），响应为
  /// `{ total, data: [ { sslmc 楼栋名, ssmc 宿舍号, unit 单元, ... } ] }`。
  Future<DormInfo?> fetchDormInfo(InAppWebViewController controller, String xh) async {
    // 只保留数字与字母，避免学号被拼进 JS 字符串时造成注入/语法错误
    final safeXh = xh.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    if (safeXh.isEmpty) return null;

    final js = '''
(function(){
  try {
    window.__dormResult = null;
    var url = 'https://ybxyxsglxt.yibinu.edu.cn//syt/sgxt/bed/querylist.htm?xh=$safeXh&type=ZSXX';
    var body = 'xh=$safeXh&type=ZSXX&pageIndex=0&pageSize=10&sortField=&sortOrder=';
    fetch(url, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'text/plain, */*; q=0.01'
      },
      body: body
    }).then(function(r){ return r.text(); })
      .then(function(t){ window.__dormResult = (t && t.length) ? t : 'EMPTY'; })
      .catch(function(e){ window.__dormResult = 'ERR:' + e; });
    return true;
  } catch (e) {
    window.__dormResult = 'ERR:' + e;
    return false;
  }
})();
''';

    try {
      await controller.evaluateJavascript(source: js);

      // 异步轮询取回结果（最多 10 秒）：不依赖 evaluateJavascript 对
      // Promise 的等待行为，各 WebView 版本表现一致
      for (int i = 0; i < 25; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final raw = await controller.evaluateJavascript(
          source: 'window.__dormResult',
        );
        if (raw is! String || raw.isEmpty) continue;
        if (raw.startsWith('ERR:')) {
          debugPrint('Dorm fetch failed: $raw');
          return null;
        }
        if (raw == 'EMPTY') {
          debugPrint('Dorm fetch empty response');
          return null;
        }
        debugPrint('Dorm fetch ok: ${raw.length} chars');
        return DormInfo.parseResponse(raw);
      }
      debugPrint('Dorm fetch timeout');
    } catch (e) {
      debugPrint('Dorm fetch error: $e');
    }
    return null;
  }

  /// 从 SharedHttpClient 获取指定主机的 cookie
  Map<String, String> _getCookiesForHost(String host) {
    final raw = _client.getCookiesForDomain(host);
    if (raw.isEmpty) return {};
    final result = <String, String>{};
    for (final part in raw.split('; ')) {
      final eq = part.indexOf('=');
      if (eq > 0) result[part.substring(0, eq)] = part.substring(eq + 1);
    }
    return result;
  }

  /// 注入 Cookie 到系统 WebView 存储（与可见 WebView 共享）
  Future<void> _injectCookies() async {
    try {
      final allCookies = _client.getAllCookies();
      final cm = CookieManager.instance();

      for (final domain in [
        'authserver.yibinu.edu.cn',
        'ybxyxsglxt.yibinu.edu.cn',
      ]) {
        final cookies = allCookies[domain];
        if (cookies != null && cookies.isNotEmpty) {
          for (final entry in cookies.entries) {
            if (entry.value.isEmpty) continue; // 空值触发 inappwebview 断言
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
          if (entry.value.isEmpty) continue; // 空值触发 inappwebview 断言
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

  /// 解析个人信息页 HTML 为结构化数据
  Map<String, dynamic> _parseStudentInfoHtml(String html) {
    final result = <String, dynamic>{};
    final doc = html_parser.parse(html);

    final sections = doc.getElementsByClassName('minemine');
    for (final section in sections) {
      final titleEl = section.getElementsByClassName('title').firstOrNull;
      final sectionTitle = titleEl?.text?.trim() ?? '未知';
      final sectionData = <String, String>{};

      // 解析表格
      final tables = section.getElementsByTagName('table');
      for (final table in tables) {
        final rows = table.getElementsByTagName('tr');
        for (final row in rows) {
          final cells = row.getElementsByTagName('td');
          for (int i = 0; i + 1 < cells.length; i += 2) {
            final label = cells[i].text?.trim().replaceAll('*', '').trim();
            final value = cells[i + 1].text?.trim() ?? '';
            if (label != null && label.isNotEmpty) {
              sectionData[label.replaceAll('：', '').replaceAll(':', '')] = value;
            }
          }
        }
      }

      result[sectionTitle] = sectionData;
    }
    return result;
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
