import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login_page.dart';
import '../core/guest_mode.dart';
import '../core/theme_utils.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../core/responsive.dart';
import '../core/adaptive_split_view.dart';
import '../core/version.dart';
import '../core/http_client.dart';
import '../core/ios_kit.dart';
import '../xuegong/student_info_detail_page.dart';
import '../xuegong/student_info_manager.dart';
import 'appearance_page.dart';
import 'privacy_policy_page.dart';
import 'quick_apps_page.dart';
import 'update/update_dialogs.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class SettingsPage extends StatefulWidget {
  final SharedHttpClient? client;

  const SettingsPage({super.key, this.client});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  StudentInfo? _studentInfo;
  bool _loadingInfo = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await StudentInfoManager.getCached();
    if (!mounted) return;
    if (info != null) {
      setState(() { _studentInfo = info; _loadingInfo = false; });
      return;
    }
    // 无缓存：进入即自动拉取（学号、姓名、专业等），期间显示"正在获取中"
    setState(() => _loadingInfo = true);
    final fetched = await StudentInfoManager.fetchAndCache(widget.client!);
    if (mounted) {
      setState(() { _studentInfo = fetched; _loadingInfo = false; });
    }
  }

  Future<void> _refreshInfo() async {
    if (widget.client == null) return;
    setState(() => _loadingInfo = true);
    final info = await StudentInfoManager.fetchAndCache(widget.client!);
    if (mounted) setState(() { _studentInfo = info; _loadingInfo = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      // MainScreen GlassScaffold 已提供背景，不重复叠加
      background: false,
      // 透明背景：透出 GlassScaffold 的渐变+光斑（液态玻璃背景源）
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          // 底部浮动玻璃导航栏为浮层，不占布局空间，交由 ListView 的
          // bottom padding 统一避让，此处关闭 SafeArea 底部避免重复留白。
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                kIosPageHPadding, 10, kIosPageHPadding,
                bottomBarSafePadding(context)),
            children: [
              MaxWidthContent(
                // 大屏放宽限宽以容纳两栏（窄屏仍按可用宽度铺满）
                maxWidth: kGridMaxWidth,
                child: Column(
                  // stretch 强制所有卡片同宽（个人信息卡/分组卡），
                  // 杜绝 loose 约束下卡片收缩导致的宽度不一致
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const IosLargeTitle(title: '设置'),
                    const SizedBox(height: 8),
                    // ── 大屏两栏：左（个人信息 + 外观）右（账号 + 关于）──
                    // 窄屏自动回落单列（顺序与原先一致，零回归）
                    AdaptiveSplitView(
                      leftFlex: 2,
                      rightFlex: 3,
                      left: LayoutBuilder(
                        builder: (context, c) {
                          // 卡片内部元素随本栏实际宽度自适应（大屏放大）
                          final scale = adaptiveCardScale(c.maxWidth);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── 个人信息卡片（始终显示） ──
                              _buildInfoCard(context, scale: scale),
                              const SizedBox(height: 16),
                              // ── 外观 ──
                              IosListGroup(
                                // ListView 已提供水平 padding，分组卡不再自带 margin，
                                // 保证与个人信息卡宽度一致
                                margin: EdgeInsets.zero,
                                children: [
                                  IosListTile(
                                    icon: Icons.palette_outlined,
                                    title: '外观',
                                    subtitle: '切换浅色/深色模式',
                                    scale: scale,
                                    onTap: () =>
                                        pushPage(context, const AppearancePage()),
                                  ),
                                  IosListTile(
                                    icon: Icons.grid_view_rounded,
                                    title: '常用功能',
                                    subtitle: '自定义首页快捷入口',
                                    scale: scale,
                                    onTap: () =>
                                        pushPage(context, const QuickAppsPage()),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      right: LayoutBuilder(
                        builder: (context, c) {
                          // 卡片内部元素随本栏实际宽度自适应（大屏放大）
                          final scale = adaptiveCardScale(c.maxWidth);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── 账号 ──
                              IosListGroup(
                                header: '账号',
                                // ListView 已提供水平 padding，分组卡不再自带 margin
                                margin: EdgeInsets.zero,
                                children: [
                                  if (GuestMode.active)
                                    IosListTile(
                                      icon: Icons.login_rounded,
                                      title: '登录账号',
                                      subtitle: '当前为游客模式，登录后可使用全部功能',
                                      scale: scale,
                                      onTap: () => _goLogin(context),
                                    )
                                  else
                                    IosListTile(
                                      icon: Icons.logout_rounded,
                                      iconColor: Colors.red,
                                      iconBackground:
                                          Colors.red.withValues(alpha: 0.1),
                                      title: '退出登录',
                                      subtitle: '清除登录状态，返回登录页面',
                                      scale: scale,
                                      onTap: () => _logout(context),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // ── 关于 ──
                              IosListGroup(
                                header: '关于',
                                // ListView 已提供水平 padding，分组卡不再自带 margin
                                margin: EdgeInsets.zero,
                                children: [
                                  IosListTile(
                                    icon: Icons.forum_rounded,
                                    iconColor: Colors.blue,
                                    iconBackground:
                                        Colors.blue.withValues(alpha: 0.1),
                                    title: '交流群',
                                    subtitle: '加入 QQ 群【宜院宾果】',
                                    scale: scale,
                                    onTap: () => _openQQGroup(context),
                                  ),
                                  IosListTile(
                                    icon: Icons.privacy_tip_outlined,
                                    iconColor: Colors.green.shade600,
                                    iconBackground:
                                        Colors.green.withValues(alpha: 0.1),
                                    title: '隐私协议',
                                    subtitle: '了解我们如何保护您的数据',
                                    scale: scale,
                                    onTap: () => pushPage(
                                        context, const PrivacyPolicyPage()),
                                  ),
                                  IosListTile(
                                    icon: Icons.update_rounded,
                                    title: '检查更新',
                                    subtitle: '当前版本 v$appVersion',
                                    scale: scale,
                                    onTap: () => showUpdateCheckFlow(context),
                                  ),
                                  IosListTile(
                                    icon: Icons.history_rounded,
                                    iconColor: Colors.teal,
                                    iconBackground:
                                        Colors.teal.withValues(alpha: 0.1),
                                    title: '更新日志',
                                    subtitle: '查看版本更新记录',
                                    scale: scale,
                                    onTap: () => showChangelogFlow(context),
                                  ),
                                  IosListTile(
                                    icon: Icons.person_rounded,
                                    iconColor: Colors.orange,
                                    iconBackground:
                                        Colors.orange.withValues(alpha: 0.12),
                                    title: '作者',
                                    subtitle: 'lazy波斯猫',
                                    scale: scale,
                                    onTap: null,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    }

  /// QQ 交流群链接（qm.qq.com 官方群推广页）
  static const String _qqGroupUrl = 'https://qm.qq.com/q/miOeBHKlRS';

  /// 打开交流群：Android 优先用 intent 直接拉起 QQ 客户端，
  /// QQ 未安装或其它平台降级为浏览器打开。
  Future<void> _openQQGroup(BuildContext context) async {
    Uri uri;
    if (Platform.isAndroid) {
      // intent scheme 指定 QQ 包名拉起；未安装时 fallback 到浏览器
      uri = Uri.parse(
        'intent://qm.qq.com/q/miOeBHKlRS#Intent;'
        'scheme=https;package=com.tencent.mobileqq;'
        'S.browser_fallback_url=${Uri.encodeComponent(_qqGroupUrl)};end',
      );
    } else {
      uri = Uri.parse(_qqGroupUrl);
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await launchUrl(Uri.parse(_qqGroupUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // intent 拉起失败（QQ 未安装等）→ 浏览器兜底
      try {
        await launchUrl(Uri.parse(_qqGroupUrl),
            mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  /// 个人信息卡片：有数据展示学生信息，无数据显示占位鼓励手动获取。
  /// [scale] 随卡片宽度自适应（大屏放大内部元素，默认 1.0 不变）。
  Widget _buildInfoCard(BuildContext context, {double scale = 1.0}) {
    // 游客模式：显示游客占位卡片，点击前往登录
    if (GuestMode.active) {
      return IosCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _goLogin(context),
        child: Row(
          children: [
            Container(
              width: 56 * scale, height: 56 * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13 * scale),
                color: Colors.grey.withValues(alpha: 0.08),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.person_outline_rounded,
                  color: Colors.grey.shade400, size: 28 * scale),
            ),
            SizedBox(width: 14 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('游客模式',
                      style: TextStyle(
                          fontSize: 15 * scale, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('登录后可查看个人信息并使用全部功能',
                      style: TextStyle(
                          fontSize: 12 * scale, color: Colors.grey.shade500)),
                ],
              ),
            ),
                Icon(Icons.login_rounded,
                    color: Colors.grey.shade400, size: 22 * scale),
              ],
            ),
      );
    }

    // 首次加载且无缓存（自动获取中）
    if (_loadingInfo && _studentInfo == null) {
      return IosCard(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            SizedBox(
              width: 24 * scale, height: 24 * scale,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(accentColorNotifier.value),
              ),
            ),
            SizedBox(height: 12 * scale),
            Text(
              '正在获取个人信息…',
              style: TextStyle(fontSize: 13 * scale, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // 有数据 → 展示完整信息
    if (_studentInfo != null) {
      return _buildStudentCard(_studentInfo!, scale: scale);
    }

    // 无数据 → 占位卡片，点击手动获取
    return IosCard(
      padding: const EdgeInsets.all(14),
      onTap: widget.client != null ? _refreshInfo : null,
      child: Row(
        children: [
          Container(
            width: 56 * scale, height: 56 * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13 * scale),
              color: Colors.grey.withValues(alpha: 0.08),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Icon(Icons.person_outline_rounded,
                color: Colors.grey.shade400, size: 28 * scale),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.client != null ? '获取失败，点击重试' : '个人信息暂不可用',
                  style: TextStyle(
                      fontSize: 15 * scale, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.client != null ? '手动拉取学号、姓名、专业等信息' : '请在登录后查看',
                  style: TextStyle(fontSize: 12 * scale, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (widget.client != null)
            Icon(Icons.refresh_rounded, color: Colors.grey.shade400, size: 22 * scale),
        ],
      ),
    );
  }

  Widget _buildStudentCard(StudentInfo info, {double scale = 1.0}) {
    return IosCard(
      padding: const EdgeInsets.all(14),
      onTap: () => pushPage(context, StudentInfoDetailPage(info: info)),
      child: Row(
        children: [
          // 头像
          Container(
            width: 56 * scale,
            height: 56 * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13 * scale),
              color: accentColorNotifier.value.withValues(alpha: 0.05),
              border: Border.all(color: accentColorNotifier.value.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12 * scale),
              child: info.hasPhoto
                  ? Image.memory(
                      Uint8List.fromList(info.photoBytes),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _buildAvatarFallback(info.name, scale: scale),
                    )
                  : _buildAvatarFallback(info.name, scale: scale),
            ),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name,
                    style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(info.studentId,
                    style: TextStyle(fontSize: 13 * scale, color: textSecondary(context))),
                    if (info.major.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(info.major,
                          style: TextStyle(fontSize: 12 * scale, color: textHint(context)),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: textHint(context), size: 22 * scale),
            ],
          ),
    );
  }

  Widget _buildAvatarFallback(String name, {double scale = 1.0}) {
    return Container(
      color: accentColorNotifier.value.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.w600, color: accentColorNotifier.value),
        ),
      ),
    );
  }

  /// 游客模式：退出游客态前往登录页（保留已记住的凭据）
  Future<void> _goLogin(BuildContext context) async {
    await GuestMode.exit();
    if (!context.mounted) return;
    pushAndClear(context, const LoginPage());
  }

  Future<void> _logout(BuildContext context) async {
    await GuestMode.exit();
    await StudentInfoManager.clearCache();
    await LocalStorage.remove('username');
    await LocalStorage.remove('password');
    await LocalStorage.remove('saved_username');
    await LocalStorage.setBool('remember_password', false);
    final client = SharedHttpClient();
    await client.clearCookies();
    if (!context.mounted) return;
    pushAndClear(context, const LoginPage());
  }

}
