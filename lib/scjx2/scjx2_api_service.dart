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
  ///
  /// 注意：scjx2 不同模块（race / teach / grad ...）签发不同的 JWT，
  /// 每个模块单独存一份 token。
  static const String _kAuthToken = 'scjx2_auth_token';

  /// 模块特定 token key：`scjx2_<moduleId>_token`
  /// - race → scjx2_race_token
  /// - teach → scjx2_teach_token
  static String _tokenKeyFor(String moduleId) => 'scjx2_${moduleId}_token';

  /// 各模块入口 URL
  /// 注意：先访问 zxcas（公共 CAS SSO 入口）→ authserver 用 ehall session
  /// ticket 跳回 scjx2 → scjx2 Set-Cookie → 跳到默认模块主页（一般是 RACE）
  /// → 然后 navigate 到目标模块（race / teach / grad）触发该模块的 GetUserInfo
  static const Map<String, String> _moduleEntry = {
    'race': '$baseUrl/zxcas',
    'teach': '$baseUrl/zxcas',
    'grad': '$baseUrl/zxcas',
  };

  /// 加载 zxcas 跳到 home 后，需要 navigate 到目标模块再触发 GetUserInfo
  static const Map<String, String> _modulePath = {
    'race': '/RACE/',
    'teach': '/TEACH/',
    'grad': '/GRAD/',
  };

  /// 各模块检测 home 用的 hash 标识
  static const Map<String, String> _moduleHomeMarker = {
    'race': 'homeageStu',
    'teach': 'homeageStu',
    'grad': 'homeageStu',
  };

  /// LocalStorage key：zxcas 登录时设置的 user_id
  static const String _kUserId = 'scjx2_user_id';

  /// LocalStorage key：MenuId
  static const String _kMenuId = 'scjx2_menu_id';

  Scjx2ApiService({required SharedHttpClient client}) : _client = client;

  // ==================== Token 管理 ====================

  /// 读模块对应的 token（指定 moduleId）或通用 fallback
  Future<String?> getAuthToken({String? moduleId}) async {
    if (moduleId != null) {
      final t = await LocalStorage.getString(_tokenKeyFor(moduleId));
      if (t != null && t.isNotEmpty) return t;
    }
    return await LocalStorage.getString(_kAuthToken);
  }

  Future<void> setAuthToken(String token, {String? moduleId}) async {
    if (moduleId != null) {
      await LocalStorage.setString(_tokenKeyFor(moduleId), token);
    }
    await LocalStorage.setString(_kAuthToken, token);
  }

  Future<void> clearAuthToken({String? moduleId}) async {
    if (moduleId != null) {
      await LocalStorage.remove(_tokenKeyFor(moduleId));
    }
    await LocalStorage.remove(_kAuthToken);
    await LocalStorage.remove(_kUserId);
    await LocalStorage.remove(_kMenuId);
  }

  Future<bool> isLoggedIn({String? moduleId}) async {
    final token = await getAuthToken(moduleId: moduleId);
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
  /// - [moduleId]: scjx2 模块标识（'race' / 'teach' / 'grad'），
  ///   用于从 LocalStorage 读对应的 token
  Future<Map<String, dynamic>> request({
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? params,
    required String currentRoutePath,
    String apiName = 'scjx2',
    String? moduleId,
    int retryCount = 0,
  }) async {
    final token = await getAuthToken(moduleId: moduleId);
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
      // 401 (JWT 过期) 或 404 (scjx2 域 cookie 失效) 都触发重新登录
      if ((resp.statusCode == 401 || resp.statusCode == 404) && retryCount < 1) {
        await clearAuthToken(moduleId: moduleId);
        final ok = await bootstrapLogin(moduleId: moduleId);
        if (ok) {
          return request(
            path: path,
            data: data,
            params: params,
            currentRoutePath: currentRoutePath,
            apiName: apiName,
            moduleId: moduleId,
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
        await clearAuthToken(moduleId: moduleId);
        final ok = await bootstrapLogin(moduleId: moduleId);
        if (ok) {
          return request(
            path: path,
            data: data,
            params: params,
            currentRoutePath: currentRoutePath,
            apiName: apiName,
            moduleId: moduleId,
            retryCount: retryCount + 1,
          );
        }
      }
      throw Exception('$apiName 接口错误 [code=$code]: $msg');
    }

    return json;
  }

  // ==================== 引导登录 ====================

  /// 通过 HeadlessInAppWebView 引导登录 scjx2 某个模块，提取 JWT
  ///
  /// 流程：
  /// 1. 把 SharedHttpClient 中 ehall/yibinu 域的 cookie 注入到 WebView
  ///    （用户已在 ehall 登录，复用 authserver.yibinu.edu.cn session 完成 CAS SSO）
  /// 2. 加载 https://scjx2.yibinu.edu.cn/<MODULE>/ → authserver 用现有 session
  ///    验证 → 直接 ticket 跳回 scjx2 主应用
  /// 3. 等待主应用加载（路由到 homeageStu）
  /// 4. 等待 zxStorage.getItem('key1') 被设置（GetUserInfo action 触发）
  /// 5. 从 window.sessionStorage 提取 JWT，缓存到 LocalStorage（模块独立 key）
  /// 6. 把 WebView 登录后产生的 scjx2 cookie 同步到 SharedHttpClient
  ///
  /// [moduleId] 指定要登录的模块：'race' / 'teach' / 'grad'。
  /// 不传或传 null 时默认为 'race'。
  Future<bool> bootstrapLogin({String? moduleId}) async {
    moduleId ??= 'race';
    // 该模块已有 token 且未过期就直接用
    if (await isLoggedIn(moduleId: moduleId)) return true;

    InAppWebViewController? controller;
    final cookieManager = CookieManager.instance();

    // 0. 清空 scjx2 域的旧 cookie（避免上一次的 teach/race session 干扰）
    //    只清 scjx2 域，保留 ehall / authserver 域（CAS SSO 依赖）
    try {
      final scjx2Cookies = await cookieManager.getCookies(
        url: WebUri('https://scjx2.yibinu.edu.cn'),
      );
      for (final c in scjx2Cookies) {
        await cookieManager.deleteCookie(
          url: WebUri('https://scjx2.yibinu.edu.cn'),
          name: c.name,
          domain: c.domain ?? 'scjx2.yibinu.edu.cn',
          path: c.path ?? '/',
        );
      }
      if (scjx2Cookies.isNotEmpty) {
        debugPrint('Scjx2: cleared ${scjx2Cookies.length} old scjx2 cookies');
      }
    } catch (e) {
      debugPrint('Scjx2: failed to clear old scjx2 cookies: $e');
    }

    // 1. 注入 ehall 已有的 cookie 到 WebView
    await _injectEhallCookiesToWebView(cookieManager);

    final entryUrl = _moduleEntry[moduleId] ?? _moduleEntry['race']!;
    final modulePath = _modulePath[moduleId] ?? '/RACE/';
    debugPrint('Scjx2: bootstrap for module=$moduleId, entry=$entryUrl');

    final headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(entryUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/151.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (ctrl) async {
        controller = ctrl;
        await Future.delayed(const Duration(milliseconds: 200));
        await _injectEhallCookiesToWebView(cookieManager);
        await Future.delayed(const Duration(milliseconds: 100));
        await ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(entryUrl)));
      },
    );

    await headlessWebView.run();
    try {
      // ---- 1. 等待 zxcas → CAS SSO → 默认模块主页（一般是 RACE） ----
      bool reachedHome = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final url = (await controller?.getUrl())?.toString() ?? '';
        if (url.contains('homeageStu')) {
          debugPrint('Scjx2: reached default home after ${i + 1}s');
          reachedHome = true;
          break;
        }
        if (i == 6) {
          final url2 = (await controller?.getUrl())?.toString() ?? '';
          if (url2.contains('authserver') && url2.contains('casLoginForm')) {
            debugPrint('Scjx2: still on CAS login after 6s, retry inject');
            await _injectEhallCookiesToWebView(cookieManager);
            await controller?.reload();
          }
        }
      }

      if (!reachedHome) {
        final url = (await controller?.getUrl())?.toString() ?? '';
        debugPrint('Scjx2: failed to reach home, last url=$url');
        if (url.contains('authserver') || url.contains('casLoginForm')) {
          debugPrint('Scjx2: still on CAS login page');
          return false;
        }
        await Future.delayed(const Duration(seconds: 3));
      }

      // ---- 2. navigate 到目标模块（如果不是默认模块）----
      // 默认 zxcas 跳到 RACE 主页（race 的 key1）。
      // teach / grad 需要 navigate 到对应入口触发该模块的 GetUserInfo，
      // 覆盖 sessionStorage['key1'] 为该模块的 JWT。
      final currentUrl = (await controller?.getUrl())?.toString() ?? '';
      if (!currentUrl.contains(modulePath)) {
        debugPrint('Scjx2: navigating to $modulePath for $moduleId');
        await controller?.evaluateJavascript(source: '''
(function() {
  try {
    window.location.href = '${baseUrl}$modulePath#/homeageStu';
  } catch(e) {}
})();
''');
        // 等模块加载 + GetUserInfo 设置 key1
        for (int i = 0; i < 15; i++) {
          await Future.delayed(const Duration(milliseconds: 1000));
          final u = (await controller?.getUrl())?.toString() ?? '';
          if (u.contains(modulePath) && u.contains('homeageStu')) {
            debugPrint('Scjx2: reached $moduleId home after navigate ${i + 1}s');
            break;
          }
        }
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

      // 调试：解码 JWT payload 看 login_user_key（区分模块）
      try {
        final parts = key1.split('.');
        if (parts.length >= 2) {
          var b64 = parts[1].replaceAll('-', '+').replaceAll('_', '/');
          while (b64.length % 4 != 0) b64 += '=';
          final decoded = utf8.decode(base64.decode(b64));
          debugPrint('Scjx2: $moduleId token payload = $decoded');
        }
      } catch (e) {
        debugPrint('Scjx2: failed to decode token: $e');
      }

      await setAuthToken(key1, moduleId: moduleId);
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

  /// 把 SharedHttpClient 中 ehall/yibinu 域的 cookie 注入到 WebView
  ///
  /// 用户已经在 ehall 登录过，authserver.yibinu.edu.cn 已有 session。
  /// 把这些 cookie 注入 WebView 后，WebView 访问 scjx2/zxcas 时会自动走
  /// CAS SSO 跳过输入页直接 ticket 跳回 RACE。
  Future<void> _injectEhallCookiesToWebView(CookieManager cookieManager) async {
    try {
      final allCookies = _client.getAllCookies();
      debugPrint('Scjx2: client cookies buckets = ${allCookies.keys.toList()}');
      for (final e in allCookies.entries) {
        debugPrint('  ${e.key}: ${e.value.length} cookies = ${e.value.keys.toList()}');
      }

      final ehallCookies = allCookies['ehall.yibinu.edu.cn'] ?? {};
      final yibinuCookies = allCookies['yibinu.edu.cn'] ?? {};
      // authserver 自己产生的 cookie 也可能有
      final authCookies = allCookies['authserver.yibinu.edu.cn'] ?? {};

      // 合并：yibinu 父域 cookie 优先
      final merged = <String, String>{};
      merged.addAll(yibinuCookies);
      merged.addAll(ehallCookies);
      merged.addAll(authCookies);

      if (merged.isEmpty) {
        debugPrint('Scjx2: no ehall cookies to inject (user not logged in)');
        return;
      }

      debugPrint('Scjx2: injecting ${merged.length} cookies to WebView');
      int ok = 0;
      for (final e in merged.entries) {
        // 注入到 .yibinu.edu.cn（父域）让 authserver / scjx2 都能用
        try {
          await cookieManager.setCookie(
            url: WebUri('https://authserver.yibinu.edu.cn'),
            name: e.key,
            value: e.value,
            domain: '.yibinu.edu.cn',
            path: '/',
          );
          ok++;
        } catch (err) {
          debugPrint('Scjx2: failed to set ${e.key}: $err');
        }
      }
      debugPrint('Scjx2: injected $ok/${merged.length} cookies');

      // 验证一下 authserver 域的 cookie 是否真的写入了
      final verify = await cookieManager.getCookies(
        url: WebUri('https://authserver.yibinu.edu.cn'),
      );
      debugPrint('Scjx2: WebView authserver cookies after inject: ${verify.length}');
      for (final c in verify) {
        debugPrint('  ${c.name} (domain=${c.domain}, path=${c.path})');
      }
    } catch (e) {
      debugPrint('Scjx2._injectEhallCookiesToWebView error: $e');
    }
  }

  /// 把 WebView 中的 cookie 同步到 SharedHttpClient
  ///
  /// 关键：必须用 CookieManager.getCookies 拿全部 cookie（含 httpOnly），
  /// 不能用 document.cookie JS 读取（httpOnly cookie 不可见）。
  /// S_zx_soft_2020F / C_zx_soft_2020O 等都是 httpOnly 标记，
  /// JS 读不到导致 scjx2 子模块接口报 404。
  Future<void> _syncCookiesFromWebView(InAppWebViewController? controller) async {
    if (controller == null) return;
    final cookieManager = CookieManager.instance();
    try {
      // 用 CookieManager 拿全部 cookie（含 httpOnly）
      final allWebViewCookies = <String, Map<String, String>>{};
      for (final domain in const [
        'scjx2.yibinu.edu.cn',
        'authserver.yibinu.edu.cn',
        'yibinu.edu.cn',
        'ehall.yibinu.edu.cn',
      ]) {
        try {
          final list = await cookieManager.getCookies(
            url: WebUri('https://$domain'),
          );
          if (list.isNotEmpty) {
            final map = <String, String>{};
            final keys = <String>[];
            for (final c in list) {
              if (c.name.isNotEmpty && c.value.isNotEmpty) {
                map[c.name] = c.value;
                keys.add(c.name);
              }
            }
            keys.sort();
            debugPrint('Scjx2: WebView $domain: ${list.length} cookies = $keys');
            if (map.isNotEmpty) allWebViewCookies[domain] = map;
          }
        } catch (e) {
          debugPrint('Scjx2: failed to get cookies for $domain: $e');
        }
      }

      if (allWebViewCookies.isEmpty) {
        debugPrint('Scjx2: no cookies found in WebView');
        return;
      }

      int totalInjected = 0;
      for (final entry in allWebViewCookies.entries) {
        _client.setCookiesForDomain(entry.key, entry.value);
        totalInjected += entry.value.length;
        debugPrint('Scjx2: injected ${entry.value.length} cookies to ${entry.key}');
      }
      debugPrint('Scjx2: total $totalInjected cookies injected');
    } catch (e) {
      debugPrint('Scjx2._syncCookiesFromWebView error: $e');
    }
  }
}
