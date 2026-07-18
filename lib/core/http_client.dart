import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'local_storage.dart';

/// 基于 dart:io HttpClient 的共享 HTTP 客户端
/// Cookie 按域名存储，HTTP/HTTPS 共享同域 cookie（与浏览器行为一致）。
class SharedHttpClient {
  final HttpClient _client;

  /// { 'ehall.yibinu.edu.cn': { name: value } }
  final Map<String, Map<String, String>> _cookiesByDomain = {};

  static const String _cookieStorageKey = 'saved_cookies';
  Timer? _saveDebounceTimer;
  static const Duration _saveDelay = Duration(seconds: 3);

  SharedHttpClient()
      : _client = HttpClient()
          ..badCertificateCallback = ((_, _, _) => true)
          ..autoUncompress = false;

  // ==================== Cookie 持久化 ====================

  /// 保存所有 Cookie 到 LocalStorage（每域名存为一行 Cookie 字符串）
  Future<void> saveCookies() async {
    if (_cookiesByDomain.isEmpty) return;
    final flat = <String, String>{};
    for (final domain in _cookiesByDomain.entries) {
      final joined = domain.value.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      flat[domain.key] = joined;
    }
    await LocalStorage.setString(_cookieStorageKey, jsonEncode(flat));
    // 同时保存一份精简版：只保留 ehall 域的 Cookie
    final ehallCookies = _cookiesByDomain['ehall.yibinu.edu.cn'];
    if (ehallCookies != null && ehallCookies.isNotEmpty) {
      await LocalStorage.setString('cookie_ehall', jsonEncode(ehallCookies));
    }
  }

  /// 从 LocalStorage 加载 Cookie
  Future<void> loadCookies() async {
    _cookiesByDomain.clear();

    // 优先加载精简版 ehall Cookie
    final ehallRaw = await LocalStorage.getString('cookie_ehall');
    if (ehallRaw != null && ehallRaw.isNotEmpty) {
      try {
        final ehallMap = jsonDecode(ehallRaw) as Map<String, dynamic>;
        _cookiesByDomain['ehall.yibinu.edu.cn'] =
            ehallMap.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    // 再加载完整版（覆盖补充）
    final saved = await LocalStorage.getString(_cookieStorageKey);
    if (saved == null || saved.isEmpty) return;
    try {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (entry.key == 'ehall.yibinu.edu.cn' &&
            _cookiesByDomain.containsKey(entry.key)) {
          // 已有精简版数据，合并补充
          final existing = _cookiesByDomain[entry.key]!;
          for (final cookie in (entry.value as String).split('; ')) {
            final eqIdx = cookie.indexOf('=');
            if (eqIdx < 0) continue;
            final name = cookie.substring(0, eqIdx).trim();
            if (!existing.containsKey(name)) {
              existing[name] = cookie.substring(eqIdx + 1).trim();
            }
          }
        } else {
          final bucket = <String, String>{};
          for (final cookie in (entry.value as String).split('; ')) {
            final eqIdx = cookie.indexOf('=');
            if (eqIdx < 0) continue;
            bucket[cookie.substring(0, eqIdx).trim()] =
                cookie.substring(eqIdx + 1).trim();
          }
          if (bucket.isNotEmpty) {
            _cookiesByDomain[entry.key] = bucket;
          }
        }
      }
    } catch (_) {}

    // 兜底：如果 ehall 域有来自父域的 Cookie（如 yibinu.edu.cn），合并
    final yibinuCookies = _cookiesByDomain['yibinu.edu.cn'];
    if (yibinuCookies != null && yibinuCookies.isNotEmpty) {
      final ehall = _cookiesByDomain.putIfAbsent(
          'ehall.yibinu.edu.cn', () => {});
      ehall.addAll(yibinuCookies);
    }
  }

  /// 清除所有已保存的 Cookie
  Future<void> clearCookies() async {
    _cookiesByDomain.clear();
    _saveDebounceTimer?.cancel();
    await LocalStorage.remove(_cookieStorageKey);
  }

  /// 防抖自动保存 Cookie（不阻塞调用者）
  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDelay, () {
      saveCookies().catchError((_) {});
    });
  }

  /// 获取指定域名的 Cookie 字符串（供外部使用，如原始 Socket 请求）
  String getCookiesForDomain(String host) {
    final all = <String, String>{};
    // 逐级向上匹配父级域名
    final parts = host.split('.');
    for (int i = parts.length - 1; i >= 0; i--) {
      final domain = parts.skip(i).join('.');
      final bucket = _cookiesByDomain[domain];
      if (bucket != null) all.addAll(bucket);
    }
    return all.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 获取所有 cookies（按域名分组），供注入 WebView 等场景使用
  Map<String, Map<String, String>> getAllCookies() {
    final copy = <String, Map<String, String>>{};
    for (final entry in _cookiesByDomain.entries) {
      copy[entry.key] = Map.from(entry.value);
    }
    return copy;
  }

  /// 注入 cookie 到指定域名 bucket（用于 WebView 登录后同步）
  ///
  /// 会覆盖同名 cookie。多个域名都会注入（如同时给
  /// `scjx2.yibinu.edu.cn` 和 `.yibinu.edu.cn` 写入）
  void setCookiesForDomain(String domain, Map<String, String> cookies) {
    if (cookies.isEmpty) return;
    final bucket = _cookiesByDomain.putIfAbsent(domain, () => {});
    bucket.addAll(cookies);
    _scheduleSave();
  }

  // ==================== 会话验证 ====================

  /// 验证会话是否有效（调用学期 API 检查返回是否为有效 JSON）
  Future<bool> verifySession() async {
    try {
      final host = 'ehall.yibinu.edu.cn';
      final req = await _client.postUrl(
        Uri.parse('https://$host'
            '/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do'),
      );
      _setup(req, req.uri, {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Origin': 'https://$host',
        'Referer':
            'https://$host/jwapp/sys/wdkb/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      });
      req.followRedirects = false;
      final resp = await req.close().timeout(const Duration(seconds: 15));

      // 302 = 被重定向到 CAS 登录 → 会话已过期
      if (resp.statusCode == 302) return false;

      final body = await resp.transform(utf8.decoder).join();

      // 验证是否为有效 JSON
      final json = jsonDecode(body) as Map?;
      if (json == null) return false;
      if (json['code'] != '0') return false;

      // 检查是否有学期数据
      final datas = json['datas'] as Map?;
      if (datas == null) return false;
      final module = datas['dqxnxq'] as Map?;
      if (module == null) return false;
      final rows = module['rows'] as List?;
      return rows != null && rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ==================== HTTP 方法 ====================

  /// GET
  Future<HttpResponse> get(Uri uri,
      {Map<String, String>? headers, bool noRedirect = false}) async {
    final req = await _client.getUrl(uri);
    _setup(req, uri, headers);
    if (noRedirect) req.followRedirects = false;
    return _send(req);
  }

  /// GET 原始字节（含响应头）
Future<RawResponse> getRaw(Uri uri,
    {Map<String, String>? headers, bool noRedirect = false}) async {
  final req = await _client.getUrl(uri);
  _setup(req, uri, headers);
  if (noRedirect) req.followRedirects = false;
  return _sendRaw(req);
}
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
    String enc(String s) {
      return Uri.encodeQueryComponent(s)
          .replaceAll('+', '%2B')
          .replaceAll('%2A', '*')
          .replaceAll('%2D', '-')
          .replaceAll('%2E', '.');
    }
    final bodyStr =
        body.entries.map((e) => '${enc(e.key)}=${enc(e.value)}').join('&');
    debugPrint('postForm body=[$bodyStr] uri=[${req.uri}]');
    req.write(bodyStr);
    return _send(req);
  }

  /// POST JSON
  ///
  /// [body] 为 null 时发送空 body（content-length: 0），非 null 时发送 jsonEncode(body)
  Future<HttpResponse> postJson(Uri uri,
      {Map<String, String>? headers,
      Object? body,
      bool noRedirect = false}) async {
    final req = await _client.postUrl(uri);
    _setup(req, uri, headers);
    req.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    if (noRedirect) req.followRedirects = false;
    if (body != null) {
      req.write(jsonEncode(body));
    }
    // body 为 null：不写任何内容，自动得到 content-length: 0
    return _send(req);
  }

  // ==================== 内部方法 ====================

  void _setup(
      HttpClientRequest req, Uri uri, Map<String, String>? extraHeaders) {
    req.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    // 声明支持的压缩格式
    req.headers.set('Accept-Encoding', 'gzip, deflate');

    // 按域名发送 cookie，同时检查父级域名（如 yibinu.edu.cn 也匹配 ehall.yibinu.edu.cn）
    final allCookies = <String, String>{};
    final host = uri.host;
    // 从完整域名逐级向上检查
    final parts = host.split('.');
    for (int i = parts.length - 1; i >= 0; i--) {
      final domain = parts.skip(i).join('.');
      final bucket = _cookiesByDomain[domain];
      if (bucket != null) {
        allCookies.addAll(bucket);
      }
    }
    if (allCookies.isNotEmpty) {
      req.headers.set('Cookie',
          allCookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
    }

    if (extraHeaders != null) {
      extraHeaders.forEach((k, v) => req.headers.set(k, v));
    }
  }

  Future<HttpResponse> _send(HttpClientRequest req) async {
    late HttpResponse result;
    try {
      // 读取原始字节，手动解压
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
      _scheduleSave();

      // 读取原始字节，手动解压
      final bytes = await resp
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      final contentEncoding =
          resp.headers.value('content-encoding')?.toLowerCase() ?? '';

      List<int> decoded;
      if (contentEncoding.contains('gzip')) {
        decoded = gzip.decode(bytes);
      } else if (contentEncoding.contains('deflate')) {
        decoded = zlib.decode(bytes);
      } else {
        // 无编码: 直接用原始字节
        decoded = bytes;
      }

      final body = utf8.decode(decoded, allowMalformed: true);
      result = HttpResponse(body, resp.statusCode, resp.headers);
    } on Exception catch (e) {
      if (e is HttpException) {
        result = HttpResponse('', 1001, null);
      } else {
        result = HttpResponse('', 0, null);
      }
    }
    return result;
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
    _scheduleSave();
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
    _saveDebounceTimer?.cancel();
    saveCookies().catchError((_) {});
    _client.close(force: true);
  }

  /// 发送请求并返回原始字节（用于 charset 检测等场景）
  Future<RawResponse> _sendRaw(HttpClientRequest req) async {
    late final RawResponse result;
    try {
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
      _scheduleSave();

      final bytes = await resp
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      final contentEncoding =
          resp.headers.value('content-encoding')?.toLowerCase() ?? '';

      List<int> decoded;
      if (contentEncoding.contains('gzip')) {
        decoded = gzip.decode(bytes);
      } else if (contentEncoding.contains('deflate')) {
        decoded = zlib.decode(bytes);
      } else {
        decoded = bytes;
      }

      result = RawResponse(decoded, resp.statusCode, resp.headers);
    } on Exception catch (e) {
      if (e is HttpException) {
        result = RawResponse(<int>[], 1001, null);
      } else {
        result = RawResponse(<int>[], 0, null);
      }
    }
    return result;
  }
}

class RawResponse {
  final List<int> bodyBytes;
  final int statusCode;
  final HttpHeaders? headers;

  RawResponse(this.bodyBytes, this.statusCode, this.headers);

  String? header(String name) {
    if (headers == null) return null;
    try {
      return headers!.value(name);
    } catch (_) {
      return null;
    }
  }
}

class HttpResponse {
  final String body;
  final int statusCode;
  final HttpHeaders? headers;

  HttpResponse(this.body, this.statusCode, this.headers);

  String? header(String name) {
    if (headers == null) return null;
    try {
      return headers!.value(name);
    } catch (_) {
      return null;
    }
  }
}
