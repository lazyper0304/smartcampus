import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide LocalStorage;

import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../core/data_cache.dart';
import 'race.dart';
import 'race_signer.dart';

/// 学科竞赛服务（API 模式）
///
/// 通过分析 scjx2 RACE 系统前端 JavaScript，逆向出 API 签名算法：
/// - signature: HMAC-SHA512("{ts}-{nonce}", "zxtd_256-bit-secret-key-2025-8-7")
/// - zhxhsign:   HMAC-SHA256(serialized_params, "zhxintd201020301")
///
/// 直接使用 SharedHttpClient + 自构造签名头调用后端 API，
/// 不再需要 HeadlessInAppWebView 加载页面提取数据。
///
/// JWT 授权（Authorization）由 zxcas 登录引导流程获取并缓存到 LocalStorage。
class RaceService {
  final SharedHttpClient _client;
  final RaceApiSigner _signer = RaceApiSigner();

  static const String baseUrl = 'https://scjx2.yibinu.edu.cn';

  /// LocalStorage key：缓存 zxcas 登录后从 sessionStorage 提取的 JWT
  static const String _kAuthToken = 'race_auth_token';

  /// LocalStorage key：zxcas 登录时设置的 user_id（备用标识）
  static const String _kUserId = 'race_user_id';

  /// LocalStorage key：MenuId
  static const String _kMenuId = 'race_menu_id';

  RaceService({required SharedHttpClient client}) : _client = client;

  /// 获取缓存的 JWT token
  Future<String?> getAuthToken() async {
    return await LocalStorage.getString(_kAuthToken);
  }

  /// 保存 JWT token
  Future<void> setAuthToken(String token) async {
    await LocalStorage.setString(_kAuthToken, token);
  }

  /// 清除 JWT token（用于重新登录）
  Future<void> clearAuthToken() async {
    await LocalStorage.remove(_kAuthToken);
    await LocalStorage.remove(_kUserId);
    await LocalStorage.remove(_kMenuId);
  }

  /// 是否已登录（有有效 token）
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// 拉取学科竞赛列表
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

    final body = <String, dynamic>{
      'currpage': page,
      'pagesize': pageSize,
    };
    final json = await _request(
      path: '/race/race/stuRace/listStuRacePage',
      data: body,
    );
    final result = RacePageResult.fromJson(json);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 拉取学科竞赛详情
  Future<RaceDetail> fetchRaceDetail(String raceId) async {
    final cacheKey = 'race_detail_$raceId';
    final cached = DataCache().get<RaceDetail>(cacheKey);
    if (cached != null) return cached;

    final json = await _request(
      path: '/race/race/stuRace/toRaceApply',
      params: {'race_id': raceId},
    );
    final detail = RaceDetail.fromJson(json);
    DataCache().set(cacheKey, detail);
    return detail;
  }

  /// 通用 RACE API 请求
  ///
  /// - [path]: API 路径（不含域名）
  /// - [data]: POST body 字典（可为 null）
  /// - [params]: query string 字典（可为 null）
  /// - [retryCount]: 内部递归计数器（401 时自动重新登录后重试一次）
  Future<Map<String, dynamic>> _request({
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? params,
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
    );

    // 拼 URL（带 query string）
    final base = '$baseUrl$path';
    final uri = params != null && params.isNotEmpty
        ? Uri.parse(base).replace(queryParameters: {
            for (final e in params.entries) e.key: e.value.toString(),
          })
        : Uri.parse(base);

    debugPrint('Race API: POST $uri');
    debugPrint('  headers: ${headers.keys.toList()}');
    debugPrint('  body: ${data ?? "{}"}');

    final resp = await _client.postJson(
      uri,
      body: data,  // null 时发空 body
      headers: headers,
    );

    debugPrint('  status: ${resp.statusCode}');
    debugPrint('  resp.body (前500): ${resp.body.length > 500 ? "${resp.body.substring(0, 500)}..." : resp.body}');

    if (resp.statusCode != 200) {
      if (resp.statusCode == 401 && retryCount < 1) {
        // token 过期或 cookie 缺失，尝试重新登录后重试一次
        await clearAuthToken();
        final ok = await bootstrapLogin();
        if (ok) {
          return _request(
            path: path,
            data: data,
            params: params,
            retryCount: retryCount + 1,
          );
        }
        throw Exception('登录已过期，请重新登录');
      }
      throw Exception('RACE 接口失败 (HTTP ${resp.statusCode})');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final code = json['code'];
    if (code != 200) {
      final msg = json['msg']?.toString() ?? '未知错误';
      if (code == 401 && retryCount < 1) {
        // 业务 401：尝试重新登录后重试
        await clearAuthToken();
        final ok = await bootstrapLogin();
        if (ok) {
          return _request(
            path: path,
            data: data,
            params: params,
            retryCount: retryCount + 1,
          );
        }
      }
      throw Exception('RACE 接口错误 [code=$code]: $msg');
    }

    return json;
  }

  /// 通过 HeadlessInAppWebView 引导登录 zxcas，提取 JWT
  ///
  /// 流程：
  /// 1. 加载 https://scjx2.yibinu.edu.cn/zxcas → 自动跳转到 authserver
  /// 2. 如果已登录会自动回到 scjx2 主应用
  /// 3. 等待主应用加载（路由到 /homeageStu）
  /// 4. 等待 zxStorage.getItem('key1') 被设置（GetUserInfo action 触发）
  /// 5. 从 window.sessionStorage 提取 JWT，缓存到 LocalStorage
  ///
  /// 返回是否成功获取到 token
  Future<bool> bootstrapLogin({Duration timeout = const Duration(seconds: 90)}) async {
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
      // ---- 1. 等待 CAS 登录 + 主页加载 ----
      bool reachedHome = false;
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final url = (await controller?.getUrl())?.toString() ?? '';
        if (url.contains('homeageStu')) {
          debugPrint('RaceService: reached home after ${i + 1}s');
          reachedHome = true;
          break;
        }
      }

      if (!reachedHome) {
        final url = (await controller?.getUrl())?.toString() ?? '';
        if (url.contains('authserver') || url.contains('casLoginForm')) {
          debugPrint('RaceService: still on CAS login page');
          return false;
        }
        // 其他情况再等一会儿
        await Future.delayed(const Duration(seconds: 3));
      }

      // ---- 2. 确保进入主路由，触发 GetUserInfo ----
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

      // ---- 3. 反复尝试从 sessionStorage 提取 token ----
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
              debugPrint('RaceService: got key1 (${key1.length} chars) on attempt ${attempt + 1}');
              break;
            }
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (key1 == null || key1.isEmpty) {
        debugPrint('RaceService: failed to extract key1');
        return false;
      }

      // ---- 4. 缓存到 LocalStorage + 同步 cookie 到 SharedHttpClient ----
      await setAuthToken(key1);
      if (menuId != null && menuId.isNotEmpty) {
        await LocalStorage.setString(_kMenuId, menuId);
      }
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.setString(_kUserId, userId);
      }

      // 把 WebView 登录后产生的 scjx2/authserver cookie 同步到 SharedHttpClient
      await _syncCookiesFromWebView(controller);

      return true;
    } catch (e) {
      debugPrint('RaceService.bootstrapLogin error: $e');
      return false;
    } finally {
      await headlessWebView.dispose();
    }
  }

  /// 把 WebView 中的 cookie 同步到 SharedHttpClient
  ///
  /// scjx2.yibinu.edu.cn 域的 Set-Cookie 在 WebView 登录后产生，
  /// 但 SharedHttpClient 不知道，需要手动拉取并注入
  Future<void> _syncCookiesFromWebView(InAppWebViewController? controller) async {
    if (controller == null) return;
    try {
      final js = '''
(function() {
  try {
    var all = document.cookie || '';
    return all;
  } catch(e) {
    return '';
  }
})();
''';
      final result = await controller.evaluateJavascript(source: js);
      final cookieStr = result?.toString() ?? '';
      if (cookieStr.isEmpty) return;
      debugPrint('RaceService: syncing cookies (${cookieStr.length} chars)');

      // 解析 cookie 字符串
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

      // 注入到 SharedHttpClient 的 scjx2 / authserver 域名 bucket
      _client.setCookiesForDomain('scjx2.yibinu.edu.cn', cookieMap);
      _client.setCookiesForDomain('authserver.yibinu.edu.cn', cookieMap);
      _client.setCookiesForDomain('yibinu.edu.cn', cookieMap);
      debugPrint('RaceService: injected ${cookieMap.length} cookies');
    } catch (e) {
      debugPrint('RaceService._syncCookiesFromWebView error: $e');
    }
  }
}
