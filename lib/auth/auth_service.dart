import 'dart:async';

import '../core/http_client.dart';
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
}
