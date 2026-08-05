import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide LocalStorage;

import 'http_client.dart';

/// 统一认证（CAS）cookie 与 WebView 的公共注入工具
///
/// 邮件系统（phpCAS 2.0）、CARSI（Shibboleth IdP 复用校内 CAS 会话）等
/// SSO WebView 场景共用：把 [SharedHttpClient] 中持久化的 **CASTGC**（TGC）
/// 注入全局 [CookieManager]（`CookieManager.instance()` 全应用共享，headless
/// bootstrap 与普通 WebView 互通）。
///
/// ⚠️ 按原域注入（参考 scjx2 注入教训，不把 ehall 业务 cookie 挂到 CAS 父域）：
/// - CASTGC：CAS TGC，父域 `.yibinu.edu.cn`（Secure + HttpOnly），
///   https authserver 凭它自动放行 SSO；
/// - authserver 自己的 cookie（JSESSIONID 等）→ authserver 域。
/// 各站点自身会话（邮件 PHPSESSID / CARSI SAML cookie）由服务端回跳
/// Set-Cookie 建立，无需注入。
///
/// ⚠️ 注入前应先 [AuthService.ensureFreshSession] 预热：App 运行期间
/// CASTGC 可能在服务端过期，直接注入"死 cookie"会卡在 CAS 登录页。
///
/// 返回成功注入数量；0 表示本地没有可用的统一认证会话。
Future<int> injectCasCookiesToWebView(
  SharedHttpClient client,
  CookieManager cookieManager,
) async {
  try {
    final allCookies = client.getAllCookies();
    debugPrint('CasWebview: client cookie buckets = ${allCookies.keys.toList()}');

    // 兜底：CASTGC 可能落在任意桶，必须确保进入注入集合
    String? castgc;
    for (final bucket in allCookies.values) {
      final v = bucket['CASTGC'];
      if (v != null && v.isNotEmpty) {
        castgc = v;
        break;
      }
    }

    var ok = 0;
    var total = 0;
    void inject(String url, String name, String value,
        {String? domain, bool secure = false, bool httpOnly = false}) {
      total++;
      if (name.isEmpty || value.contains(';')) return;
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
        debugPrint('CasWebview: failed to set $name: $err');
      }
    }

    // 1) CASTGC → 父域（Secure + HttpOnly，https authserver 才携带）
    if (castgc != null && castgc.isNotEmpty) {
      inject('https://authserver.yibinu.edu.cn', 'CASTGC', castgc,
          domain: '.yibinu.edu.cn', secure: true, httpOnly: true);
    }

    // 2) authserver 自己的 cookie → authserver 域
    final authCookies = allCookies['authserver.yibinu.edu.cn'] ?? {};
    for (final e in authCookies.entries) {
      if (e.key == 'CASTGC') continue;
      inject('https://authserver.yibinu.edu.cn', e.key, e.value,
          domain: 'authserver.yibinu.edu.cn');
    }

    debugPrint('CasWebview: injected $ok/$total cookies'
        '${castgc != null && castgc.isNotEmpty ? " (CASTGC present)" : " (CASTGC missing)"}');
    return ok;
  } catch (e) {
    debugPrint('CasWebview.injectCasCookiesToWebView error: $e');
    return 0;
  }
}
