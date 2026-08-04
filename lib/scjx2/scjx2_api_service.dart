import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide LocalStorage;

import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../auth/auth_service.dart';
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
  /// → 然后 navigate 到目标模块（race / teach / grad / srtp）触发该模块的 GetUserInfo
  static const Map<String, String> _moduleEntry = {
    'race': '$baseUrl/zxcas',
    'teach': '$baseUrl/zxcas',
    'grad': '$baseUrl/zxcas',
    'srtp': '$baseUrl/zxcas',
  };

  /// 加载 zxcas 跳到 home 后，需要 navigate 到目标模块再触发 GetUserInfo
  static const Map<String, String> _modulePath = {
    'race': '/RACE/',
    'teach': '/TEACH/',
    'grad': '/GRAD/',
    'srtp': '/SRTP/',
  };

  /// 各模块检测 home 用的 hash 标识
  static const Map<String, String> _moduleHomeMarker = {
    'race': 'homeageStu',
    'teach': 'homeageStu',
    'grad': 'homeageStu',
    'srtp': 'homeageStu',
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
        // 先尝试用已存账号密码自动重登，刷新 ehall 会话（CASTGC），
        // 让 bootstrapLogin 的 WebView SSO 能正常放行；失败也不影响后续降级。
        try {
          final auth = AuthService(sharedClient: _client);
          await auth.autoRelogin();
        } catch (_) {}
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
        // 同 HTTP 401：先自动重登刷新 ehall 会话，再走 WebView SSO
        try {
          final auth = AuthService(sharedClient: _client);
          await auth.autoRelogin();
        } catch (_) {}
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
        // bootstrap 也失败 → 抛"登录已过期"，页面据此走 _tryBootstrap
        // → 失败后显示"重新登录"按钮（不能抛 [code=401]，页面无法识别）
        throw Exception('登录已过期，请重新登录');
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
  Future<bool> bootstrapLogin({String? moduleId}) {
    moduleId ??= 'race';
    // 互斥锁：串行化 WebView 引导登录。
    // race 双 Tab 同时 init、request 401 自愈与页面 _tryBootstrap 并发调用时，
    // 多个 HeadlessInAppWebView 会互相 deleteAllCookies 清空对方注入的 cookie，
    // 导致 SSO 混乱（症状"时好时坏"）。所有 bootstrap 请求排队执行。
    final prev = _bootstrapLock ?? Future.value();
    final run = prev.then((_) => _bootstrapLogin(moduleId!));
    // 无论成败都推进锁链，避免一次失败卡死后续所有登录
    _bootstrapLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// 互斥锁状态（见 [bootstrapLogin]）
  Future<void>? _bootstrapLock;

  /// 单次引导登录（含短路 + 自动重登重试），由 [bootstrapLogin] 串行化调用
  Future<bool> _bootstrapLogin(String moduleId) async {
    // 该模块已有 token 且未过期就直接用
    if (await isLoggedIn(moduleId: moduleId)) return true;

    // 第一次尝试：用当前 _client 持久化的 cookie 注入 WebView。
    if (await _bootstrapOnce(moduleId)) return true;

    // 首次失败：持久化的 CASTGC / ehall 会话多半已在服务端过期，
    // _client 里是"死 cookie"，注入 WebView 只会触发 CAS 重定向回环
    // （这正是"清掉应用数据重新登录就好、过段时间又坏"的根因）。
    // 用已存账号密码静默重登刷新 _client，再重试一次。
    try {
      final auth = AuthService(sharedClient: _client);
      if (await auth.autoRelogin()) {
        await clearAuthToken(moduleId: moduleId);
        return await _bootstrapOnce(moduleId);
      }
    } catch (_) {
      debugPrint('Scjx2: autoRelogin during bootstrap failed');
    }
    return false;
  }

  /// 单次引导登录尝试（不含自动重登重试）。逻辑详见 [bootstrapLogin]。
  Future<bool> _bootstrapOnce(String moduleId) async {
    InAppWebViewController? controller;
    final cookieManager = CookieManager.instance();

    // 0. 重置 WebView 累积状态，打破 CAS 重定向回环 / 学校风控
    //    实测：cookie + 缓存累积后网页会陷入刷新循环（进不去），清缓存即恢复。
    //    只清 scjx2 域不够，必须连 CAS/authserver 侧 cookie + HTTP 缓存一起清。
    //    随后 _injectEhallCookiesToWebView 会重新注入 ehall SSO cookie，全清安全。
    try {
      await cookieManager.deleteAllCookies();
      debugPrint('Scjx2: reset - deleted all WebView cookies');
    } catch (e) {
      debugPrint('Scjx2: failed to delete all cookies: $e');
    }

    // 1. 注入 ehall 已有的 cookie 到 WebView
    await _injectEhallCookiesToWebView(cookieManager);

    final entryUrl = _moduleEntry[moduleId] ?? _moduleEntry['race']!;
    final modulePath = _modulePath[moduleId] ?? '/RACE/';
    debugPrint('Scjx2: bootstrap for module=$moduleId, entry=$entryUrl');

    // 刷新回环检测：统计 10s 内**同一 URL** 的加载次数，≥3 次判定为回环。
    // 关键：按 URL 区分，而不是按总跳转次数——正常 CAS SSO 链路
    // （zxcas → authserver → ticket 回跳 → scjx2 home → 模块）每个 URL 只加载
    // 一次，快网络下 4s 内 6+ 跳完全正常，旧"4s 内 6 次"判定会误伤自愈
    // （这正是"用久了突然不行、清缓存碰运气能好"的原因之一）；
    // 真正的刷新回环是同一 URL 反复自重载。
    final urlLoadTimes = <String, List<DateTime>>{};
    var loopDetected = false;
    var didLoopReset = false;

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
        // 清 HTTP 缓存（用户反馈清缓存可破风控刷新循环）
        try {
          await InAppWebViewController.clearAllCache();
          debugPrint('Scjx2: cleared WebView HTTP cache');
        } catch (e) {
          debugPrint('Scjx2: failed to clear cache: $e');
        }
        await Future.delayed(const Duration(milliseconds: 200));
        await _injectEhallCookiesToWebView(cookieManager);
        await Future.delayed(const Duration(milliseconds: 100));
        await ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(entryUrl)));
      },
      onLoadStart: (ctrl, url) {
        final urlStr = url.toString();
        final now = DateTime.now();
        final times = urlLoadTimes.putIfAbsent(urlStr, () => <DateTime>[]);
        times.removeWhere((t) => now.difference(t).inMilliseconds > 10000);
        times.add(now);
        if (times.length >= 3) {
          loopDetected = true;
          debugPrint('Scjx2: REFRESH LOOP detected '
              '(${times.length} loads of same URL in 10s) url=$urlStr');
        }
      },
    );

    await headlessWebView.run();
    try {
      // ---- 1. 等待 zxcas → CAS SSO → 默认模块主页（一般是 RACE） ----
      bool reachedHome = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));

        // 检测到刷新回环：硬重置一次（清缓存 + 全清 cookie + 重新注入 SSO + 重载）。
        // 这正是用户手动"清理缓存（尤其 cookie）"能恢复的原理。
        if (loopDetected) {
          if (!didLoopReset) {
            didLoopReset = true;
            loopDetected = false;
            urlLoadTimes.clear();
            // 仅尝试一次重置：清缓存 + 全清 cookie + 重新注入 SSO + 重载。
            // 这正是用户手动"清理缓存（尤其 cookie）"能恢复的原理。
            debugPrint('Scjx2: breaking refresh loop - hard reset + reload');
            try {
              await InAppWebViewController.clearAllCache();
              await cookieManager.deleteAllCookies();
            } catch (e) {
              debugPrint('Scjx2: loop reset error: $e');
            }
            await _injectEhallCookiesToWebView(cookieManager);
            await controller?.reload();
            continue;
          } else {
            // 已重置过一次仍在回环 → 证明不是缓存问题，而是注入的 cookie 已失效
            // （服务端已过期）。标记失败，交回 bootstrapLogin 走自动重登刷新。
            debugPrint('Scjx2: loop persists after reset - stale credential, '
                'abort to outer autoRelogin');
            reachedHome = false;
            break;
          }
        }

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

  /// 把 SharedHttpClient 中 ehall/yibinu/authserver 域的 cookie 注入到 WebView
  ///
  /// 用户已经在 ehall 登录过，authserver.yibinu.edu.cn 已有 session。
  /// 把这些 cookie 注入 WebView 后，WebView 访问 scjx2/zxcas 时会自动走
  /// CAS SSO 跳过输入页直接 ticket 跳回 RACE。
  ///
  /// ⚠️ 按原域注入（而非统一挂 .yibinu.edu.cn 父域）：
  /// - CASTGC：CAS TGC，父域 .yibinu.edu.cn（Secure+HttpOnly），
  ///   authserver/ehall/scjx2 都会携带；
  /// - authserver 自己的 cookie（JSESSIONID 等）→ authserver 域；
  /// - ehall 业务 cookie（MOD_AUTH_CAS/_WEU/route/JSESSIONID 等）→ ehall 域。
  /// 旧实现把 ehall 的 cookie 全量挂到父域，authserver 会收到一堆本不该
  /// 发给它的 cookie（含多个历史过期变体——本地罐从不清理且忽略 path），
  /// 干扰 CAS 会话判定，是"cookie 太多导致回环"的根源。
  Future<void> _injectEhallCookiesToWebView(CookieManager cookieManager) async {
    try {
      final allCookies = _client.getAllCookies();
      debugPrint('Scjx2: client cookies buckets = ${allCookies.keys.toList()}');
      for (final e in allCookies.entries) {
        debugPrint('  ${e.key}: ${e.value.length} cookies = ${e.value.keys.toList()}');
      }

      // 兜底：CASTGC 可能落在带前导点的桶(.yibinu.edu.cn)或其他桶，
      // 必须确保它进入注入集合（authserver 凭 CASTGC 才放行 SSO）。
      String? castgc;
      for (final bucket in allCookies.values) {
        final v = bucket['CASTGC'];
        if (v != null && v.isNotEmpty) {
          castgc = v;
          break;
        }
      }

      if (castgc == null || castgc.isEmpty) {
        debugPrint('Scjx2: no CASTGC to inject (user not logged in)');
      }

      var ok = 0;
      var total = 0;

      // 逐条注入；value 含 ';' 的坏 cookie 跳过（会截断请求头解析）
      void inject(String url, String name, String value,
          {String? domain, bool secure = false, bool httpOnly = false}) {
        total++;
        if (value.contains(';') || name.isEmpty) return;
        try {
          cookieManager.setCookie(
            url: WebUri(url),
            name: name,
            value: value,
            domain: domain,
            path: '/',
            isSecure: secure,
            isHttpOnly: httpOnly,
          );
          ok++;
        } catch (err) {
          debugPrint('Scjx2: failed to set $name: $err');
        }
      }

      // 1) CASTGC → 父域（Secure + HttpOnly，否则 https 请求 authserver 不带它）
      if (castgc != null && castgc.isNotEmpty) {
        inject('https://authserver.yibinu.edu.cn', 'CASTGC', castgc,
            domain: '.yibinu.edu.cn', secure: true, httpOnly: true);
      }

      // 2) authserver 自己的 cookie → authserver 域
      final authCookies = allCookies['authserver.yibinu.edu.cn'] ?? {};
      for (final e in authCookies.entries) {
        if (e.key == 'CASTGC') continue;
        inject('https://authserver.yibinu.edu.cn', e.key, e.value);
      }

      // 3) ehall 业务 cookie → ehall 域（浏览器只对该域发送）
      final ehallCookies = allCookies['ehall.yibinu.edu.cn'] ?? {};
      for (final e in ehallCookies.entries) {
        if (e.key == 'CASTGC') continue;
        inject('https://ehall.yibinu.edu.cn', e.key, e.value,
            domain: 'ehall.yibinu.edu.cn');
      }

      // 4) yibinu 父域的其他 cookie（如 route 等）→ 父域
      final yibinuCookies = allCookies['yibinu.edu.cn'] ?? {};
      for (final e in yibinuCookies.entries) {
        if (e.key == 'CASTGC') continue;
        inject('https://authserver.yibinu.edu.cn', e.key, e.value,
            domain: '.yibinu.edu.cn');
      }

      debugPrint('Scjx2: injected $ok/$total cookies'
          '${castgc != null && castgc.isNotEmpty ? " (CASTGC present)" : " (CASTGC missing)"}');

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
