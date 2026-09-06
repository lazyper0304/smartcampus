import 'dart:convert' show base64Decode;

import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/responsive.dart' show bottomBarSafePadding;
import '../core/simple_page.dart';
import '../core/theme_utils.dart' show textSecondary, dividerColor;
import 'vpn_service.dart';
import 'vpn_windows_core.dart' show VpnWindowsCoreCaptchaBridge;

/// 校园 VPN 页面 — 深信服 EasyConnect 接入（yibinu-connect 开源实现）。
///
/// 大圆钮连接/断开 + 账号配置卡片；状态经 VpnService.phase 全局通知器驱动。
/// 仅 Android / Windows 端可用。
class VpnPage extends StatefulWidget {
  final String? initialUsername;

  const VpnPage({super.key, this.initialUsername});

  @override
  State<VpnPage> createState() => _VpnPageState();
}

class _VpnPageState extends State<VpnPage> with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _busy = false;

  /// 连接按钮呼吸动画（连接中）
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    lowerBound: 0.92,
    upperBound: 1.06,
  );

  @override
  void initState() {
    super.initState();
    VpnService.phase.addListener(_onPhase);
    VpnService.captchaHandler = _showCaptchaDialog;
    // Windows 内核子进程经 stdio 行协议请求验证码，复用同一弹窗
    VpnWindowsCoreCaptchaBridge.handler = _showCaptchaDialog;
    _loadSavedConfig();
  }

  /// 图形验证码弹窗：展示服务端下发的验证码图片，返回用户输入（取消=空串）
  Future<String> _showCaptchaDialog(String base64Image) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('请输入验证码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                base64Decode(base64Image),
                height: 48,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: '验证码',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(''),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return code ?? '';
  }

  Future<void> _loadSavedConfig() async {
    final cfg = await VpnService.loadConfig();
    if (!mounted) return;
    setState(() {
      _usernameCtrl.text =
          cfg.username.isNotEmpty ? cfg.username : (widget.initialUsername ?? '');
      _passwordCtrl.text = cfg.password;
      _remember = cfg.rememberPassword;
    });
  }

  void _toggleRemember(bool? value) {
    if (value == null) return;
    setState(() => _remember = value);
    // 关闭时立即清除已保存的密码，避免残留
    VpnService.setRememberPassword(value);
  }

  void _onPhase() {
    final phase = VpnService.phase.value;
    final busy = phase == VpnPhase.authenticating ||
        phase == VpnPhase.connecting ||
        phase == VpnPhase.disconnecting;
    if (!mounted) return;
    setState(() => _busy = busy);
    if (phase == VpnPhase.connecting) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = _pulse.lowerBound;
    }
  }

  @override
  void dispose() {
    VpnService.phase.removeListener(_onPhase);
    VpnService.captchaHandler = null;
    VpnWindowsCoreCaptchaBridge.handler = null;
    _pulse.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    FocusScope.of(context).unfocus();
    // 已连接时点击 = 断开（_busy 只覆盖中间态，connected 态下为 false，
    // 若仅凭 _busy 判断会误入连接分支重新触发认证/验证码）
    final current = VpnService.phase.value;
    if (_busy || current == VpnPhase.connected) {
      await VpnService.disconnect();
      return;
    }
    final ok = await VpnService.connect(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberPassword: _remember,
    );
    if (!ok && mounted && VpnService.lastError.value != null) {
      // 错误信息已由页面错误区展示，无需额外弹窗打断
    }
  }

  // ==================== UI ====================

  ({Color color, String label, IconData icon}) _statusVisual(VpnPhase phase) {
    switch (phase) {
      case VpnPhase.connected:
        return (color: const Color(0xFF34C759), label: '已连接', icon: Icons.lock_open_rounded);
      case VpnPhase.authenticating:
        return (color: const Color(0xFFFF9500), label: '正在认证…', icon: Icons.sync_rounded);
      case VpnPhase.connecting:
        return (color: const Color(0xFFFF9500), label: '正在建立隧道…', icon: Icons.sync_rounded);
      case VpnPhase.disconnecting:
        return (color: const Color(0xFFFF9500), label: '正在断开…', icon: Icons.sync_rounded);
      case VpnPhase.idle:
        return (color: const Color(0xFF8E8E93), label: '未连接', icon: Icons.lock_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SimplePage(
      child: Scaffold(
        appBar: AppBar(title: const Text('校园 VPN'), centerTitle: true),
        body: !VpnService.isSupported
            ? Center(
                child: IosCard(
                  margin: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.vpn_lock_rounded,
                          size: 42, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('当前平台暂不支持',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text('VPN 功能目前支持 Android 与 Windows 端',
                          style: TextStyle(color: textSecondary(context))),
                    ],
                  ),
                ),
              )
            : SafeArea(
                child: ValueListenableBuilder<VpnPhase>(
                  valueListenable: VpnService.phase,
                  builder: (context, phase, _) {
                    final visual = _statusVisual(phase);
                    final connected = phase == VpnPhase.connected;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                          20, 8, 20, bottomBarSafePadding(context)),
                      children: [
                        const SizedBox(height: 16),

                        // ── 大连接按钮 ──
                        Center(
                          child: ScaleTransition(
                            scale: _pulse,
                            child: GestureDetector(
                              onTap: _toggle,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: connected
                                      ? visual.color.withValues(alpha: 0.16)
                                      : visual.color.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: visual.color.withValues(alpha: 0.55),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: visual.color.withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(visual.icon,
                                        size: 44, color: visual.color),
                                    const SizedBox(height: 6),
                                    Text(
                                      connected ? '断开' : '连接',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: visual.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            visual.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: visual.color,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: VpnService.clientIp,
                          builder: (context, ip, _) => ip == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Center(
                                    child: Text(ip,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary(context))),
                                  ),
                                ),
                        ),

                        // ── 错误提示 ──
                        ValueListenableBuilder<String?>(
                          valueListenable: VpnService.lastError,
                          builder: (context, err, _) => err == null
                              ? const SizedBox(height: 28)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: IosCard(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded,
                                            size: 18, color: Color(0xFFFF3B30)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(err,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFFD70015))),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // ── 账号配置 ──
                        IosSectionHeader('账号'),
                        IosCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // hintText 占位符（labelText 浮动标签会被玻璃卡片裁剪遮挡）
                              TextField(
                                controller: _usernameCtrl,
                                enabled: !_busy,
                                decoration: const InputDecoration(
                                  hintText: '用户名',
                                  hintStyle:
                                      TextStyle(fontWeight: FontWeight.w400),
                                  prefixIcon:
                                      Icon(Icons.person_outline_rounded),
                                  border: InputBorder.none,
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: dividerColor(context)),
                              TextField(
                                controller: _passwordCtrl,
                                enabled: !_busy,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  hintText: '密码',
                                  prefixIcon:
                                      const Icon(Icons.password_rounded),
                                  border: InputBorder.none,
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: dividerColor(context)),
                              // 记住密码勾选（整行可点）
                              InkWell(
                                onTap: _busy ? null : () => _toggleRemember(!_remember),
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Checkbox(
                                        value: _remember,
                                        onChanged:
                                            _busy ? null : _toggleRemember,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text('记住密码',
                                          style: theme.textTheme.bodyLarge),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── 接入信息 ──
                        IosSectionHeader('接入信息'),
                        IosListGroup(
                          children: [
                            IosListTile(
                              icon: Icons.dns_rounded,
                              title: '服务器',
                              subtitle: VpnService.kDefaultServer.replaceFirst(
                                  'https://', ''),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
