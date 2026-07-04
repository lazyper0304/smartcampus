import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:html/parser.dart' as html_parser;

import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'raw_http_client.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

/// 学工系统 HTTP 模式调试页面（纯 SSO，不需要手动输入密码）
class XuegongHttpTestPage extends StatefulWidget {
  final SharedHttpClient client;

  const XuegongHttpTestPage({super.key, required this.client});

  @override
  State<XuegongHttpTestPage> createState() => _XuegongHttpTestPageState();
}

class _XuegongHttpTestPageState extends State<XuegongHttpTestPage> {
  bool _running = false;
  final _logs = <_LogEntry>[];
  final _rawClient = RawHttpClient();

  // ── SSO 参数 ──
  static const String _xuegongUrl =
      'https://ybxyxsglxt.yibinu.edu.cn/toIndex.htm?newTab=&tabName=';
  static const String _casUrl =
      'http://authserver.yibinu.edu.cn/authserver/login';

  String get _ssoUrl =>
      '$_casUrl?service=${Uri.encodeComponent(_xuegongUrl)}';

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HTTP 模式调试'),
          centerTitle: true,
          actions: [
            if (_logs.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => setState(() => _logs.clear()),
                tooltip: '清除日志',
              ),
          ],
        ),
        body: Column(
          children: [
            // ── 顶部操作区 ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: _running
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(_running ? '执行中…' : '执行 SSO 测试'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _yibinBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _running ? null : () => _runSsoDebug(),
                    ),
                  ),
                ],
              ),
            ),

            // ── 日志列表 ──
            Expanded(
              child: _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bug_report_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('点击上方按钮开始调试',
                              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) => _buildLogCard(_logs[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(_LogEntry entry) {
    final icon = entry.isError
        ? Icons.error_outline
        : entry.isSuccess
            ? Icons.check_circle_outline
            : Icons.info_outline;
    final iconColor = entry.isError
        ? Colors.red
        : entry.isSuccess
            ? Colors.green
            : _yibinBlue;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: iconColor)),
              ),
            ]),
            if (entry.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  entry.body.length > 2000
                      ? '${entry.body.substring(0, 2000)}\n\n…（已截断 ${entry.body.length} 字符）'
                      : entry.body,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _log(String title, String body, {bool isError = false, bool isSuccess = false}) {
    setState(() => _logs.add(_LogEntry(title, body, isError, isSuccess)));
  }

  // ── 核心调试流程 ──

  Future<void> _runSsoDebug() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    try {
      // 1. 检查已有 cookie
      await _checkCookies();

      // 2. 尝试 SSO
      await _attemptSso();

      // 3. 如果 SSO 成功，尝试获取页面
      await _tryFetchPage();
    } catch (e) {
      _log('异常', e.toString(), isError: true);
    }

    setState(() => _running = false);
  }

  Future<void> _checkCookies() async {
    // 显示 SharedHttpClient 中的所有域
    _log('检查 Cookie 存储', 'SharedHttpClient 中所有域名:', isSuccess: false);
    final allCookies = widget.client.getAllCookies();
    for (final entry in allCookies.entries) {
      final names = entry.value.keys.join(', ');
      _log('  → ${entry.key}', '$names', isSuccess: false);
    }

    // 检查 authserver 的 cookie
    final authCookies = widget.client.getCookiesForDomain('authserver.yibinu.edu.cn');
    _log('authserver cookie', authCookies.isNotEmpty ? authCookies : '(空)', isSuccess: authCookies.isNotEmpty);

    // 检查 LocalStorage 中的 saved cookies
    final savedRaw = await LocalStorage.getString('saved_cookies') ?? '(无)';
    _log('LocalStorage saved_cookies',
        savedRaw.length > 500 ? '${savedRaw.substring(0, 500)}…' : savedRaw, isSuccess: false);
  }

  Future<void> _attemptSso() async {
    _log('尝试 SSO', 'GET $_ssoUrl\nnoRedirect: true', isSuccess: false);

    try {
      final resp = await widget.client.get(
        Uri.parse(_ssoUrl),
        noRedirect: true,
      );

      if (resp.statusCode == 302) {
        final loc = resp.header('location') ?? '(无)';
        _log('SSO 成功（302）', 'Location: $loc', isSuccess: true);

        // 跟随重定向
        await _followRedirects(resp);
      } else if (resp.statusCode == 200) {
        // 返回了登录页
        final doc = html_parser.parse(resp.body);
        final title = doc.getElementsByTagName('title').firstOrNull?.text ?? '(无标题)';
        final hasForm = doc.getElementById('casLoginForm') != null;
      final snippet = resp.body.length > 120 ? resp.body.substring(0, 120) : resp.body;
        _log('SSO 失败（200）', '标题: $title\n包含登录表单: $hasForm\n响应前120字符:\n$snippet', isError: true);
      } else {
        _log('SSO 异常', 'HTTP ${resp.statusCode}', isError: true);
      }
    } catch (e) {
      _log('SSO 请求异常', e.toString(), isError: true);
    }
  }

  Future<void> _followRedirects(HttpResponse firstResp) async {
    var resp = firstResp;
    var hops = 0;
    final locations = <String>[];

    while ((resp.statusCode == 301 || resp.statusCode == 302 || resp.statusCode == 303) && hops < 10) {
      hops++;
      final loc = resp.header('location') ?? '(无 location)';
      locations.add('hop#$hops: ${resp.statusCode} → $loc');

      if (loc.isEmpty || loc == '(无 location)') break;
      final targetUri = Uri.parse(loc);

      if (hops == 1) {
        resp = await widget.client.postForm(targetUri, body: {}, noRedirect: true);
        if (resp.statusCode == 200 || resp.statusCode == 404 || resp.statusCode >= 500) {
          resp = await widget.client.get(targetUri, noRedirect: true);
        }
      } else {
        resp = await widget.client.get(targetUri, noRedirect: true);
      }
    }

    _log('重定向链 (${hops}跳)', locations.join('\n'), isSuccess: hops > 0);

    if (resp.statusCode == 200 || resp.statusCode == 1001) {
      _log('最终页面', 'HTTP ${resp.statusCode}, body len=${resp.body.length}', isSuccess: true);
    } else {
      _log('最终响应', 'HTTP ${resp.statusCode}', isSuccess: false);
    }

    // 查看获取到的学工系统 cookie
    final xuegongCookies = widget.client.getCookiesForDomain('ybxyxsglxt.yibinu.edu.cn');
    _log('学工系统 cookie', xuegongCookies.isNotEmpty ? xuegongCookies : '(空)', isSuccess: xuegongCookies.isNotEmpty);
  }

  Future<void> _tryFetchPage() async {
    final cookies = widget.client.getCookiesForDomain('ybxyxsglxt.yibinu.edu.cn');
    if (cookies.isEmpty) {
      _log('跳过获取页面', '无学工系统 cookie', isError: true);
      return;
    }

    final cookieMap = <String, String>{};
    for (final part in cookies.split('; ')) {
      final eq = part.indexOf('=');
      if (eq > 0) cookieMap[part.substring(0, eq)] = part.substring(eq + 1);
    }

    // 尝试完成第二层认证：先获取用户信息，再用用户名尝试自动登录
    _log('尝试获取用户信息', 'POST /syt/recive/getxxinfo.htm', isSuccess: false);
    try {
      final infoResp = await _rawClient.postForm(
        'https://ybxyxsglxt.yibinu.edu.cn/syt/recive/getxxinfo.htm',
        cookies: cookieMap,
        formBody: {},
        extraHeaders: {
          'Referer': 'https://ybxyxsglxt.yibinu.edu.cn/wiseduIndex.jsp',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      _log('用户信息响应: HTTP ${infoResp.statusCode}',
          'body: ${_trimBody(infoResp.body, 300)}',
          isSuccess: infoResp.statusCode == 200);
    } catch (e) {
      _log('获取用户信息异常', e.toString(), isError: true);
    }

    // 检查验证码状态
    _log('检查是否需要验证码',
        'GET /login/captcha/isvalid.htm?math.random()', isSuccess: false);
    try {
      final captchaResp = await _rawClient.get(
        'https://ybxyxsglxt.yibinu.edu.cn/login/captcha/isvalid.htm?${DateTime.now().millisecondsSinceEpoch}',
        cookies: cookieMap,
        extraHeaders: {
          'Referer': 'https://ybxyxsglxt.yibinu.edu.cn/wiseduIndex.jsp',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      _log('验证码状态: HTTP ${captchaResp.statusCode}',
          'body: ${_trimBody(captchaResp.body, 200)}',
          isSuccess: captchaResp.statusCode == 200);
    } catch (e) {
      _log('验证码检查异常', e.toString(), isError: true);
    }

    // 第二次尝试：用学号 + captchaResponse= （空，假设不需要验证码）
    _log('尝试用学号自动登录', 'POST /login/Login.htm (username + captchaResponse=)', isSuccess: false);
    try {
      final loginResp = await _rawClient.postForm(
        'https://ybxyxsglxt.yibinu.edu.cn/login/Login.htm',
        cookies: cookieMap,
        formBody: {'username': '240105118', 'captchaResponse': ''},
        extraHeaders: {
          'Referer': 'https://ybxyxsglxt.yibinu.edu.cn/wiseduIndex.jsp',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      _log('学号登录响应: HTTP ${loginResp.statusCode}',
          'body: ${_trimBody(loginResp.body, 300)}',
          isSuccess: loginResp.statusCode == 302 || !loginResp.body.contains('请输入') && !loginResp.body.contains('验证码'));
    } catch (e) {
      _log('自动登录异常', e.toString(), isError: true);
    }

    // 再尝试获取页面
    const urls = [
      'https://ybxyxsglxt.yibinu.edu.cn/toIndex.htm?newTab=&tabName=',
      'https://ybxyxsglxt.yibinu.edu.cn/syt/xsinfo/stuinfo.htm',
    ];

    for (final url in urls) {
      _log('RawHttp GET', url, isSuccess: false);
      try {
        final resp = await _rawClient.get(url, cookies: cookieMap);
        final bodyPreview = resp.body.length > 500
            ? '${resp.body.substring(0, 500)}\n…'
            : resp.body;
        _log('响应: HTTP ${resp.statusCode}', 'body: ${resp.body.length} 字符\n$bodyPreview',
            isSuccess: resp.statusCode == 200 || resp.statusCode == 1001);
      } catch (e) {
        _log('RawHttp 异常', e.toString(), isError: true);
      }
    }
  }
}

class _LogEntry {
  final String title;
  final String body;
  final bool isError;
  final bool isSuccess;

  _LogEntry(this.title, this.body, this.isError, this.isSuccess);
}

/// 安全截取字符串前 maxLen 字符
String _trimBody(String s, int maxLen) =>
    s.length > maxLen ? s.substring(0, maxLen) : s;
