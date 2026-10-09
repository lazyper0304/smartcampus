import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/bingo/bingo_client.dart';
import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'bingo_auth_service.dart';
import 'cas_login_service.dart';

class LoginResult {
  final bool success;
  final String message;

  /// Bingo 代理侧是否成功（课表/成绩/评教/通知/第二课堂依赖它）
  final bool bingoSuccess;

  /// CAS 统一认证侧是否成功（SSO 类模块依赖它）
  final bool casSuccess;

  /// 需图形验证码时携带的挑战载荷
  final LoginCaptchaChallenge? challenge;

  const LoginResult({
    required this.success,
    required this.message,
    this.bingoSuccess = false,
    this.casSuccess = false,
    this.challenge,
  });

  /// 双下放均成功
  LoginResult.dual({
    required this.bingoSuccess,
    required this.casSuccess,
    this.message = '登录成功',
  })  : success = true,
        challenge = null;

  LoginResult.failed(this.message)
      : success = false,
        bingoSuccess = false,
        casSuccess = false,
        challenge = null;
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

  /// 双下放登录：一次登录同时下发两套凭证
  ///
  /// - **Bingo 侧**：`POST /auth/login`（LDAP 验密 + 图形验证码），
  ///   落地 `access_token` / `refresh_token`，供课表 / 成绩 / 评教 /
  ///   办公网通知 / 第二课堂等代理接口使用。
  /// - **CAS 侧**：原有 `CasLoginService` 完整登录链路，落地 CASTGC 等
  ///   cookie，供邮件 / CARSI / 玻尔科研等 SSO 模块使用。
  ///
  /// 两路**并发**发起、**互不阻断**：Bingo 失败不牵连 CAS，反之亦然。
  /// 只要 Bingo 成功即视为登录成功（五个目标模块全部可用）。
  /// CAS 失败仅降级提示，不影响主流程；后续 `ensureFreshSession` 仍会
  /// 用已保存凭据自动补齐 CAS 会话。
  Future<LoginResult> login({
    String? loginUrl,
    required String username,
    required String password,
    String? captchaId,
    String? captchaCode,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      return LoginResult.failed('用户名或密码不能为空');
    }

    final schoolId = username.trim();

    // 两路并发：Bingo 走 HTTPS API，CAS 走 authserver
    final bingoFuture = _loginBingo(schoolId, password, captchaId, captchaCode);
    final casFuture = _loginCas(loginUrl, schoolId, password);

    final bingo = await bingoFuture;
    final cas = await casFuture;

    if (bingo.error != null) {
      final err = bingo.error!;
      // 密码错误 / 验证码错误等，两侧都会失败，优先展示 Bingo 的用户可读文案
      return LoginResult(
        success: false,
        message: err.message,
        challenge: bingo.challenge,
      );
    }

    if (!cas.success) {
      debugPrint('[Auth] 双下放：CAS 侧登录失败（不影响 Bingo 模块）: ${cas.message}');
      return LoginResult(
        success: true,
        message: cas.success
            ? '登录成功'
            : '登录成功（部分功能需重新授权）',
        bingoSuccess: true,
        casSuccess: cas.success,
        challenge: bingo.challenge,
      );
    }

    return LoginResult.dual(bingoSuccess: true, casSuccess: true);
  }

  /// Bingo 侧登录结果
  Future<_BingoOutcome> _loginBingo(
    String schoolId,
    String password,
    String? captchaId,
    String? captchaCode,
  ) async {
    try {
      await BingoAuthService.instance
          .login(
            schoolId: schoolId,
            password: password,
            captchaId: captchaId,
            captchaCode: captchaCode,
          )
          .timeout(const Duration(seconds: 30));
      return const _BingoOutcome(success: true);
    } on BingoException catch (e) {
      // 服务端可能在下发错误的同时内嵌验证码挑战，登录页据此重绘输入框
      return _BingoOutcome(
        success: false,
        message: e.message,
        challenge: e.captcha,
        error: e,
      );
    } on TimeoutException {
      return _BingoOutcome(
        success: false,
        message: '网络请求超时，请检查网络连接',
        error: BingoException('网络请求超时，请检查网络连接'),
      );
    } catch (e) {
      return _BingoOutcome(
        success: false,
        message: '登录失败：$e',
        error: BingoException('登录失败：$e'),
      );
    }
  }

  /// 供登录页回填：CAS 侧登录结果
  Future<_CasOutcome> _loginCas(
      String? loginUrl, String schoolId, String password) async {
    try {
      await _casLoginService
          .login(
            loginUrl: loginUrl ?? CasLoginService.yibinLoginUrl,
            username: schoolId,
            password: password,
          )
          .timeout(const Duration(seconds: 60));
      return const _CasOutcome(success: true);
    } on TimeoutException {
      return const _CasOutcome(
          success: false, message: '统一认证超时，部分功能不可用');
    } on Exception catch (e) {
      return _CasOutcome(
          success: false,
          message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 查询是否需要图形验证码（学号输入防抖后调用）
  Future<LoginCaptchaChallenge> queryCaptchaStatus(String schoolId) =>
      BingoAuthService.instance.fetchCaptchaStatus(schoolId);

  /// 取图形验证码图片
  Future<LoginCaptchaChallenge> fetchCaptcha(String schoolId) =>
      BingoAuthService.instance.fetchCaptcha(schoolId);

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

    // Bingo 侧优先续期（无验证码挑战时可直接成功），失败不影响 CAS 侧
    var bingoOk = BingoClient.isLoggedIn;
    if (!bingoOk && username.trim().isNotEmpty && password.isNotEmpty) {
      try {
        await BingoAuthService.instance
            .login(schoolId: username.trim(), password: password)
            .timeout(const Duration(seconds: 30));
        bingoOk = true;
      } catch (e) {
        debugPrint('[Auth] autoRelogin: Bingo 侧失败 - $e');
      }
    }

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

/// Bingo 侧登录的内部结果
class _BingoOutcome {
  const _BingoOutcome({
    required this.success,
    this.message = '',
    this.challenge,
    this.error,
  });

  final bool success;
  final String message;
  final LoginCaptchaChallenge? challenge;

  /// 非空表示失败，携带可展示的错误
  final BingoException? error;
}

/// CAS 侧登录的内部结果
class _CasOutcome {
  const _CasOutcome({required this.success, this.message = ''});
  final bool success;
  final String message;
}
