import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'cas_login_service.dart';

class LoginResult {
  final bool success;
  final String message;

  const LoginResult({
    required this.success,
    required this.message,
  });
}

class AuthService {
  final SharedHttpClient client;
  late final CasLoginService _casLoginService;

  AuthService({SharedHttpClient? sharedClient})
      : client = sharedClient ?? SharedHttpClient() {
    _casLoginService = CasLoginService(sharedClient: client);
  }

  /// 登录
  Future<LoginResult> login({
    String? loginUrl,
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      return const LoginResult(success: false, message: '用户名或密码不能为空');
    }

    try {
      await _casLoginService
          .login(
            loginUrl: loginUrl ?? CasLoginService.yibinLoginUrl,
            username: username.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 60));

      return const LoginResult(success: true, message: '登录成功');
    } on TimeoutException {
      return const LoginResult(
          success: false, message: '网络请求超时，请检查网络连接');
    } on Exception catch (e) {
      return LoginResult(
          success: false,
          message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void dispose() {
    _casLoginService.dispose();
  }

  /// 使用已保存的账号密码自动重登（静默续期）
  ///
  /// 适用场景：启动期 [SharedHttpClient.verifySession] 失败、或运行时请求返回
  /// 401/404 会话过期。仅当用户勾选过"记住密码"（`remember_password=true`）
  /// 且本地存有账号密码时才尝试；否则直接返回 false，由调用方降级为手动登录页。
  ///
  /// 走 [CasLoginService] 完整真实登录链路（刷新 ehall 会话 + https 补 CASTGC），
  /// 比注入 cookie 可靠（Chromium 常忽略注入的 Secure/HttpOnly cookie）。
  /// 成功后落盘 Cookie，返回 true；任何失败（无凭据 / 超时 / 账号错误）均返回 false。
  Future<bool> autoRelogin() async {
    final remember = await LocalStorage.getBool('remember_password');
    if (!remember) return false;
    final username = await LocalStorage.getString('username') ?? '';
    final password = await LocalStorage.getString('password') ?? '';
    if (username.trim().isEmpty || password.isEmpty) return false;

    try {
      await _casLoginService
          .login(
            loginUrl: CasLoginService.yibinLoginUrl,
            username: username.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 60));
      await client.saveCookies();
      return true;
    } on TimeoutException {
      debugPrint('autoRelogin: 超时');
      return false;
    } on Exception catch (e) {
      debugPrint('autoRelogin: 失败 - $e');
      return false;
    }
  }
}
