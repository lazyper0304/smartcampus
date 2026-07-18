import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide LocalStorage;

import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'scjx2_signer.dart';

/// scjx2.yibinu.edu.cn 通用 API 客户端
///
/// 提供给 race（学科竞赛）、teach（实验教学）等模块共用：
/// - JWT token 管理（LocalStorage 缓存）
/// - zxcas 引导登录（HeadlessInAppWebView）
/// - WebView cookie 同步到 SharedHttpClient
/// - 通用 POST 请求（自动签名 + 401 自动重登）
class Scjx2ApiService {
  final SharedHttpClient _client;
  final Scjx2ApiSigner _signer = Scjx2ApiSigner();

  static const String baseUrl = 'https://scjx2.yibinu.edu.cn';

  /// LocalStorage key：缓存 zxcas 登录后从 sessionStorage 提取的 JWT
  static const String _kAuthToken = 'scjx2_auth_token';

  /// LocalStorage key：zxcas 登录时设置的 user_id
  static const String _kUserId = 'scjx2_user_id';

  /// LocalStorage key：MenuId
  static const String _kMenuId = 'scjx2_menu_id';

  Scjx2ApiService({required SharedHttpClient client}) : _client = client;

  // ==================== Token 管理 ====================

  Future<String?> getAuthToken() async {
    return await LocalStorage.getString(_kAuthToken);
  }

  Future<void> setAuthToken(String token) async {
    await LocalStorage.setString(_kAuthToken, token);
  }

  Future<void> clearAuthToken() async {
    await LocalStorage.remove(_kAuthToken);
    await LocalStorage.remove(_kUserId);
    await LocalStorage.remove(_kMenuId);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== 通用 POST 请求 ====================

  /// 发起 scjx2 API 请求
  ///
  /// - [path]: API 路径（不含域名），如 `/race/race/stuRace/listStuRacePage`
  /// - [data]: POST body 字典（可为 null，空 body 时传 null）
  /// - [params]: query string 字典（可为 null）
  /// - [currentRoutePath]: 当前路由路径，用于签名头
  ///   （如 `/9001/modules/sjjx/race/stu/race/stage/list`）
  /// - [apiName]: 错误信息中显示的 API 名（如 "RACE"）
  Future<Map<String, dynamic>> request({
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? params,
    required String currentRoutePath,
    String apiName = 'scjx2',
    int retryCount = 0,
  }) async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('未登录 scjx2，请先登录');
    }

    final menuId = await LocalStorage.getString(_kMenuId) ?? '';

    // 构造签名头
    final headers = _signer.buildHeaders(
      data: data,
      params: params,
      menuId: menuId,
      authorization: token,
      currentRoutePath: currentRoutePath,
    );

    // 拼 URL
    final base = '$baseUrl$path';
    final uri = params != null && params.isNotEmpty
        ? Uri.parse(base).replace(queryParameters: {
            for (final e in params.entries) e.key: e.value.toString(),
          })
        : Uri.parse(base);

    debugPrint('$apiName API: POST $uri');
    debugPrint('  body: ${data ?? "(empty)"}');

    final resp = await _client.postJson(
      uri,
      body: data,
      headers: headers,
    );

    debugPrint('  status: ${resp.statusCode}');
    debugPrint('  resp.body (前500): ${resp.body.length > 500 ? "${resp.body.substring(0, 500)}..." : resp.body}');

    if (resp.statusCode != 200) {
      if (resp.statusCode == 401 && retryCount < 1) {
        await clearAuthToken();
        final ok = await bootstrapLogin();
        if (ok) {
          return request(
            path: path,
            data: data,
            params: params,
            currentRoutePath: currentRoutePath,
            apiName: apiName,
            retryCount: retryCount + 1,
          );
        }
        throw Exception('登录已过期，请重新登录');
      }
      throw Exception('$apiName 接口失败 (HTTP ${resp.statusCode})');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final code = json['code'];
    if (code != 200) {
      final msg = json['msg']?.toString() ?? '未知错误';
      if (code == 401 && retryCount < 1) {
        await clearAuthToken();
        final ok = await bootstrapLogin();
        if (ok) {
          return request(
            path: path,
            data: data,
            params: params,
            currentRoutePath: currentRoutePath,
            apiName: apiName,
            retryCount: retryCount + 1,
          );
        }
      }
      throw Exception('$apiName 接口错误 [code=$code]: $msg');
    }

    return json;
  }

  // ==================== 引导登录 ====================

  /// 通过 HeadlessInAppWebView 引导登录 zxcas，提取 JWT
  ///
  /// 流程：
  /// 1. 加载 https://scjx2.yibinu.edu.cn/zxcas → 自动跳转到 authserver
  /// 2. 如果已登录会自动回到 scjx2 主应用
  /// 3. 等待主应用加载（路由到 /homeageStu）
  /// 4. 等待 zxStorage.getItem('key1') 被设置（GetUserInfo action 触发）
  /// 5. 从 window.sessionStorage 提取 JWT，缓存到 LocalStorage
  /// 6. 把 WebView 登录后产生的 cookie 同步到 SharedHttpClient
  Future<bool> bootstrapLogin() async {
    if (await isLoggedIn()) return true;

    InAppWebViewController? controller;

    final headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$baseUrl/zxcas')),
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
    );

    await headlessWebView.run();
    try {
      bool reachedHome = false;
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final url = (await controller?.getUrl())?.toString() ?? '';
        if (url.contains('homeageStu')) {
          debugPrint('Scjx2: reached home after ${i + 1}s');
          reachedHome = true;
          break;
        }
      }

      if (!reachedHome) {
        final url = (await controller?.getUrl())?.toString() ?? '';
        if (url.contains('authserver') || url.contains('casLoginForm')) {
          debugPrint('Scjx2: still on CAS login page');
          return false;
        }
        await Future.delayed(const Duration(seconds: 3));
      }

      await controller?.evaluateJavascript(source: '''
(function() {
  try {
    if (window.location.hash.indexOf('/homeageStu') < 0) {
      window.location.hash = '/homeageStu';
    }
  } catch(e) {}
})();
''');
      await Future.delayed(const Duration(seconds: 2));

      String? key1;
      String? menuId;
      String? userId;
      for (int attempt = 0; attempt < 15; attempt++) {
        final extract = await controller?.evaluateJavascript(source: '''
(function() {
  try {
    var k = window.sessionStorage.getItem('key1') || '';
    var m = window.sessionStorage.getItem('MenuId') || '';
    var u = window.sessionStorage.getItem('user_id') || '';
    return JSON.stringify({key1: k, menuId: m, userId: u});
  } catch(e) {
    return JSON.stringify({error: e.message});
  }
})();
''');
        if (extract is String && extract.isNotEmpty) {
          try {
            final m = jsonDecode(extract) as Map<String, dynamic>;
            key1 = m['key1']?.toString();
            menuId = m['menuId']?.toString();
            userId = m['userId']?.toString();
            if (key1 != null && key1.isNotEmpty) {
              debugPrint('Scjx2: got key1 (${key1.length} chars) on attempt ${attempt + 1}');
              break;
            }
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (key1 == null || key1.isEmpty) {
        debugPrint('Scjx2: failed to extract key1');
        return false;
      }

      await setAuthToken(key1);
      if (menuId != null && menuId.isNotEmpty) {
        await LocalStorage.setString(_kMenuId, menuId);
      }
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.setString(_kUserId, userId);
      }

      // 同步 cookie 到 SharedHttpClient
      await _syncCookiesFromWebView(controller);

      return true;
    } catch (e) {
      debugPrint('Scjx2.bootstrapLogin error: $e');
      return false;
    } finally {
      await headlessWebView.dispose();
    }
  }

  /// 把 WebView 中的 cookie 同步到 SharedHttpClient
  Future<void> _syncCookiesFromWebView(InAppWebViewController? controller) async {
    if (controller == null) return;
    try {
      final result = await controller.evaluateJavascript(source: '''
(function() {
  try { return document.cookie || ''; }
  catch(e) { return ''; }
})();
''');
      final cookieStr = result?.toString() ?? '';
      if (cookieStr.isEmpty) return;
      debugPrint('Scjx2: syncing cookies (${cookieStr.length} chars)');

      final cookieMap = <String, String>{};
      for (final part in cookieStr.split(';')) {
        final eqIdx = part.indexOf('=');
        if (eqIdx < 0) continue;
        final name = part.substring(0, eqIdx).trim();
        final value = part.substring(eqIdx + 1).trim();
        if (name.isEmpty || value.isEmpty) continue;
        cookieMap[name] = value;
      }

      if (cookieMap.isEmpty) return;

      _client.setCookiesForDomain('scjx2.yibinu.edu.cn', cookieMap);
      _client.setCookiesForDomain('authserver.yibinu.edu.cn', cookieMap);
      _client.setCookiesForDomain('yibinu.edu.cn', cookieMap);
      debugPrint('Scjx2: injected ${cookieMap.length} cookies');
    } catch (e) {
      debugPrint('Scjx2._syncCookiesFromWebView error: $e');
    }
  }
}
