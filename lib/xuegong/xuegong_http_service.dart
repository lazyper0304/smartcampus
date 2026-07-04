import 'dart:convert';
import 'dart:math' as dart_math;

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'raw_http_client.dart';

/// 学工系统 HTTP 服务
///
/// 通过 CAS SSO + 原始 Socket HTTP 客户端绕过 1001 状态码限制，
/// 实现对学工系统的 HTTP 级数据获取，无需 WebView 或外部浏览器。
class XuegongHttpService {
  final SharedHttpClient _sharedClient;
  final RawHttpClient _rawClient = RawHttpClient();
  Map<String, String>? _cachedCookies;

  /// 学工系统 CAS service URL（登录成功后的回调地址）
  static const String _xuegongServiceUrl =
      'https://ybxyxsglxt.yibinu.edu.cn/toIndex.htm?newTab=&tabName=';

  /// CAS 登录 URL
  static String get _casLoginUrl =>
      'http://authserver.yibinu.edu.cn/authserver/login'
      '?service=${Uri.encodeComponent(_xuegongServiceUrl)}';

  XuegongHttpService(this._sharedClient);

  // ── 公开方法 ──

  /// 使用指定凭据的 fetchPage（覆盖自动读取 localStorage）
  Future<String> fetchPageWithCreds(
      String url, String username, String password) async {
    final cookies = await _ensureAuthWithCreds(username, password);
    final resp = await _rawClient.get(url, cookies: cookies);
    if (resp.statusCode == 200 || resp.statusCode == 1001) return resp.body;
    throw Exception('获取页面失败（HTTP ${resp.statusCode}）');
  }

  /// 获取学工系统页面内容（自动处理认证）
  Future<String> fetchPage(String url) async {
    // 1. 获取用于学工系统的 cookies
    final cookies = await _ensureAuth();

    // 2. 通过 RawHttpClient 获取页面（可处理 1001）
    final resp = await _rawClient.get(url, cookies: cookies);

    if (resp.statusCode == 200 || resp.statusCode == 1001) {
      return resp.body;
    }

    // 如果是 302 重定向到登录页，说明 session 过期
    if (resp.statusCode == 302 || resp.statusCode == 301) {
      final location = resp.header('location');
      if (location != null && location.contains('authserver')) {
        // 重新认证
        _cachedCookies = null;
        final newCookies = await _ensureAuth();
        final retry = await _rawClient.get(url, cookies: newCookies);
        return retry.body;
      }
    }

    throw Exception('获取页面失败（HTTP ${resp.statusCode}）');
  }

  // ── 认证流程 ──

  /// 确保有学工系统的有效 cookie，返回 cookie map
  Future<Map<String, String>> _ensureAuth() async {
    // 优先使用缓存的 cookie
    if (_cachedCookies != null && _cachedCookies!.isNotEmpty) {
      return _cachedCookies!;
    }

    // 从 SharedHttpClient 获取学工系统 cookie
    final existing = _sharedClient.getCookiesForDomain(
        'ybxyxsglxt.yibinu.edu.cn');
    if (existing.isNotEmpty) {
      _cachedCookies = _parseCookieString(existing);
      return _cachedCookies!;
    }

    // 尝试 SSO：利用已有 eHall 的 CAS session
    final ssoCookies = await _trySso();
    if (ssoCookies != null) {
      _cachedCookies = ssoCookies;
      return ssoCookies;
    }

    // SSO 失败，执行完整 CAS 登录
    final loginCookies = await _fullLogin();
    _cachedCookies = loginCookies;
    return loginCookies;
  }

  /// 尝试 SSO（单点登录）
  Future<Map<String, String>?> _trySso() async {
    try {
      final resp = await _sharedClient.get(
        Uri.parse(_casLoginUrl),
        noRedirect: true,
      );

      if (resp.statusCode == 302) {
        // CAS 已自动下发 ticket → 跟随重定向
        return _followRedirectChain(resp);
      }

      // 200 = 登录页，CASTGC 已过期
      return null;
    } catch (e) {
      debugPrint('SSO failed: $e');
      return null;
    }
  }

  /// 跟随 CAS ticket 重定向链，返回最终域名的 cookie
  Future<Map<String, String>> _followRedirectChain(
      HttpResponse firstResp) async {
    var resp = firstResp;
    var hops = 0;

    while ((resp.statusCode == 301 || resp.statusCode == 302 ||
            resp.statusCode == 303) &&
        hops < 10) {
      hops++;
      final loc = resp.header('location');
      if (loc == null || loc.isEmpty) break;

      final targetUri = Uri.parse(loc);

      // 第一跳用 POST 跟随（CAS ticket 验证需要）
      if (hops == 1) {
        resp = await _sharedClient.postForm(targetUri,
            body: {}, noRedirect: true);
        if (resp.statusCode == 200 ||
            resp.statusCode == 404 ||
            resp.statusCode >= 500) {
          resp = await _sharedClient.get(targetUri, noRedirect: true);
        }
      } else {
        resp = await _sharedClient.get(targetUri, noRedirect: true);
      }
    }

    // 提取学工系统域的 cookie
    final cookies =
        _sharedClient.getCookiesForDomain('ybxyxsglxt.yibinu.edu.cn');
    if (cookies.isEmpty) {
      throw Exception('CAS SSO 认证后未获取到学工系统 cookie');
    }
    return _parseCookieString(cookies);
  }

  /// 完整 CAS 登录（使用已保存的凭据）
  Future<Map<String, String>> _fullLogin() async {
    final username =
        await LocalStorage.getString('saved_username') ?? '';
    final password =
        await LocalStorage.getString('password') ?? '';
    if (username.isEmpty || password.isEmpty) {
      throw Exception('未找到已保存的登录凭据，请先在智慧校园登录');
    }

    return _casLogin(username, password);
  }

  /// 使用指定凭据进行认证
  Future<Map<String, String>> _ensureAuthWithCreds(
      String username, String password) async {
    // 先尝试 SSO
    final ssoCookies = await _trySso();
    if (ssoCookies != null) {
      _cachedCookies = ssoCookies;
      return ssoCookies;
    }

    // SSO 失败，使用指定凭据直接登录
    final cookies = await _casLogin(username, password);
    _cachedCookies = cookies;
    return cookies;
  }

  /// CAS 登录核心（参考 CasLoginService）
  Future<Map<String, String>> _casLogin(
      String username, String password) async {
    const desktopUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    final uri = Uri.parse(_casLoginUrl);
    final host = uri.host;

    // 1. GET 登录页
    var resp = await _sharedClient.get(uri,
        headers: _htmlHeaders(host, desktopUA));
    final doc = html_parser.parse(resp.body);
    final form = doc.getElementById('casLoginForm');
    if (form == null) throw Exception('未找到 casLoginForm');

    // 2. 提取表单字段
    final params = <String, String>{};
    for (final input in form.getElementsByTagName('input')) {
      final name = input.attributes['name'] ?? '';
      if (name.isEmpty || name == 'rememberMe') continue;
      String val = input.attributes['value'] ?? '';
      if (name == 'username') val = username;
      params[name] = val;
    }

    // 3. 加密密码
    String salt = 'E5b2IYX5TT1D79TA';
    final saltMatch =
        RegExp(r'var pwdDefaultEncryptSalt = "(.+?)";').firstMatch(resp.body);
    if (saltMatch != null) salt = saltMatch.group(1)!;

    try {
      // needCaptcha 获取更新盐
      final needResp = await _sharedClient.get(
        Uri.parse('http://$host/authserver/needCaptcha.html'
            '?username=$username&pwdEncrypt2=pwdEncryptSalt'),
        headers: _htmlHeaders(host, desktopUA),
      );
      if (needResp.body.contains('::::')) {
        salt = needResp.body.split('::::')[1];
      }
    } catch (_) {}

    params['password'] = _encryptAES(password, salt);
    params.remove('rememberMe');

    // 4. POST 登录
    resp = await _sharedClient.postForm(uri,
        body: params,
        headers: _htmlHeaders(host, desktopUA),
        noRedirect: true);

    if (resp.statusCode != 302) {
      if (resp.body.contains('验证码') || resp.body.contains('captcha')) {
        throw Exception('需要验证码，请在 WebView 中手动登录');
      }
      final snippet = resp.body.length > 150
          ? resp.body.substring(0, 150)
          : resp.body;
      throw Exception('登录失败（HTTP ${resp.statusCode}）：$snippet');
    }

    // 5. 跟随重定向链
    var hops = 0;
    while ((resp.statusCode == 301 || resp.statusCode == 302 ||
            resp.statusCode == 303) &&
        hops < 10) {
      hops++;
      final loc = resp.header('location');
      if (loc == null || loc.isEmpty) break;
      final targetUri = Uri.parse(loc);

      if (hops == 1) {
        resp = await _sharedClient.postForm(targetUri,
            body: {},
            headers: _htmlHeaders(targetUri.host, desktopUA),
            noRedirect: true);
        if (resp.statusCode == 200 ||
            resp.statusCode == 404 ||
            resp.statusCode >= 500) {
          resp = await _sharedClient.get(targetUri,
              headers: _htmlHeaders(targetUri.host, desktopUA),
              noRedirect: true);
        }
      } else {
        resp = await _sharedClient.get(targetUri,
            headers: _htmlHeaders(targetUri.host, desktopUA),
            noRedirect: true);
      }
    }

    // 6. 验证获取到 cookie
    final cookieStr =
        _sharedClient.getCookiesForDomain('ybxyxsglxt.yibinu.edu.cn');
    if (cookieStr.isNotEmpty) {
      return _parseCookieString(cookieStr);
    }

    // 最后尝试直接访问学工系统首页
    try {
      await _sharedClient.get(Uri.parse(_xuegongServiceUrl), noRedirect: true);
    } catch (_) {}
    final retry =
        _sharedClient.getCookiesForDomain('ybxyxsglxt.yibinu.edu.cn');
    if (retry.isNotEmpty) return _parseCookieString(retry);

    throw Exception('CAS 登录后未获取到学工系统 cookie');
  }

  // ── 辅助方法 ──

  Map<String, String> _parseCookieString(String cookieStr) {
    if (cookieStr.isEmpty) return {};
    final result = <String, String>{};
    for (final part in cookieStr.split('; ')) {
      final eqIdx = part.indexOf('=');
      if (eqIdx > 0) {
        result[part.substring(0, eqIdx)] = part.substring(eqIdx + 1);
      }
    }
    return result;
  }

  Map<String, String> _htmlHeaders(String host, String ua) => {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        'Host': host,
        'Upgrade-Insecure-Requests': '1',
        'User-Agent': ua,
      };

  String _encryptAES(String password, String key) {
    final random = dart_math.Random();
    const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
    final prefix =
        List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
    final iv =
        List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
    final e = enc.Encrypter(enc.AES(enc.Key.fromUtf8(key),
        mode: enc.AESMode.cbc, padding: 'PKCS7'));
    return e
        .encrypt('$prefix$password', iv: enc.IV.fromUtf8(iv))
        .base64;
  }
}
