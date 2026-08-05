import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide LocalStorage;

import '../core/cas_webview.dart' as cas_webview;
import '../core/http_client.dart';

/// 宜宾学院邮件系统（mailmid.yibinu.edu.cn）Service
///
/// 邮件系统使用 phpCAS 1.3.2（CAS 2.0）接入学校统一认证：
/// - 未登录访问 `oauthLogin` → 302 到 authserver.yibinu.edu.cn CAS 登录页
///   （`service=http://mailmid.yibinu.edu.cn/index/index/oauthLogin`）
/// - CAS 验证通过（携带有效 CASTGC）→ 302 回 `oauthLogin?ticket=ST-xxx`
/// - phpCAS 验证 ticket → 建立邮件系统自身 PHPSESSID 会话
///
/// 因此 App 内免登录的关键：把 SharedHttpClient 中持久化的 **CASTGC**（TGC）
/// 注入 WebView（CASTGC 只在 https authserver 上消费，mailmid 自身的
/// PHPSESSID 由服务端 Set-Cookie 建立）。
class MailService {
  final SharedHttpClient _client;

  /// OAuth 登录入口（http！邮件系统明文站点，Android 已开 usesCleartextTraffic）
  static const String baseUrl =
      'http://mailmid.yibinu.edu.cn/index/index/oauthLogin';

  /// 邮件系统主页（登录后通常停留于此）
  static const String homeUrl = 'http://mailmid.yibinu.edu.cn/';

  MailService({required SharedHttpClient client}) : _client = client;

  /// 把统一认证 cookie 注入 WebView
  ///
  /// ⚠️ 按原域注入（参考 scjx2 注入教训，不把 ehall 业务 cookie 挂到 CAS 父域）：
  /// - CASTGC：CAS TGC，父域 `.yibinu.edu.cn`（Secure + HttpOnly），
  ///   https authserver 凭它自动放行 SSO；
  /// - authserver 自己的 cookie（JSESSIONID 等）→ authserver 域。
  /// 邮件系统自身的 PHPSESSID 无需注入（服务端回跳时 Set-Cookie 建立）。
  ///
  /// 公共实现见 [injectCasCookiesToWebView]（core/cas_webview.dart，
  /// 邮件 / CARSI 等 SSO WebView 共用）。注入前建议先预热会话
  /// （[AuthService.ensureFreshSession]），避免注入运行期已过期的死 CASTGC。
  ///
  /// 返回成功注入数量；0 表示本地没有可用的统一认证会话。
  Future<int> injectCasCookiesToWebView(CookieManager cookieManager) {
    return cas_webview.injectCasCookiesToWebView(_client, cookieManager);
  }

  /// 本地是否存在可用的统一认证会话（仅判断有没有 CASTGC 可注入；
  /// 服务端过期时 WebView 会自然落到 CAS 登录页，可手动登录兜底）
  bool hasLocalCasSession() {
    final all = _client.getAllCookies();
    for (final bucket in all.values) {
      if (bucket['CASTGC']?.isNotEmpty ?? false) return true;
    }
    return false;
  }
}
