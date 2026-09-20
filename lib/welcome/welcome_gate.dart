import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../core/http_client.dart';
import '../splash/startup_flow.dart';
import 'welcome_page.dart';

/// 启动入口：**每次启动都展示欢迎首屏**，由用户**向上拉出**（或点「开始使用」）
/// 进入应用。
///
/// 关键行为（2026-09-20 定案，替代原 SplashPage 路由方案）：
/// - 会话/登录分流 [resolveStartupTarget] 在欢迎页展示期间**静默后台执行**，
///   因此用户拉出时**不再出现"验证 Cookie 中…"的中间过渡屏**（用户明确要求
///   「不要跳转到新的登录界面」）；
/// - 交接方式为**就地切换子组件**（根路由内容由欢迎页换成目标页），
///   不做 `Navigator` 跳转、无转场动画 —— 视觉上就是"拉起欢迎页后应用出现"；
/// - 目标未就绪时（拉出太快）显示极简「正在进入…」，就绪后原地替换。
class WelcomeGate extends StatefulWidget {
  /// 启动分流实现（默认 [resolveStartupTarget]）。
  ///
  /// 仅用于可测性：测试环境本地文件 IO 在 fake-async 下不会完成，
  /// 无法等出真实分流结果，故允许注入一个立即返回的假实现。
  final Future<StartupTarget> Function()? resolver;

  const WelcomeGate({super.key, this.resolver});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  /// 启动分流结果（null = 仍在后台加载）
  StartupTarget? _target;

  /// 用户已上滑拉出 / 点击开始使用 → 进入交接阶段
  bool _entering = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    StartupTarget target;
    try {
      target = await (widget.resolver ?? resolveStartupTarget)();
    } catch (_) {
      // 分流过程异常（本地存储/网络异常等）→ 兜底登录页，
      // 用户仍可手动登录，不会卡在欢迎页
      target = StartupTarget(
        page: const LoginPage(),
        client: SharedHttpClient(),
      );
    }
    if (!mounted) return;
    setState(() => _target = target);
  }

  /// 欢迎页已滑出屏幕 → 就地交出根路由内容
  void _enterApp() {
    if (_entering) return;
    setState(() => _entering = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_entering) {
      return WelcomePage(onStart: _enterApp);
    }
    final target = _target;
    if (target == null) return const _StartupLoading();
    return target.page;
  }
}

/// 极简"正在进入"占位（仅在用户拉出过快、分流尚未完成时短暂出现）：
/// 与主界面同款白色背景 + 小转圈，不构成独立的"加载页"观感。
class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF16161A)
          : const Color(0xFFF7F8FA),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
    );
  }
}
