import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 系统 `openFile` MethodChannel（仅 Android 有原生实现：
/// FileProvider content:// 授权，Android 7+ 禁止 file:// 直接暴露给外部应用）
const _channel = MethodChannel('com.smartcampus.smartcampus/file');

/// 把本地文件交给系统默认应用打开（附件下载后的"打开文件"）。
///
/// 平台分发：
/// - **Android**：走 MethodChannel `openFile`（content:// + 临时授权，
///   唤起系统默认关联应用，如 WPS）；
/// - **Windows / Linux / macOS**：走 [url_launcher] 打开 `file://` URI
///   （Windows 内部用 ShellExecute 唤起系统默认关联程序，
///   支持 doc/xlsx/pdf/zip/图片等）——避免 MethodChannel 在桌面端
///   MissingPluginException；
/// - **Web**：不支持本地文件打开，提示。
///
/// 失败时自动用 SnackBar 提示用户。
Future<void> openFileWithSystem(BuildContext context, String path) async {
  try {
    if (kIsWeb) {
      if (context.mounted) _toast(context, '当前平台不支持打开本地文件');
      return;
    }
    // Android 保留原生 FileProvider 通道
    if (Platform.isAndroid) {
      await _channel.invokeMethod<bool>('openFile', {'path': path});
      return;
    }
    // 桌面端：file:// URI 交给系统默认应用
    final ok = await launchUrl(
      Uri.file(path),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      _toast(context, '未找到可打开该文件的应用（建议安装 WPS）');
    }
  } on PlatformException catch (e) {
    final msg = switch (e.code) {
      'NO_APP' => '未找到可打开该文件的应用（建议安装 WPS）',
      'NO_FILE' => '文件不存在或已失效',
      _ => '无法打开文件：${e.message ?? e.code}',
    };
    if (context.mounted) _toast(context, msg);
  } catch (e) {
    if (context.mounted) _toast(context, '无法打开文件：$e');
  }
}

void _toast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}
