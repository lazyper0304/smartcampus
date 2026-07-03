import 'dart:convert';
import 'dart:io';

/// 基于 dart:io HttpClient 的共享 HTTP 客户端
/// Cookie 按域名存储，HTTP/HTTPS 共享同域 cookie（与浏览器行为一致）。
class SharedHttpClient {
  final HttpClient _client;

  /// { 'ehall.yibinu.edu.cn': { name: value } }
  final Map<String, Map<String, String>> _cookiesByDomain = {};

  SharedHttpClient()
      : _client = HttpClient()
          ..badCertificateCallback = ((_, _, _) => true);

  /// GET
  Future<HttpResponse> get(Uri uri,
      {Map<String, String>? headers, bool noRedirect = false}) async {
    final req = await _client.getUrl(uri);
    _setup(req, uri, headers);
    if (noRedirect) req.followRedirects = false;
    return _send(req);
  }

  /// GET 原始字节
  Future<List<int>> getBytes(Uri uri,
      {Map<String, String>? headers, bool noRedirect = false}) async {
    final req = await _client.getUrl(uri);
    _setup(req, uri, headers);
    if (noRedirect) req.followRedirects = false;
    return _sendBytes(req);
  }

  /// POST form-urlencoded
  Future<HttpResponse> postForm(Uri uri,
      {Map<String, String>? headers,
      required Map<String, String> body,
      bool noRedirect = false}) async {
    final req = await _client.postUrl(uri);
    _setup(req, uri, headers);
    req.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    if (noRedirect) req.followRedirects = false;
    // 使用自定义编码，保留 * - . 等字符（参考浏览器行为）
    String enc(String s) {
      return Uri.encodeQueryComponent(s).replaceAll('%2A', '*').replaceAll('%2D', '-').replaceAll('%2E', '.');
    }
    req.write(body.entries
        .map((e) => '${enc(e.key)}=${enc(e.value)}')
        .join('&'));
    return _send(req);
  }

  /// POST JSON
  Future<HttpResponse> postJson(Uri uri,
      {Map<String, String>? headers,
      required Object body,
      bool noRedirect = false}) async {
    final req = await _client.postUrl(uri);
    _setup(req, uri, headers);
    req.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    if (noRedirect) req.followRedirects = false;
    req.write(jsonEncode(body));
    return _send(req);
  }

  void _setup(
      HttpClientRequest req, Uri uri, Map<String, String>? extraHeaders) {
    req.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    // 按域名发送 cookie（HTTP/HTTPS 共享）
    final bucket = _cookiesByDomain[uri.host];
    if (bucket != null && bucket.isNotEmpty) {
      req.headers.set('Cookie',
          bucket.entries.map((e) => '${e.key}=${e.value}').join('; '));
    }

    if (extraHeaders != null) {
      extraHeaders.forEach((k, v) => req.headers.set(k, v));
    }
  }

  Future<HttpResponse> _send(HttpClientRequest req) async {
    final resp = await req.close().timeout(const Duration(seconds: 30));
    final requestUri = req.uri;

    for (final c in resp.cookies) {
      final domain = c.domain ?? requestUri.host;
      _cookiesByDomain.putIfAbsent(domain, () => {});
      _cookiesByDomain[domain]![c.name] = c.value;
    }

    // 手动解析 Set-Cookie 头（兜底）
    try {
      resp.headers.forEach((name, values) {
        if (name.toLowerCase() == 'set-cookie') {
          for (final val in values) {
            _parseSetCookieManual(val, requestUri.host);
          }
        }
      });
    } catch (_) {}

    final body = await resp.transform(utf8.decoder).join();
    return HttpResponse(body, resp.statusCode, resp.headers);
  }

  Future<List<int>> _sendBytes(HttpClientRequest req) async {
    final resp = await req.close().timeout(const Duration(seconds: 30));
    final requestUri = req.uri;
    for (final c in resp.cookies) {
      final domain = c.domain ?? requestUri.host;
      _cookiesByDomain.putIfAbsent(domain, () => {});
      _cookiesByDomain[domain]![c.name] = c.value;
    }
    try {
      resp.headers.forEach((name, values) {
        if (name.toLowerCase() == 'set-cookie') {
          for (final val in values) {
            _parseSetCookieManual(val, requestUri.host);
          }
        }
      });
    } catch (_) {}
    final chunks = <int>[];
    await for (final chunk in resp) {
      chunks.addAll(chunk);
    }
    return chunks;
  }

  void _parseSetCookieManual(String header, String defaultDomain) {
    final eqIdx = header.indexOf('=');
    if (eqIdx < 0) return;
    final semiIdx = header.indexOf(';');
    final name = header.substring(0, eqIdx).trim();
    final value = (semiIdx < 0
            ? header.substring(eqIdx + 1)
            : header.substring(eqIdx + 1, semiIdx))
        .trim();
    if (name.isEmpty) return;

    final domainMatch = RegExp(r'domain=\s*\.?([^;\s]+)', caseSensitive: false)
        .firstMatch(header);
    final domain = domainMatch?.group(1) ?? defaultDomain;
    _cookiesByDomain.putIfAbsent(domain, () => {});
    _cookiesByDomain[domain]![name] = value;
  }

  void dispose() {
    _client.close(force: true);
  }
}

class HttpResponse {
  final String body;
  final int statusCode;
  final HttpHeaders headers;

  HttpResponse(this.body, this.statusCode, this.headers);

  String? header(String name) {
    try {
      return headers.value(name);
    } catch (_) {
      return null;
    }
  }
}
