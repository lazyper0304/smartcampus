import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../core/theme_utils.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../core/version.dart';
import '../core/http_client.dart';
import '../xuegong/student_info_detail_page.dart';
import '../xuegong/student_info_manager.dart';
import 'about_page.dart';
import 'appearance_page.dart';
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
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 个人信息卡片（始终显示） ──
              _buildInfoCard(context),
              const SizedBox(height: 16),
              _buildSection('外观'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A3E)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: accentColorNotifier.value.withValues(alpha: 0.08),
                  ),
                ),
                child: _buildSettingTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: '外观',
                  subtitle: '切换浅色/深色模式',
                  color: accentColorNotifier.value,
                  onTap: () => pushPage(context, const AppearancePage()),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection('账号'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A3E)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
                ),
                child: _buildSettingTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: '关于',
                    subtitle: '版本 $appVersion',
                    color: accentColorNotifier.value,
                    onTap: () => pushPage(context, const AboutPage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

  /// 个人信息卡片：有数据展示学生信息，无数据显示占位鼓励手动获取
  Widget _buildInfoCard(BuildContext context) {
    // 首次加载且无缓存
    if (_loadingInfo && _studentInfo == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.1)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    // 有数据 → 展示完整信息
    if (_studentInfo != null) {
      return _buildStudentCard(_studentInfo!);
    }

    // 无数据 → 占位卡片，点击手动获取
    return GestureDetector(
      onTap: widget.client != null ? _refreshInfo : null,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Colors.grey.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Icon(Icons.person_outline_rounded,
                    color: Colors.grey.shade400, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client != null ? '点击获取个人信息' : '个人信息暂不可用',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.client != null ? '手动拉取学号、姓名、专业等信息' : '请在登录后查看',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (widget.client != null)
                Icon(Icons.refresh_rounded, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentInfo info) {
    return GestureDetector(
      onTap: () => pushPage(context, StudentInfoDetailPage(info: info)),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.1)),
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
                  color: accentColorNotifier.value.withValues(alpha: 0.05),
                  border: Border.all(color: accentColorNotifier.value.withValues(alpha: 0.1)),
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
                        style: TextStyle(fontSize: 13, color: textSecondary(context))),
                    if (info.major.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(info.major,
                          style: TextStyle(fontSize: 12, color: textHint(context)),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textHint(context), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      color: accentColorNotifier.value.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: accentColorNotifier.value),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 13, color: textHint(context)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: textSecondary(context)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary(context)),
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
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textHint(context), size: 20),
          ],
        ),
      ),
    );
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
    pushAndClear(context, const LoginPage());
  }
}
