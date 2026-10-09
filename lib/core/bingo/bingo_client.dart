import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../local_storage.dart';
import 'bingo_config.dart';

/// Bingo 接口异常。[code] 为业务码，HTTP 状态码见 [statusCode]。
class BingoException implements Exception {
  BingoException(
    this.message, {
    this.code = 0,
    this.statusCode = 0,
    this.captcha,
  });

  final String message;
  final int code;
  final int statusCode;

  /// 登录失败时后端内嵌下发的验证码挑战（仅 `/auth/login` 会带）
  final LoginCaptchaChallenge? captcha;

  /// 会话失效（需重新登录 / 刷新）
  bool get isAuthError => statusCode == 401 || code == BingoConfig.codeUnauthorized;

  /// 需要图形验证码：显式业务码，或文案里出现「验证码」
  bool get needCaptcha =>
      code == BingoConfig.codeCaptchaRequired ||
      (captcha?.hasImage ?? false) ||
      message.contains('验证码');

  @override
  String toString() => message;
}

/// 登录失败时后端下发的验证码挑战载荷
class LoginCaptchaChallenge {
  const LoginCaptchaChallenge({
    this.captchaId,
    this.captchaImage,
    this.captchaRequired = false,
  });

  final String? captchaId;
  final String? captchaImage;
  final bool captchaRequired;

  bool get hasImage =>
      (captchaId?.isNotEmpty ?? false) && (captchaImage?.isNotEmpty ?? false);

  factory LoginCaptchaChallenge.fromJson(Map<String, dynamic>? data) {
    if (data == null) return const LoginCaptchaChallenge();
    final id = data['captcha_id'] as String?;
    final img = data['captcha_image'] as String?;
    final required = data['captcha_required'] as bool? ?? false;
    return LoginCaptchaChallenge(
      captchaId: id,
      captchaImage: img,
      // 后端内嵌 data 可能只给图不给标志位，有图即视为需要
      captchaRequired: required || ((id?.isNotEmpty ?? false)),
    );
  }
}

/// Bingo 客户端：注入 Bearer token、401 单飞刷新、统一解包 `{code,message,data}`。
///
/// 语义对齐 `YibinApp/Flutter/lib/core/network/dio_client.dart` 的
/// `AuthInterceptor`：401 时单飞调用 `/auth/refresh`（并发请求共享同一次刷新），
/// 成功后重放原请求；刷新失败则抛出认证错误由上层清会话。
class BingoClient {
  BingoClient._();

  static final BingoClient instance = BingoClient._();

  /// 需要登录态的端点（这些路径不注入 Bearer）
  static const Set<String> _noAuthPaths = {
    '/auth/login',
    '/auth/refresh',
    '/auth/logout',
    '/auth/me',
    '/auth/login/captcha',
    '/auth/login/captcha-status',
  };

  /// 单飞刷新中的 Future
  static Future<bool>? _refreshInFlight;

  /// 已确认会话失效的回调（由 auth 层注册，用于清空登录态）
  static void Function()? onSessionExpired;

  static String? _accessTokenCache;
  static bool _tokenCacheLoaded = false;

  static String? get accessToken {
    if (!_tokenCacheLoaded) {
      _tokenCacheLoaded = true;
      // 同步初值，异步补齐（首次通常为 null）
      LocalStorage.getString(BingoConfig.keyAccessToken).then((v) {
        if (v != null && v.isNotEmpty) _accessTokenCache = v;
      });
    }
    return _accessTokenCache;
  }

  static void _setAccessToken(String? token) {
    _accessTokenCache = token;
    _tokenCacheLoaded = true;
  }

  /// 是否已登录
  static bool get isLoggedIn => (accessToken?.isNotEmpty ?? false);

  static Future<void> saveTokens(String access, String refresh) async {
    _setAccessToken(access);
    await LocalStorage.setString(BingoConfig.keyAccessToken, access);
    await LocalStorage.setString(BingoConfig.keyRefreshToken, refresh);
    await LocalStorage.setString(BingoConfig.keySessionApiBase, BingoConfig.baseUrl);
  }

  static Future<void> saveUserInfo(String schoolId, Map<String, dynamic>? user) async {
    await LocalStorage.setString(BingoConfig.keySchoolId, schoolId);
    if (user != null) {
      await LocalStorage.setString(BingoConfig.keyUserInfo, jsonEncode(user));
    }
  }

  static Future<Map<String, dynamic>?> loadUserInfo() async {
    final raw = await LocalStorage.getString(BingoConfig.keyUserInfo);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> loadSchoolId() =>
      LocalStorage.getString(BingoConfig.keySchoolId);

  /// 清空 Bingo 侧凭证（不动 CAS 侧 cookie）
  static Future<void> clearTokens() async {
    _setAccessToken(null);
    _refreshInFlight = null;
    await LocalStorage.remove(BingoConfig.keyAccessToken);
    await LocalStorage.remove(BingoConfig.keyRefreshToken);
    await LocalStorage.remove(BingoConfig.keySchoolId);
    await LocalStorage.remove(BingoConfig.keyUserInfo);
  }

  /// 刷新 access_token（单飞：并发调用共享同一次网络请求）
  static Future<bool> _coordinatedRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<bool> _doRefresh() async {
    final rt = await LocalStorage.getString(BingoConfig.keyRefreshToken);
    if (rt == null || rt.isEmpty) return false;
    try {
      final res = await instance._requestRaw(
        'POST',
        BingoConfig.uri('/auth/refresh'),
        body: {'refresh_token': rt},
        withAuth: false,
      );
      if (res.statusCode != 200) return false;
      final shell = jsonDecode(res.body);
      if (shell is! Map || shell['code'] != BingoConfig.codeOk) return false;
      final data = shell['data'];
      if (data is! Map) return false;
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access == null || access.isEmpty) return false;
      await saveTokens(access, refresh ?? rt);
      return true;
    } catch (e) {
      debugPrint('[Bingo] refresh token 失败: $e');
      return false;
    }
  }

  /// 应用启动时预热 token 缓存
  static Future<void> warmUp() async {
    final v = await LocalStorage.getString(BingoConfig.keyAccessToken);
    _tokenCacheLoaded = true;
    _accessTokenCache = (v != null && v.isNotEmpty) ? v : null;
  }

  // ==================== 对外请求方法 ====================

  /// GET，返回 `data`（Map）
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
    bool retry = true,
  }) async {
    final data = await _requestData('GET', BingoConfig.uri(path, query),
        retry: retry);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// GET，返回 `data`（List）
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    bool retry = true,
  }) async {
    final data = await _requestData('GET', BingoConfig.uri(path, query),
        retry: retry);
    return data is List ? data : <dynamic>[];
  }

  /// POST，返回 `data`（Map）
  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
    bool retry = true,
  }) async {
    final data = await _requestData(
        'POST', BingoConfig.uri(path), body: body, retry: retry);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST，返回 `data`（List）
  Future<List<dynamic>> postList(
    String path, {
    Object? body,
    bool retry = true,
  }) async {
    final data = await _requestData(
        'POST', BingoConfig.uri(path), body: body, retry: retry);
    return data is List ? data : <dynamic>[];
  }

  /// PUT，返回 `data`（Map）
  Future<Map<String, dynamic>> putMap(
    String path, {
    Object? body,
    bool retry = true,
  }) async {
    final data = await _requestData(
        'PUT', BingoConfig.uri(path), body: body, retry: retry);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// DELETE，无返回值
  Future<void> delete(String path, {bool retry = true}) async {
    await _requestData('DELETE', BingoConfig.uri(path), retry: retry);
  }

  /// 通用请求，解包统一响应壳并返回 `data`
  Future<dynamic> _requestData(
    String method,
    Uri uri, {
    Object? body,
    bool retry = true,
  }) async {
    var res = await _requestRaw(method, uri, body: body);

    // 401 → 单飞刷新 → 重放一次
    if (res.statusCode == 401 && retry && !_noAuthPaths.any(uri.path.endsWith)) {
      final ok = await _coordinatedRefresh();
      if (ok) {
        res = await _requestRaw(method, uri, body: body);
      } else {
        _setAccessToken(null);
        onSessionExpired?.call();
        throw BingoException('登录已过期，请重新登录',
            code: BingoConfig.codeUnauthorized, statusCode: 401);
      }
    }

    final shell = _decodeShell(res);
    // 登录失败时后端可能内嵌验证码挑战，一并带出供登录页渲染
    final captcha = _pickCaptcha(shell.data);
    if (res.statusCode >= 400) {
      throw BingoException(
        shell.message.isEmpty ? '请求失败（HTTP ${res.statusCode}）' : shell.message,
        code: shell.code,
        statusCode: res.statusCode,
        captcha: captcha,
      );
    }
    if (shell.code != BingoConfig.codeOk) {
      throw BingoException(
        shell.message.isEmpty ? '请求失败' : shell.message,
        code: shell.code,
        statusCode: res.statusCode,
        captcha: captcha,
      );
    }
    return shell.data;
  }

  /// 从响应 `data` 中提取验证码挑战载荷
  ///
  /// 后端有两种下发形态，都兼容：
  /// - 顶层即验证码对象：`{captcha_id, captcha_image, captcha_required}`
  /// - 包一层 `captcha`：`{captcha: {...}}`
  static LoginCaptchaChallenge? _pickCaptcha(dynamic data) {
    if (data is! Map) return null;
    final raw = data['captcha'] is Map ? data['captcha'] : data;
    if (raw is! Map) return null;
    final hasId = raw['captcha_id']?.toString().isNotEmpty ?? false;
    final hasImg = raw['captcha_image']?.toString().isNotEmpty ?? false;
    if (!hasId && !hasImg) return null;
    return LoginCaptchaChallenge.fromJson(Map<String, dynamic>.from(raw));
  }

  /// 底层请求：注入 Bearer、设超时、返回原始字符串
  Future<_RawRes> _requestRaw(
    String method,
    Uri uri, {
    Object? body,
    bool withAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Platform': _platformHeader(),
    };
    final isAuthFree = !withAuth || _noAuthPaths.any(uri.path.endsWith);
    if (!isAuthFree) {
      final token = accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final timeout = method == 'GET'
          ? BingoConfig.receiveTimeout
          : BingoConfig.connectTimeout;
      final req = await client.openUrl(method, uri)
          .timeout(BingoConfig.connectTimeout);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Accept-Encoding', 'gzip, deflate');
      headers.forEach(req.headers.set);
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        req.headers.set('Content-Length', bytes.length);
        req.add(bytes);
      }
      final resp = await req.close().timeout(timeout);
      final text = await resp.transform(utf8.decoder).join();
      return _RawRes(resp.statusCode, text);
    } on TimeoutException {
      throw BingoException('网络超时，请稍后重试', statusCode: 0);
    } on BingoException {
      rethrow;
    } catch (e) {
      throw BingoException('网络请求失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  /// 二进制下载（附件 / 课表导出）。[noRedirect] 时不跟随 302，用于取预签名地址。
  Future<BingoBinaryResponse> download(
    String path, {
    Map<String, dynamic>? query,
    bool noRedirect = false,
    Duration? timeout,
  }) async {
    final uri = BingoConfig.uri(path, query);
    final headers = <String, String>{
      'Accept': '*/*',
      'X-Platform': _platformHeader(),
    };
    final token = accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(uri).timeout(BingoConfig.connectTimeout);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Accept-Encoding', 'identity');
      headers.forEach(req.headers.set);
      if (noRedirect) req.followRedirects = false;
      final resp = await req.close().timeout(timeout ?? BingoConfig.downloadTimeout);
      final bytes = await _readAllBytes(resp);
      return BingoBinaryResponse(
        statusCode: resp.statusCode,
        bytes: bytes,
        headers: resp.headers,
        location: resp.headers.value('location'),
        contentType: resp.headers.contentType?.mimeType,
        contentDisposition: resp.headers.value('content-disposition'),
      );
    } on TimeoutException {
      throw BingoException('下载超时，请稍后重试');
    } catch (e) {
      throw BingoException('下载失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  /// 下载预签名 URL（第二跳）：不带 Authorization、不带 Content-Type。
  Future<BingoBinaryResponse> downloadDirect(String absoluteUrl) async {
    final uri = Uri.parse(absoluteUrl);
    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(uri).timeout(BingoConfig.connectTimeout);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Accept', '*/*');
      req.headers.set('Accept-Encoding', 'identity');
      final resp = await req.close().timeout(BingoConfig.downloadTimeout);
      final bytes = await _readAllBytes(resp);
      return BingoBinaryResponse(
        statusCode: resp.statusCode,
        bytes: bytes,
        headers: resp.headers,
        contentType: resp.headers.contentType?.mimeType,
        contentDisposition: resp.headers.value('content-disposition'),
      );
    } catch (e) {
      throw BingoException('附件下载失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  /// 不带 Bearer 的裸请求（登录 / 验证码 / 刷新专用）
  static Future<Map<String, dynamic>> authRequest(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await BingoClient.instance._requestRaw(
      method,
      BingoConfig.uri(path, query),
      body: body,
      withAuth: false,
    );
    final shell = _decodeShell(res);
    if (res.statusCode >= 400 || shell.code != BingoConfig.codeOk) {
      throw BingoException(
        shell.message.isEmpty ? '请求失败（HTTP ${res.statusCode}）' : shell.message,
        code: shell.code,
        statusCode: res.statusCode,
      );
    }
    return shell.data is Map<String, dynamic>
        ? shell.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  // ==================== 内部工具 ====================

  static _Shell _decodeShell(_RawRes res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        return _Shell(
          code: (decoded['code'] as num?)?.toInt() ?? -1,
          message: decoded['message']?.toString() ?? '',
          data: decoded['data'],
        );
      }
    } catch (_) {
      // 非 JSON（如 502 HTML 错误页）
    }
    return _Shell(code: -1, message: '', data: null);
  }

  static Future<List<int>> _readAllBytes(HttpClientResponse resp) async {
    final out = <int>[];
    await for (final chunk in resp) {
      out.addAll(chunk);
    }
    return out;
  }

  static String _platformHeader() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}

class _Shell {
  const _Shell({required this.code, required this.message, this.data});
  final int code;
  final String message;
  final dynamic data;
}

class _RawRes {
  const _RawRes(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// 二进制下载结果（附件 / 课表导出）
class BingoBinaryResponse {
  const BingoBinaryResponse({
    required this.statusCode,
    required this.bytes,
    this.headers,
    this.location,
    this.contentType,
    this.contentDisposition,
  });

  final int statusCode;
  final List<int> bytes;
  final HttpHeaders? headers;
  final String? location;
  final String? contentType;
  final String? contentDisposition;

  bool get isRedirect =>
      statusCode == 301 || statusCode == 302 || statusCode == 303 ||
      statusCode == 307 || statusCode == 308;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}