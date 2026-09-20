import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/login_page.dart';
import '../core/beginner_mode.dart';
import '../core/guest_mode.dart';
import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../home/main_screen.dart';
import '../xuegong/student_info_manager.dart';
import 'fetch_info_page.dart';

/// 启动分流结果：要进入的页面 + 已完成本地会话加载的共享 HTTP 客户端。
class StartupTarget {
  final Widget page;
  final SharedHttpClient client;

  const StartupTarget({required this.page, required this.client});
}

/// 执行启动分流（从原 `SplashPage._checkSession` 原样迁出）。
///
/// 调用时机变更（2026-09-20）：**在欢迎首屏展示期间静默执行**，用户点
/// 「开始使用」/向上拉出时目标页已就绪 → 直接呈现，不再出现"验证 Cookie 中…"
/// 的中间过渡屏（用户明确要求「不要跳转到新的登录界面」）。
///
/// 分流规则（与原实现完全一致，勿改）：
/// - 游客模式 → 主界面（userId 空，仅免登录功能）；
/// - 有本地账号密码 → 真实 CAS 登录（全新 cookie，杜绝死 cookie 回环）：
///   - 无个人信息缓存且非新生模式 → 个人信息获取页；
///   - 否则 → 主界面；
/// - 无凭据 / 重登失败 → 登录页。
Future<StartupTarget> resolveStartupTarget() async {
  final client = SharedHttpClient();
  await client.loadCookies();
  await GuestMode.load();
  await BeginnerMode.load();

  // 游客模式：跳过会话校验，直接进入首页（仅可用免登录功能）
  if (GuestMode.active) {
    return StartupTarget(
      page: MainScreen(client: client, userId: ''),
      client: client,
    );
  }

  // 每次进入应用都用本地保存的账号密码走**真实 CAS 登录**（全新 cookie），
  // 不再复用可能已过期的本地 cookie（服务端 TTL 过期后本地是"死 cookie"，
  // 注入 WebView 只会触发 CAS 刷新回环 → 学科竞赛等模块获取失败）。
  final autoAuth = AuthService(sharedClient: client);
  if (await autoAuth.autoRelogin()) {
    final savedUser = await LocalStorage.getString('saved_username') ?? '';

    // 首次进入需先获取到个人信息（无缓存时走 FetchInfoPage 阻塞获取），
    // 后续有缓存直接进主界面。
    // 新生模式：已登录但个人信息暂未录入，跳过获取直接进主界面。
    final cached = await StudentInfoManager.getCached();
    if (cached == null && !BeginnerMode.active) {
      return StartupTarget(page: FetchInfoPage(client: client), client: client);
    }
    return StartupTarget(
      page: MainScreen(client: client, userId: savedUser),
      client: client,
    );
  }

  // 无本地凭据（首次使用 / 已退出登录 / 自动重登失败）→ 登录页；
  // 登录成功后凭据会保存，下次启动即可自动重登。
  return StartupTarget(page: const LoginPage(), client: client);
}
