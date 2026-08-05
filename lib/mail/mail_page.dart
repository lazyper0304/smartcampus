import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/http_client.dart';
import '../news/webview_page.dart';
import 'mail_service.dart';

/// 宜宾学院邮件系统
///
/// 复用通用 [WebViewPage]：加载前注入统一认证 CASTGC cookie
/// （oauthLogin → authserver CAS 自动放行 → 免密进入邮箱）。
/// cookie 失效时 WebView 会自然落到 CAS 登录页，可在页面内手动登录兜底。
class MailPage extends StatelessWidget {
  final SharedHttpClient client;

  const MailPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return WebViewPage(
      url: MailService.baseUrl,
      title: '邮件系统',
      onWebViewReady: (controller) async {
        await MailService(client: client)
            .injectCasCookiesToWebView(CookieManager.instance());
      },
    );
  }
}
