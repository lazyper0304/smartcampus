import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../auth/auth_service.dart';
import '../core/http_client.dart';
import '../news/webview_page.dart';
import 'mail_service.dart';

/// 宜宾学院邮件系统
///
/// 复用通用 [WebViewPage]：加载前注入统一认证 CASTGC cookie
/// （oauthLogin → authserver CAS 自动放行 → 免密进入邮箱）。
/// cookie 失效时 WebView 会自然落到 CAS 登录页，可在页面内手动登录兜底。
///
/// ⚠️ 进入前先 [AuthService.ensureFreshSession] 预热：App 运行期间
/// CASTGC 可能在服务端过期（本地是"死 cookie"），不预热会卡在 CAS
/// 登录页——此前只有先访问学科竞赛（bootstrap 自愈刷新）才能进。
class MailPage extends StatelessWidget {
  final SharedHttpClient client;

  const MailPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return WebViewPage(
      url: MailService.baseUrl,
      title: '邮件系统',
      onWebViewReady: (controller) async {
        // 1. 会话预热：本地 CASTGC 过期（或缺失）时静默重登刷新
        await AuthService(sharedClient: client).ensureFreshSession();
        // 2. 注入新鲜的统一认证 cookie
        await MailService(client: client)
            .injectCasCookiesToWebView(CookieManager.instance());
      },
    );
  }
}
