import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme_utils.dart';
import '../../core/version.dart';
import '../../main.dart';
import 'update_models.dart';
import 'update_service.dart';

/// 更新相关的对话框与交互流程。
///
/// 对外只暴露 [showUpdateCheckFlow] 与 [showChangelogFlow] 两个入口，
/// 由设置页等调用方通过 onTap 触发，内部已封装 loading 与错误提示。

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

/// 检查更新：显示 loading → 请求 → 弹「发现新版本 / 已是最新」提示。
Future<void> showUpdateCheckFlow(BuildContext context) async {
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
    final result = await UpdateService.checkForUpdate();
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (result.hasUpdate) {
      _showUpdateDialog(context, result);
    } else {
      _showSnack(context, '已是最新版本 (v$appVersion)');
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _showSnack(context, '检查更新失败：$e');
  }
}

void _showUpdateDialog(BuildContext context, UpdateCheckResult result) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('发现新版本 ${result.latestTag}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前版本：v$appVersion',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(result.releaseNotes,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _openUrl(result.downloadUrl);
          },
          child: const Text('前往下载'),
        ),
      ],
    ),
  );
}

/// 更新日志：显示 loading → 拉取 release 列表 → 弹日志对话框。
Future<void> showChangelogFlow(BuildContext context) async {
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
    final releases = await UpdateService.fetchReleases();
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (releases.isEmpty) {
      _showSnack(context, '暂无更新记录');
      return;
    }
    _showChangelogDialog(context, releases);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _showSnack(context, '加载更新日志失败：$e');
  }
}

void _showChangelogDialog(BuildContext context, List<ReleaseInfo> releases) {
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
                final r = releases[i];
                final date =
                    r.publishedAt.length >= 10 ? r.publishedAt.substring(0, 10) : '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColorNotifier.value.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(r.tagName,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accentColorNotifier.value)),
                        ),
                        const SizedBox(width: 8),
                        if (date.isNotEmpty)
                          Text(date,
                              style: TextStyle(fontSize: 11, color: textHint(context))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r.body, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
