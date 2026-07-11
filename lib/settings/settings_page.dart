import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../auth/login_page.dart';
import '../core/local_storage.dart';
import '../core/http_client.dart';
import '../core/version.dart';
import '../main.dart';
import '../xuegong/student_info_manager.dart';
import '../xuegong/student_info_detail_page.dart';

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
    if (mounted) setState(() { _studentInfo = info; _loadingInfo = false; });
  }

  Future<void> _refreshInfo() async {
    if (widget.client == null) return;
    setState(() => _loadingInfo = true);
    final info = await StudentInfoManager.fetchAndCache(widget.client!);
    if (mounted) setState(() { _studentInfo = info; _loadingInfo = false; });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        return GlassPage(
          statusBarStyle: GlassStatusBarStyle.auto,
          child: Scaffold(
            body: SafeArea(
              child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 个人信息卡片 ──
                if (_loadingInfo)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  )
                else if (_studentInfo != null)
                  _buildStudentCard(_studentInfo!),

                // ── 外观 ──
                const SizedBox(height: 16),
                _buildSection('外观'),
                // ... (外观设置不变)
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildThemeOption(
                          icon: Icons.brightness_auto_rounded,
                          label: '跟随系统',
                          selected: currentMode == ThemeMode.system,
                          onTap: () => _setMode(ThemeMode.system),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildThemeOption(
                          icon: Icons.light_mode_rounded,
                          label: '浅色',
                          selected: currentMode == ThemeMode.light,
                          onTap: () => _setMode(ThemeMode.light),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildThemeOption(
                          icon: Icons.dark_mode_rounded,
                          label: '深色',
                          selected: currentMode == ThemeMode.dark,
                          onTap: () => _setMode(ThemeMode.dark),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection('账号'),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        context,
                        icon: Icons.logout_rounded,
                        title: '退出登录',
                        subtitle: '清除登录状态，返回登录页面',
                        color: Colors.red,
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection('关于'),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile('版本', appVersion),
                      _buildDivider(),
                      _buildSettingTile(
                        context,
                        icon: Icons.update_rounded,
                        title: '检查更新',
                        subtitle: '查看是否有新版本可用',
                        color: const Color.fromRGBO(25, 25, 153, 1),
                        onTap: _checkUpdate,
                      ),
                      _buildDivider(),
                      _buildSettingTile(
                        context,
                        icon: Icons.history_rounded,
                        title: '更新日志',
                        subtitle: '查看版本更新记录',
                        color: Colors.teal,
                        onTap: _showChangelog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildStudentCard(StudentInfo info) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StudentInfoDetailPage(info: info)),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 头像
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.05),
                  border: Border.all(color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: info.hasPhoto
                      ? Image.memory(
                          Uint8List.fromList(info.photoBytes),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarFallback(info.name),
                        )
                      : _buildAvatarFallback(info.name),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(info.studentId,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    if (info.major.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(info.major,
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color.fromRGBO(25, 25, 153, 1)),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Future<void> _setMode(ThemeMode mode) async {
    final appState = SmartCampusApp.of(context);
    await appState?.setThemeMode(mode);
  }

  /// 检查更新：获取 GitHub latest release 并与本地版本对比
  Future<void> _checkUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 16),
                Text('正在检查更新…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/lazyper0304/smartcampus/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (resp.statusCode != 200) {
        _showSnack('检查更新失败：无法连接到 GitHub');
        return;
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final latestTag = json['tag_name']?.toString() ?? '';
      final releaseBody = json['body']?.toString() ?? '';
      final htmlUrl = json['html_url']?.toString() ?? 'https://github.com/lazyper0304/smartcampus/releases/latest';
      if (latestTag.isEmpty) {
        _showSnack('获取版本信息失败');
        return;
      }

      // 去除 tag 前缀 v（如 v1.0.0 → 1.0.0）
      final latestVer = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

      if (_compareVersion(latestVer, appVersion) > 0) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('发现新版本 $latestTag'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('当前版本：v$appVersion', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Text(releaseBody, style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openUrl(htmlUrl);
                },
                child: const Text('前往下载'),
              ),
            ],
          ),
        );
      } else {
        if (mounted) _showSnack('已是最新版本 (v$appVersion)');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack('检查更新失败：$e');
    }
  }

  /// 展示更新日志（从 GitHub Releases 获取）
  Future<void> _showChangelog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 16),
                Text('加载更新日志…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/lazyper0304/smartcampus/releases?per_page=20'),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (resp.statusCode != 200) {
        _showSnack('加载更新日志失败');
        return;
      }

      final releases = jsonDecode(resp.body) as List;
      if (releases.isEmpty) {
        _showSnack('暂无更新记录');
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            children: [
              Container(
                color: const Color.fromRGBO(25, 25, 153, 1),
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Text('更新日志',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: releases.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, i) {
                    final r = releases[i] as Map<String, dynamic>;
                    final tag = r['tag_name']?.toString() ?? '';
                    final name = r['name']?.toString() ?? tag;
                    final body = r['body']?.toString() ?? '';
                    final published = r['published_at']?.toString() ?? '';
                    final date = published.length >= 10 ? published.substring(0, 10) : '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tag,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: Color.fromRGBO(25, 25, 153, 1))),
                            ),
                            const SizedBox(width: 8),
                            if (date.isNotEmpty)
                              Text(date,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(body,
                            style: const TextStyle(fontSize: 13, height: 1.5)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack('加载更新日志失败：$e');
    }
  }

  /// 比较语义化版本号，a > b 返回正数，a == b 返回 0，a < b 返回负数
  int _compareVersion(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const blue = Color.fromRGBO(25, 25, 153, 1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? blue.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? blue.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? blue : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: selected ? blue : Colors.grey[600])),
            if (selected) ...[
              const SizedBox(height: 4),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: blue, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, {
    required IconData icon, required String title,
    required String subtitle, required Color color, required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]);
  }

  Future<void> _logout(BuildContext context) async {
    await StudentInfoManager.clearCache();
    await LocalStorage.remove('username');
    await LocalStorage.remove('password');
    await LocalStorage.remove('saved_username');
    await LocalStorage.setBool('remember_password', false);
    final client = SharedHttpClient();
    await client.clearCookies();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
