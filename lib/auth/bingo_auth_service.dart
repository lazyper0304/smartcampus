import 'package:flutter/foundation.dart';

import '../core/bingo/bingo_client.dart';
import '../core/local_storage.dart';

/// Bingo 后端认证服务（LDAP 同步登录 + Token 刷新）。
///
/// 三段式流程（与 `YibinApp/Flutter` 的 `AuthRepositoryImpl` 对齐）：
/// `GET /auth/login/captcha-status` →（需要时）`GET /auth/login/captcha`
/// → `POST /auth/login`。
///
/// 与 CAS 侧共同构成「双下放」：本服务只管 Bingo 代理接口
/// （课表/成绩/评教/通知/第二课堂）的凭证，CAS 凭证由 `AuthService` 负责。
class BingoAuthService {
  BingoAuthService._();

  static final BingoAuthService instance = BingoAuthService._();

  /// 查询当前 IP + 学号是否需要图形验证码（只读，不下发图片、不计入限流）
  Future<LoginCaptchaChallenge> fetchCaptchaStatus(String schoolId) async {
    final data = await BingoClient.authRequest(
      'GET',
      '/auth/login/captcha-status',
      query: schoolId.trim().isEmpty ? null : {'school_id': schoolId.trim()},
    );
    return LoginCaptchaChallenge.fromJson(data);
  }

  /// 取图形验证码。后端判定无需验证码时返回 `captcha_required=false` 且无图，
  /// 此处原样返回而不抛错——「当前无需验证码」不是用户错误。
  Future<LoginCaptchaChallenge> fetchCaptcha(String schoolId) async {
    final data = await BingoClient.authRequest(
      'GET',
      '/auth/login/captcha',
      query: schoolId.trim().isEmpty ? null : {'school_id': schoolId.trim()},
    );
    return LoginCaptchaChallenge.fromJson(data);
  }

  /// 登录并落地双 token。
  ///
  /// 失败时抛 [BingoException]；若服务端下发了验证码挑战，异常 message 之后
  /// 可通过 [takeLastChallenge] 取回用于重绘验证码。
  Future<Map<String, dynamic>> login({
    required String schoolId,
    required String password,
    String? captchaId,
    String? captchaCode,
  }) async {
    final data = await BingoClient.authRequest('POST', '/auth/login', body: {
      'school_id': schoolId.trim(),
      'password': password,
      if (captchaId != null && captchaId.isNotEmpty) 'captcha_id': captchaId,
      if (captchaCode != null && captchaCode.isNotEmpty) 'captcha_code': captchaCode,
    });

    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || access.isEmpty) {
      throw BingoException('登录成功但未返回访问凭证');
    }
    await BingoClient.saveTokens(access, refresh ?? '');
    final user = data['user'];
    await BingoClient.saveUserInfo(
      schoolId.trim(),
      user is Map<String, dynamic> ? user : null,
    );
    return data;
  }

  /// 登出（失败不阻塞本地清凭证）
  Future<void> logout() async {
    try {
      await BingoClient.instance.postMap('/auth/logout');
    } catch (_) {
      // 登出失败不阻塞
    } finally {
      await BingoClient.clearTokens();
    }
  }

  /// 拉取当前用户（用于校准缓存的 user 信息）
  Future<Map<String, dynamic>?> fetchMe() async {
    if (!BingoClient.isLoggedIn) return null;
    try {
      return await BingoClient.instance.getMap('/auth/me');
    } on BingoException catch (e) {
      debugPrint('[Bingo] /auth/me 失败: ${e.message}');
      return null;
    }
  }

  /// 当前登录学号
  Future<String> currentSchoolId() async =>
      await BingoClient.loadSchoolId() ??
      await LocalStorage.getString('username') ??
      '';

  /// 当前用户信息（本地缓存）
  Future<Map<String, dynamic>?> currentUser() => BingoClient.loadUserInfo();
}
