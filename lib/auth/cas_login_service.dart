import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:html/parser.dart' as html_parser;

import '../core/http_client.dart';
import 'captcha_service.dart';

/// 金智教务系统 CAS 统一登录
/// 严格参考 yibinu-score-crawler + verify_yibinu_ehall + wisedu-unified-login-api 实现
///
/// 关键要点（参考 Java 参考实现）：
/// 1. 所有 ehall API 使用 http:// 而非 https://
/// 2. CAS ticket 验证重定向使用 POST 方法跟随
/// 3. 每个页面跳转都会产生新 cookie，必须持续合并
/// 4. 连续输错密码会触发验证码，使用 ML Kit OCR 自动识别
class CasLoginService {
  static const String _chars =
      'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  /// 宜宾学院统一认证登录 URL
  /// 注意：必须使用 http:// 而非 https://，与 Java 参考实现一致
  static const String yibinLoginUrl =
      'http://authserver.yibinu.edu.cn/authserver/login'
      '?service=http%3A%2F%2Fehall.yibinu.edu.cn%2Flogin'
      '%3Fservice%3Dhttp%3A%2F%2Fehall.yibinu.edu.cn%2Fnew%2Findex.html';

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

    // 从 needCaptcha 接口获取更新后的盐（注意：needCaptcha 也用 http）
    final needResp = await client.get(
      Uri.parse('http://$host/authserver/needCaptcha.html'
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
        'http://authserver.yibinu.edu.cn/authserver/captcha.html';

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

        // 200 → 检查错误信息，验证码无效则重试
        if (resp.body.contains('无效的验证码')) continue;

        // 其他错误
        final snippet =
            resp.body.length > 150 ? resp.body.substring(0, 150) : resp.body;
        throw Exception('登录失败（HTTP ${resp.statusCode}）：$snippet');
      } catch (e) {
        if (e is Exception && e.toString().contains('登录失败')) rethrow;
        // 其他异常（网络、OCR失败等）继续重试
      }
    }
    throw Exception('验证码登录失败（已重试 10 次）');
  }

  /// 检查无验证码登录响应
  void _checkLoginResponse(HttpResponse resp) {
    if (resp.statusCode != 302) {
      final snippet = resp.body.length > 150
          ? resp.body.substring(0, 150)
          : resp.body;
      throw Exception('登录失败（HTTP ${resp.statusCode}）：$snippet');
    }
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
