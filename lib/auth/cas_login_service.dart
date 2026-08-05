import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:html/parser.dart' as html_parser;

import '../core/http_client.dart';
import 'captcha_service.dart';

/// CAS 登录被拒绝（账号/密码错误等业务性失败）——非网络/OCR 类，
/// 不重试；message 为友好文案（不抛 HTML 片段）。
class LoginRejectedException implements Exception {
  final String message;
  const LoginRejectedException(this.message);

  @override
  String toString() => message;
}

/// 金智教务系统 CAS 统一登录
/// 严格参考 yibinu-score-crawler + verify_yibinu_ehall + wisedu-unified-login-api 实现
///
/// 关键要点（参考 Java 参考实现）：
/// 1. ⚠️ 登录入口必须用 https service（http service 已被服务端拒绝，8/2 实测）
/// 2. CAS ticket 验证重定向使用 POST 方法跟随
/// 3. 每个页面跳转都会产生新 cookie，必须持续合并
/// 4. 连续输错密码会触发验证码，使用 ML Kit OCR 自动识别
class CasLoginService {
  static const String _chars =
      'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  /// 宜宾学院统一认证登录 URL
  ///
  /// ⚠️ 必须使用 https service（`service=https://ehall.yibinu.edu.cn:443/login?...`）：
  /// 2026-08-02 实测 http service（`http://ehall.../login`）POST 恒被拒
  /// （200 失败页无提示），https service 经 verify_yibinu.py 验证成功。
  static const String yibinLoginUrl =
      'https://authserver.yibinu.edu.cn/authserver/login'
      '?service=https%3A%2F%2Fehall.yibinu.edu.cn%3A443%2Flogin'
      '%3Fservice%3Dhttps%3A%2F%2Fehall.yibinu.edu.cn%2Fnew%2Findex.html';

  final SharedHttpClient client;

  CasLoginService({SharedHttpClient? sharedClient})
      : client = sharedClient ?? SharedHttpClient();

  /// 执行 CAS 登录，成功后 Cookie 已保存在 SharedHttpClient 中
  Future<void> login({
    String loginUrl = yibinLoginUrl,
    required String username,
    required String password,
  }) async {
    const desktopUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final uri = Uri.parse(loginUrl);
    final host = uri.host;

    // ── 1. GET 登录页 ──
    HttpResponse resp;
    resp = await client.get(uri, headers: _htmlHeaders(host, desktopUA));
    final doc = html_parser.parse(resp.body);
    final form = doc.getElementById('casLoginForm');
    if (form == null) throw Exception('未找到 casLoginForm');

    // ── 2. 提取隐藏字段 ──
    final params = <String, String>{};
    for (final input in form.getElementsByTagName('input')) {
      final name = input.attributes['name'] ?? '';
      if (name.isEmpty || name == 'rememberMe') continue;
      String val = input.attributes['value'] ?? '';
      if (name == 'username') val = username;
      params[name] = val;
    }

    // ── 3. 获取加密盐 ──
    String salt = 'E5b2IYX5TT1D79TA'; // 默认 fallback
    final saltMatch =
        RegExp(r'var pwdDefaultEncryptSalt = "(.+?)";').firstMatch(resp.body);
    if (saltMatch != null) salt = saltMatch.group(1)!;

    // 从 needCaptcha 接口获取更新后的盐（注意：needCaptcha 也用 https）
    final needResp = await client.get(
      Uri.parse('https://$host/authserver/needCaptcha.html'
          '?username=$username&pwdEncrypt2=pwdEncryptSalt'),
      headers: _htmlHeaders(host, desktopUA),
    );
    if (needResp.body.contains('::::')) {
      salt = needResp.body.split('::::')[1];
    }

    // ── 4. AES 加密密码 ──
    params['password'] = _encryptAES(password, salt);
    params.remove('rememberMe');

    // ── 5. 判断是否需要验证码并登录 ──
    // 参考 login-java CasLoginProcess: 需要验证码时最多重试 20 次
    final captchaService = CaptchaService(client);
    final needCaptcha = await captchaService.needsCaptcha(host, username);

    if (needCaptcha) {
      await _loginWithCaptcha(
        uri: uri,
        params: params,
        host: host,
        desktopUA: desktopUA,
        captchaService: captchaService,
      );
    } else {
      resp = await client.postForm(uri,
          body: params,
          headers: _htmlHeaders(host, desktopUA),
          noRedirect: true);
      _checkLoginResponse(resp);
    }

    // ── 6. 跟随重定向（CAS ticket 验证链） ──
    // 参考 Java CasLoginProcess.casSendLoginData():
    //   第一步：POST 跟随（携带 cookie + ticket）
    //   第二步及之后：GET 跟随
    var hops = 0;
    while ((resp.statusCode == 301 || resp.statusCode == 302 ||
            resp.statusCode == 303) &&
        hops < 10) {
      hops++;
      final loc = resp.header('location');
      if (loc == null || loc.isEmpty) break;

      final targetUri = Uri.parse(loc);
      if (hops == 1) {
        // 第一个重定向：使用 POST 跟随（CAS ticket 验证）
        resp = await client.postForm(targetUri,
            body: const {}, headers: _htmlHeaders(targetUri.host, desktopUA), noRedirect: true);
        // 如果 POST 失败（某些服务器不接受），回退到 GET
        if (resp.statusCode == 200 || resp.statusCode == 404 || resp.statusCode >= 500) {
          resp = await client.get(targetUri, headers: _htmlHeaders(targetUri.host, desktopUA), noRedirect: true);
        }
      } else {
        // 后续重定向：使用 GET 跟随
        resp = await client.get(targetUri,
            headers: _htmlHeaders(targetUri.host, desktopUA), noRedirect: true);
      }
    }

    // ── 7. 预热 ehall 各模块页面（收集模块级 cookie） ──
    // 参考 yibinu-score-crawler: 每个页面都会产生新 cookie
    // 注意：*default/index.do 及后续 API 调用均使用 HTTPS
    for (final url in [
      'https://ehall.yibinu.edu.cn',
      'https://ehall.yibinu.edu.cn/new/index.html',
      'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
    ]) {
      try {
        var r = await client.get(Uri.parse(url), noRedirect: true);
        var h = 0;
        while ((r.statusCode == 301 || r.statusCode == 302 ||
                r.statusCode == 303) &&
            h < 8) {
          h++;
          final l = r.header('location');
          if (l == null || l.isEmpty) break;
          final t = Uri.parse(l);
          r = await client.get(t, noRedirect: true);
        }
      } catch (_) {}
    }
    // 预热课表 API（POST + HTTPS）
    try {
      await client.postForm(
        Uri.parse(
            'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/modules/xskcb/xskcb.do'),
        body: {'XNXQDM': _calcXnxqdm()},
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Host': 'ehall.yibinu.edu.cn',
          'Origin': 'https://ehall.yibinu.edu.cn',
          'Referer':
              'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
    } catch (_) {}
    // ── 8. https 补登录：捕获 Secure 的 CASTGC（scjx2 / 学工 SSO 必需）──
    // http 登录时客户端（HttpClient/浏览器）会拒存 Secure cookie，
    // 故 authserver 下发的 CASTGC 永远拿不到 → scjx2/学工 无法 SSO 自动放行。
    // 这里在同一账号下用 https 再跑一次完整登录，把 302 响应里的
    // `Set-Cookie: CASTGC=...; Secure; HttpOnly` 写入 SharedHttpClient
    // （_send 自动解析并随 saved_cookies 持久化），并显式落到注入器读取的桶。
    // 失败不影响 ehall 主流程（仅 scjx2/学工 退化为手动登录）。
    try {
      await _captureCastgcOverHttps(username, password);
    } catch (e) {
      debugPrint('CAS https CASTGC capture failed (non-fatal): $e');
    }
  }

  /// 用 https 再跑一次 CAS 登录，专门捕获 Secure 的 CASTGC（TGC）。
  ///
  /// http 登录时客户端（HttpClient/浏览器）会拒存 Secure cookie，
  /// 故 authserver 下发的 CASTGC 永远到不了客户端；而 scjx2 / 学工 的
  /// CAS SSO 必须携带有效 CASTGC 才能自动放行。
  /// 本方法在同一账号密码下走一次完整 https 登录
  /// （GET 登录页取隐藏字段/盐 → AES 加密 → POST noRedirect），
  /// 302 响应里的 `Set-Cookie: CASTGC=...; Secure; HttpOnly` 会被
  /// [SharedHttpClient._send] 自动解析并持久化；最后显式落到
  /// `yibinu.edu.cn` / `authserver.yibinu.edu.cn` 桶，供注入器读取。
  ///
  /// 返回抓到的 CASTGC 值；未抓到返回 null。任何异常均向上抛出，
  /// 由调用方 [login] 包 try/catch 兜底（不影响 ehall 主流程）。
  Future<String?> _captureCastgcOverHttps(String username, String password) async {
    const desktopUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final uri = Uri.parse(yibinLoginUrl);
    final host = uri.host; // authserver.yibinu.edu.cn

    // 1. GET https 登录页（取隐藏字段 + 加密盐）
    final resp = await client.get(uri, headers: _htmlHeaders(host, desktopUA));
    final doc = html_parser.parse(resp.body);
    final form = doc.getElementById('casLoginForm');
    if (form == null) {
      debugPrint('CASTGC capture: no casLoginForm on https login page');
      return null;
    }

    // 2. 提取隐藏字段（lt / execution / _eventId 等）
    final params = <String, String>{};
    for (final input in form.getElementsByTagName('input')) {
      final name = input.attributes['name'] ?? '';
      if (name.isEmpty || name == 'rememberMe') continue;
      var val = input.attributes['value'] ?? '';
      if (name == 'username') val = username;
      params[name] = val;
    }

    // 3. 获取加密盐（https）
    String salt = 'E5b2IYX5TT1D79TA'; // 默认 fallback
    final saltMatch =
        RegExp(r'var pwdDefaultEncryptSalt = "(.+?)";').firstMatch(resp.body);
    if (saltMatch != null) salt = saltMatch.group(1)!;
    try {
      final needResp = await client.get(
        Uri.parse('https://$host/authserver/needCaptcha.html'
            '?username=$username&pwdEncrypt2=pwdEncryptSalt'),
        headers: _htmlHeaders(host, desktopUA),
      );
      if (needResp.body.contains('::::')) {
        salt = needResp.body.split('::::')[1];
      }
    } catch (_) {
      // 盐获取失败时沿用页面默认值
    }

    // 4. AES 加密密码
    params['password'] = _encryptAES(password, salt);
    params.remove('rememberMe');

    // 5. POST（noRedirect）拿 302 里的 CASTGC；非 302 则走验证码重试
    final captchaService = CaptchaService(client);
    var postResp = await client.postForm(
      uri,
      body: params,
      headers: _htmlHeaders(host, desktopUA),
      noRedirect: true,
    );

    if (postResp.statusCode != 302) {
      // 可能需要验证码：用 https 验证码地址走 OCR 重试
      final httpsCaptchaUrl = 'https://$host/authserver/captcha.html';
      for (int attempt = 0; attempt < 10; attempt++) {
        try {
          final code = await captchaService.recognize(captchaUrl: httpsCaptchaUrl);
          params['captchaResponse'] = code;
          final r = await client.postForm(
            uri,
            body: params,
            headers: _htmlHeaders(host, desktopUA),
            noRedirect: true,
          );
          if (r.statusCode == 302) {
            postResp = r;
            break;
          }
          if (r.body.contains('无效的验证码')) continue;
          postResp = r;
          break;
        } catch (_) {
          // OCR/网络异常则继续重试
        }
      }
    }

    // 6. 从 302 响应头的 Set-Cookie 解析**本次登录**产生的 CASTGC（权威值）。
    // 不能从客户端 cookie 罐里找：罐里可能残留 loadCookies 加载的旧 CASTGC
    // （服务端 TTL 已过期），若本次 https 补登录被验证码/风控拦截（非 302），
    // 会把"死 TGC"误判为登录成功并落盘 → WebView 注入后必然 CAS 回环
    // （"用久了只有手动重新登录才成功"的另一成因）。
    final castgcValues = <String>[];
    try {
      postResp.headers?.forEach((name, values) {
        if (name.toLowerCase() == 'set-cookie') {
          for (final v in values) {
            if (v.startsWith('CASTGC=')) {
              var end = v.indexOf(';');
              if (end < 0) end = v.length;
              final val = v.substring(7, end).trim();
              if (val.isNotEmpty) castgcValues.add(val);
            }
          }
        }
      });
    } catch (_) {}

    final castgc = castgcValues.isNotEmpty ? castgcValues.first : null;
    if (castgc != null) {
      // 显式落到注入器读取的桶（无前导点，匹配 scjx2 / 学工）
      client.setCookiesForDomain('yibinu.edu.cn', {'CASTGC': castgc});
      client.setCookiesForDomain('authserver.yibinu.edu.cn', {'CASTGC': castgc});
      debugPrint('CASTGC capture: found via https login Set-Cookie');
    } else {
      debugPrint('CASTGC capture: NOT found (status=${postResp.statusCode})');
    }
    return castgc;
  }

  /// 带验证码登录（最多重试 10 次）
  Future<void> _loginWithCaptcha({
    required Uri uri,
    required Map<String, String> params,
    required String host,
    required String desktopUA,
    required CaptchaService captchaService,
  }) async {
    const captchaUrl =
        'https://authserver.yibinu.edu.cn/authserver/captcha.html';

    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        final code = await captchaService.recognize(captchaUrl: captchaUrl);
        params['captchaResponse'] = code;

        final resp = await client.postForm(uri,
            body: params,
            headers: _htmlHeaders(host, desktopUA),
            noRedirect: true);

        // 302 → 登录成功
        if (resp.statusCode == 302) return;

        // 200 → 检查错误信息，验证码无效则继续重试
        if (resp.body.contains('无效的验证码')) continue;

        // 账号/密码等业务错误：提取友好提示并立即抛出，不再重试
        throw LoginRejectedException(_extractLoginError(resp.body));
      } catch (e) {
        if (e is LoginRejectedException) rethrow;
        // 其他异常（网络、OCR失败等）继续重试
      }
    }
    throw LoginRejectedException('验证码登录失败（已重试 10 次）');
  }

  /// 检查无验证码登录响应
  void _checkLoginResponse(HttpResponse resp) {
    if (resp.statusCode != 302) {
      // 账号/密码等业务错误：友好提示，不抛 HTML 片段
      throw LoginRejectedException(_extractLoginError(resp.body));
    }
  }

  /// 从 CAS 登录失败页 HTML 中提取友好错误提示（自定义文案，不弹 JS/HTML）
  String _extractLoginError(String html) {
    try {
      final doc = html_parser.parse(html);
      final el = doc.querySelector(
          '#tips, .login-error-tip, .error-tip, #msg, .auth_error, .error-tips');
      if (el != null) {
        final t = el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (t.isNotEmpty && t.length < 100) return t;
      }
    } catch (_) {}
    if (html.contains('账号或密码错误') || html.contains('用户名或密码错误')) {
      return '账号或密码错误';
    }
    if (html.contains('验证码')) return '验证码错误，请重试';
    if (html.contains('停用') || html.contains('不存在')) {
      return '账号已停用或不存在';
    }
    return '登录失败，请检查账号密码后重试';
  }

  /// 计算当前学期
  String _calcXnxqdm() {
    final now = DateTime.now();
    return now.month >= 2 && now.month <= 7
        ? '${now.year - 1}-${now.year}-2'
        : '${now.year}-${now.year + 1}-1';
  }

  Map<String, String> _htmlHeaders(String host, String ua) => {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'max-age=0',
        'Connection': 'keep-alive',
        'Host': host,
        'Upgrade-Insecure-Requests': '1',
        'User-Agent': ua,
      };

  String _encryptAES(String password, String key) {
    final prefix = List.generate(64, (_) => _chars[Random().nextInt(_chars.length)]).join();
    final iv = List.generate(16, (_) => _chars[Random().nextInt(_chars.length)]).join();
    final e = enc.Encrypter(
        enc.AES(enc.Key.fromUtf8(key), mode: enc.AESMode.cbc, padding: 'PKCS7'));
    return e.encrypt('$prefix$password', iv: enc.IV.fromUtf8(iv)).base64;
  }

  void dispose() {
    client.dispose();
  }
}
