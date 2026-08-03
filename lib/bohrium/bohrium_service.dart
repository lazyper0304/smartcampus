import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide LocalStorage;

import '../core/http_client.dart';
import '../core/local_storage.dart';

/// 玻尔科研平台（yibinu.bohrium.com）Service
///
/// 平台为深势科技 Bohrium 高校定制版，使用学校 CAS 统一认证：
/// - 未登录访问 → 后端 302 到 authserver.yibinu.edu.cn CAS 登录
/// - CAS 验证通过后回跳 `https://yibinu.bohrium.com/cas_login?ticket=...`
/// - 前端 POST `/platform-gateway/v1/account/cas_login` 用 ticket 兑换 token
/// - token 写入 localStorage/cookie `brmToken`
///
/// 因此 App 内免登录的关键是：把已登录 ehall 时 SharedHttpClient 中
/// 持久化的 authserver CASTGC（TGC）注入 WebView，让 CAS SSO 自动放行，
/// 与学工系统 / scjx2 的注入策略一致。
class BohriumService {
  final SharedHttpClient _client;

  /// 平台入口（首页）
  static const String baseUrl = 'https://yibinu.bohrium.com';

  /// LocalStorage key：上次 cookie 注入时间戳（供会话过期判断，可选）
  static const String _kLastInjectAt = 'bohrium_last_inject_at';

  BohriumService({required SharedHttpClient client}) : _client = client;

  /// 把 SharedHttpClient 中 ehall / CAS 相关的 cookie 注入 WebView
  ///
  /// 覆盖域：authserver.yibinu.edu.cn（CASTGC 落点）、yibinu.edu.cn 父域、
  /// ehall.yibinu.edu.cn。CASTGC 是 Secure/HttpOnly 的 TGC，必须带
  /// `isSecure` + `isHttpOnly` + 前导点父域注入，否则 https 请求
  /// authserver 时 WebView 不会携带它 → SSO 失败。
  ///
  /// 返回成功注入的 cookie 数量；0 表示客户端没有可用的 CAS 会话。
  Future<int> injectCasCookiesToWebView(CookieManager cookieManager) async {
    try {
      final allCookies = _client.getAllCookies();
      debugPrint('Bohrium: client cookie buckets = ${allCookies.keys.toList()}');

      final authCookies = allCookies['authserver.yibinu.edu.cn'] ?? {};
      final yibinuCookies = allCookies['yibinu.edu.cn'] ?? {};
      final ehallCookies = allCookies['ehall.yibinu.edu.cn'] ?? {};

      // 兜底：CASTGC 可能落在任意带前导点或其他桶，必须确保进注入集合
      String? castgc;
      for (final bucket in allCookies.values) {
        final v = bucket['CASTGC'];
        if (v != null && v.isNotEmpty) {
          castgc = v;
          break;
        }
      }

      // 合并：父域优先，再叠加子域，最后补 CASTGC
      final merged = <String, String>{};
      merged.addAll(yibinuCookies);
      merged.addAll(ehallCookies);
      merged.addAll(authCookies);
      if (castgc != null && castgc.isNotEmpty) {
        merged['CASTGC'] = castgc;
      }

      if (merged.isEmpty) {
        debugPrint('Bohrium: no CAS cookies to inject (not logged in)');
        return 0;
      }

      debugPrint('Bohrium: injecting ${merged.length} cookies'
          '${castgc != null && castgc.isNotEmpty ? " (CASTGC present)" : " (CASTGC missing)"}');

      int ok = 0;
      for (final e in merged.entries) {
        final isCastgc = e.key == 'CASTGC';
        try {
          await cookieManager.setCookie(
            url: WebUri('https://authserver.yibinu.edu.cn'),
            name: e.key,
            value: e.value,
            domain: '.yibinu.edu.cn',
            path: '/',
            // 目标域全部走 https（CAS/玻尔平台），统一按 Secure 注入
            isSecure: true,
            isHttpOnly: isCastgc,
          );
          ok++;
        } catch (err) {
          debugPrint('Bohrium: failed to set ${e.key}: $err');
        }
      }

      await LocalStorage.setString(_kLastInjectAt, DateTime.now().toIso8601String());
      debugPrint('Bohrium: injected $ok/${merged.length} cookies');
      return ok;
    } catch (e) {
      debugPrint('Bohrium.injectCasCookiesToWebView error: $e');
      return 0;
    }
  }

  /// 客户端是否存在可用的 CAS 会话（仅判断本地有没有 CASTGC 可注入）
  ///
  /// 注意：CASTGC 在服务端有过期时间（默认约 1 天），本地存在不代表
  /// 一定有效；无效时 WebView 会自然落到 CAS 登录页，用户可手动登录，
  /// 由服务端 Set-Cookie 建立真实会话。
  bool hasLocalCasSession() {
    final all = _client.getAllCookies();
    for (final bucket in all.values) {
      if (bucket['CASTGC']?.isNotEmpty ?? false) return true;
    }
    return false;
  }
}
