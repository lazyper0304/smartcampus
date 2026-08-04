import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation.dart';
import '../../core/version.dart';
import '../../main.dart';
import 'changelog_page.dart';
import 'update_models.dart';
import 'update_service.dart';

/// 更新相关的对话框与交互流程。
///
/// 对外只暴露 [showUpdateCheckFlow] 与 [showChangelogFlow] 两个入口。
/// 检查更新复用同一个玻璃弹窗：先显示「正在检查更新…」，结果返回后
/// 原地切换为 已是最新 / 发现新版本 / 失败重试，不另弹新窗。

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// 检查更新：单个玻璃弹窗，内部按状态原地切换内容。
Future<void> showUpdateCheckFlow(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    // 淡遮罩：玻璃 Dialog 透出页面背景
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => const _UpdateCheckDialog(),
  );
}

/// 更新日志：跳转独立页面（页面自带加载中/失败重试/空态与下拉刷新）。
void showChangelogFlow(BuildContext context) {
  pushPage(context, const ChangelogPage());
}

/// 检查更新弹窗：loading → 已是最新 / 发现新版本 / 失败重试，原地切换。
class _UpdateCheckDialog extends StatefulWidget {
  const _UpdateCheckDialog();

  @override
  State<_UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<_UpdateCheckDialog> {
  bool _loading = true;
  String? _error;
  UpdateCheckResult? _result;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await UpdateService.checkForUpdate();
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '检查更新失败：$e';
          _loading = false;
        });
      }
    }
  }

  void _close() => Navigator.of(context).pop();

  void _download() {
    _close();
    _openUrl(_result!.downloadUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColorNotifier.value;
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      // 屏幕正中间 + 四周留白
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      // 磨砂玻璃：BackdropFilter 模糊 + 半透明渐变（弹窗固定不位移，采样稳定）
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                      .withValues(alpha: isDark ? 0.55 : 0.45),
                  (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                      .withValues(alpha: isDark ? 0.48 : 0.38),
                ],
                stops: const [0.0, 0.45],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildContent(accent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(Color accent) {
    // ── 检查中 ──
    if (_loading) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('正在检查更新…'),
              ],
            ),
          ),
        ),
      ];
    }
    // ── 失败 ──
    if (_error != null) {
      return [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFC2410C), size: 40),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _close, child: const Text('关闭')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _check, child: const Text('重试')),
          ],
        ),
      ];
    }
    final result = _result!;
    // ── 发现新版本 ──
    if (result.hasUpdate) {
      return [
        Text('发现新版本 ${result.latestTag}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text('当前版本：v$appVersion',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        Text(result.releaseNotes,
            style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _close, child: const Text('稍后')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _download, child: const Text('前往下载')),
          ],
        ),
      ];
    }
    // ── 已是最新版本 ──
    return [
      Center(child: Icon(Icons.check_circle_rounded, color: accent, size: 40)),
      const SizedBox(height: 12),
      const Center(
        child: Text('已是最新版本',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 6),
      Center(
        child: Text('当前版本 v$appVersion',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _close, child: const Text('好的')),
      ),
    ];
  }
}
