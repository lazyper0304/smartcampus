import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../main.dart';
import 'guest_mode.dart';
import 'navigation.dart';

/// 游客模式下点击需登录功能时的统一拦截弹窗。
///
/// 用户选择「去登录」时退出游客模式并跳转登录页。
Future<void> showGuestLoginDialog(BuildContext context, {String? featureName}) async {
  final accent = accentColorNotifier.value;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: accent, size: 22),
          const SizedBox(width: 8),
          const Text('需要登录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      ),
      content: Text(
        featureName != null
            ? '「$featureName」需要登录后才能使用，当前处于游客模式。'
            : '该功能需要登录后才能使用，当前处于游客模式。',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('取消', style: TextStyle(color: Colors.grey[600])),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('去登录'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await GuestMode.exit();
    if (!context.mounted) return;
    pushAndClear(context, const LoginPage());
  }
}
