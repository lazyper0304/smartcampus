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

  /// autoRelogin 互斥锁链：多个调用方（SplashPage 启动重登 / scjx2 401 自愈 /
  /// kccx 403 重试 / qxfacx）可能并发触发"清 cookie + 完整重登"，
  /// 必须串行执行，避免互相清空对方刚登录的会话。
  static Future<void>? _autoReloginLock;

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
  /// 401/404 会话过期。登录成功后凭据总是会保存（见 login_page._saveCredentials），
  /// 因此只要有账号密码即尝试；无凭据（首次未登录/已退出登录）返回 false，
  /// 由调用方降级为手动登录页。
  ///
  /// ⚠️ 登录前先 [SharedHttpClient.clearCookies]（清内存 + 磁盘）：
  /// 复用旧 client 时，内存罐里是"多代 cookie 混合"——loadCookies 加载的
  /// 旧 CASTGC/JSESSIONID/route 残留（服务端 TTL 已过期）与本次新 cookie 并存。
  /// 把这种脏罐子注入 WebView 会干扰 authserver 的 CAS 会话判定 → SSO 刷新
  /// 回环 → 学科竞赛等模块表现为"只有手动重新登录才能成功"（手动登录页用
  /// 全新 client、无旧 cookie，天然干净）。清空后行为与手动登录一致。
  ///
  /// 走 [CasLoginService] 完整真实登录链路（刷新 ehall 会话 + https 补 CASTGC），
  /// 比注入 cookie 可靠（Chromium 常忽略注入的 Secure/HttpOnly cookie）。
  /// 成功后落盘 Cookie，返回 true；任何失败（无凭据 / 超时 / 账号错误）均返回 false。
  Future<bool> autoRelogin() {
    // 互斥锁：串行化"清 cookie + 重登"，防止并发调用互相清空会话
    final prev = _autoReloginLock ?? Future.value();
    final run = prev.then((_) => _doAutoRelogin());
    // 无论成败都推进锁链，避免一次失败卡死后续所有重登
    _autoReloginLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// 确保统一认证会话新鲜（CAS 会话预热）
  ///
  /// 冷启动（SplashPage）已每次真实登录，但 **App 运行期间** authserver 的
  /// TGC（CASTGC）仍可能在服务端过期——本地 cookie 罐里是"死 CASTGC"，
  /// 直接注入 WebView（邮件 / CARSI / 玻尔科研等 SSO 场景）会卡在 CAS 登录页。
  /// 此前只有学科竞赛（scjx2 bootstrap 失败 → autoRelogin）隐式做了刷新，
  /// 导致"必须先访问学科竞赛，邮件 / CARSI / 玻尔才能免密进入"的依赖。
  ///
  /// ⚠️ 必须探测 **authserver 的 TGC**（[SharedHttpClient.verifyCasTgc]），
  /// 而不是 ehall 业务会话（[SharedHttpClient.verifySession]）：
  /// ehall 会话（MOD_AUTH_CAS / JSESSIONID）的存活期通常远长于 TGC，
  /// 用它代替探测会在 TGC 已死时误判"会话新鲜"→ 跳过重登 → 注入死 CASTGC
  /// （本缺陷的根因，2026-08-08 修复）。
  ///
  /// 策略：
  /// 1. 本地连 CASTGC 都没有 → autoRelogin 静默重登（有账号密码时）；
  /// 2. 本地有 CASTGC → [SharedHttpClient.verifyCasTgc] 直接探测 authserver
  ///    （302 = SSO 放行即有效；200 登录表单 = TGC 已过期）；
  /// 3. 探测判定过期 / 失败 → autoRelogin 用已存账号密码刷新。
  ///
  /// 返回 true 表示本地已有（或已刷新出）可用会话。
  Future<bool> ensureFreshSession() async {
    if (!client.hasCastgc()) return autoRelogin();
    // 有本地会话：先探测 authserver TGC 是否仍有效；探测异常（网络抖动等）
    // 按"有会话"放行，交给 WebView 手动登录兜底，不贸然清 cookie 重登。
    try {
      if (await client.verifyCasTgc()) return true;
    } catch (_) {
      return true;
    }
    return autoRelogin();
  }

  Future<bool> _doAutoRelogin() async {
    final username = await LocalStorage.getString('username') ?? '';
    final password = await LocalStorage.getString('password') ?? '';
    if (username.trim().isEmpty || password.isEmpty) return false;

    try {
      // 先清空旧 cookie（内存 + 磁盘），保证本次登录产生全新、干净的 cookie 罐，
      // 与手动登录页行为一致。旧 cookie 已过期时注入 WebView 只会触发
      // CAS 刷新回环（"用久了只有手动重登才成功"的根因）。
      await client.clearCookies();
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
