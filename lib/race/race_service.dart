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

    final result = await _fetchViaApi(page, pageSize);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 走 API 调用
  Future<RacePageResult> _fetchViaApi(int page, int pageSize) async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('未登录 scjx2，请先登录');
    }

    final body = <String, dynamic>{
      'currpage': page,
      'pagesize': pageSize,
    };

    final menuId = await LocalStorage.getString(_kMenuId) ?? '';

    // 构造签名头
    final headers = _signer.buildHeaders(
      data: body,
      menuId: menuId,
      authorization: token,
    );

    final uri = Uri.parse('$baseUrl/race/race/stuRace/listStuRacePage');
    debugPrint('Race API: POST $uri page=$page pageSize=$pageSize');

    final resp = await _client.postJson(
      uri,
      body: body,
      headers: headers,
    );

    if (resp.statusCode != 200) {
      // 401 表示 token 过期，需要重新登录
      if (resp.statusCode == 401) {
        await clearAuthToken();
        throw Exception('登录已过期，请重新登录');
      }
      throw Exception('学科竞赛接口失败 (HTTP ${resp.statusCode})');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final code = json['code'];
    if (code != 200) {
      final msg = json['msg']?.toString() ?? '未知错误';
      // 401 业务码也表示 token 过期
      if (code == 401 || resp.body.contains('未登录') || resp.body.contains('token')) {
        await clearAuthToken();
      }
      throw Exception('学科竞赛接口错误: $msg');
    }

    return RacePageResult.fromJson(json);
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

      // ---- 4. 缓存到 LocalStorage ----
      await setAuthToken(key1);
      if (menuId != null && menuId.isNotEmpty) {
        await LocalStorage.setString(_kMenuId, menuId);
      }
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.setString(_kUserId, userId);
      }

      return true;
    } catch (e) {
      debugPrint('RaceService.bootstrapLogin error: $e');
      return false;
    } finally {
      await headlessWebView.dispose();
    }
  }
}
