import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as html_parser;

import 'raw_http_client.dart';

import '../core/http_client.dart';

/// 学工系统数据提取服务
///
/// 使用 HeadlessInAppWebView 后台加载学工系统页面，
/// SSO Cookie 注入 → JS 自动登录 → 导航目标页 → JS 提取 HTML。
class XuegongDataService {
  final SharedHttpClient _client;
  InAppWebViewController? _controller;

  XuegongDataService(this._client);

  /// 获取学工系统指定页面的 HTML 内容
  Future<String> extractPageHtml(String url) async {
    await _injectCookies();

    final completer = Completer<String>();

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
      // 等待 JS 自动登录完成（轮询 URL 变化）
      // wiseduIndex.jsp → JavaScript 自动登录 → 跳转到 toIndex.htm
      String? currentUrl;
      for (int i = 0; i < 45; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final pageUrl = await _controller?.getUrl();
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
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );

      // 等待目标页面加载 + JS 渲染完成。
      // 轮询个人信息区块（.minemine）出现，最多 10 秒——比固定等待更可靠，
      // 页面渲染慢（学工页有 JS 错误 onLoadAction is not defined）时显著提高成功率。
      var rendered = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final ready = await _controller?.evaluateJavascript(
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
          final raw = await _controller?.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          );
          if (raw is String && raw.isNotEmpty) {
            html = raw;
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 5));
      }

      if (html != null && html.isNotEmpty) {
        completer.complete(html);
      } else {
        completer.completeError(Exception('无法提取页面内容'));
      }

      return await completer.future.timeout(const Duration(seconds: 90));
    } finally {
      await headlessWebView.dispose();
      _controller = null;
    }
  }

  /// 获取学工系统页面并解析为结构化数据
  Future<Map<String, dynamic>> extractStructuredData(String url) async {
    final html = await extractPageHtml(url);
    final data = _parseStudentInfoHtml(html);

    // 从 WebView 系统 Cookie 存储获取学工系统 session cookie
    String? jsessionid;
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(
        url: WebUri('https://ybxyxsglxt.yibinu.edu.cn/'),
      );
      for (final c in cookies) {
        if (c.name == 'JSESSIONID') {
          jsessionid = c.value;
          break;
        }
      }
    } catch (_) {}

    // 如果有照片 URL，下载照片
    final photoUrl = data['_photoUrl'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final cookieMap = <String, String>{};
        if (jsessionid != null && jsessionid.isNotEmpty) {
          cookieMap['JSESSIONID'] = jsessionid;
        }
        final resp = await RawHttpClient().getBytes(photoUrl, cookies: cookieMap);
        data['_photoBytes'] = resp.bodyBytes ?? [];
        debugPrint('Photo downloaded: ${(data['_photoBytes'] as List<int>).length} bytes');
      } catch (e) {
        debugPrint('Photo download error: $e');
      }
    }

    return data;
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
    final rawClient = RawHttpClient();

    // 提取照片 URL
    final img = doc.querySelector('img[src*="showphoto"]');
    if (img != null) {
      result['_photoUrl'] = img.attributes['src'] ?? '';
    }

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
