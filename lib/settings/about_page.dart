import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/theme_utils.dart';
import '../core/version.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 关于页面 — 检查更新、更新日志、作者信息
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: const Text('关于')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildItem(
              context,
              icon: Icons.update_rounded,
              title: '检查更新',
              subtitle: '查看是否有新版本可用',
              color: accentColorNotifier.value,
              onTap: () => _checkUpdate(context),
            ),
            const SizedBox(height: 4),
            _buildItem(
              context,
              icon: Icons.history_rounded,
              title: '更新日志',
              subtitle: '查看版本更新记录',
              color: Colors.teal,
              onTap: () => _showChangelog(context),
            ),
            const SizedBox(height: 4),
            _buildItem(
              context,
              icon: Icons.person_rounded,
              title: '作者',
              subtitle: 'lazy波斯猫',
              color: Colors.orange,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A3E)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
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
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: textHint(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 检查更新 ====================

  Future<void> _checkUpdate(BuildContext context) async {
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

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (resp.statusCode != 200) {
        _showSnack(context, '检查更新失败：无法连接到 GitHub');
        return;
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final latestTag = json['tag_name']?.toString() ?? '';
      final releaseBody = json['body']?.toString() ?? '';
      // 使用直接下载链接，不跳转到 Release 页面
      final downloadUrl = latestTag.isNotEmpty
          ? 'https://github.com/lazyper0304/smartcampus/releases/download/$latestTag/app-release.apk'
          : 'https://github.com/lazyper0304/smartcampus/releases/latest';
      if (latestTag.isEmpty) {
        _showSnack(context, '获取版本信息失败');
        return;
      }

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
                  _openUrl(downloadUrl);
                },
                child: const Text('前往下载'),
              ),
            ],
          ),
        );
      } else {
        if (context.mounted) _showSnack(context, '已是最新版本 (v$appVersion)');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, '检查更新失败：$e');
    }
  }

  // ==================== 更新日志 ====================

  Future<void> _showChangelog(BuildContext context) async {
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

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (resp.statusCode != 200) {
        _showSnack(context, '加载更新日志失败');
        return;
      }

      final releases = jsonDecode(resp.body) as List;
      if (releases.isEmpty) {
        _showSnack(context, '暂无更新记录');
        return;
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            children: [
              Container(
                color: accentColorNotifier.value,
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Text('更新日志',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
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
                                color: accentColorNotifier.value.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tag,
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: accentColorNotifier.value)),
                            ),
                            const SizedBox(width: 8),
                            if (date.isNotEmpty)
                              Text(date, style: TextStyle(fontSize: 11, color: textHint(context))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
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
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, '加载更新日志失败：$e');
    }
  }

  // ==================== 工具方法 ====================

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

  void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;
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
}
