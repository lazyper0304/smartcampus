import 'dart:io';

import 'package:flutter/foundation.dart';

/// 全局崩溃日志：捕获 Flutter 框架错误 / 平台错误 / 未捕获异步异常，
/// 写入本地日志文件（Windows: %APPDATA%\smartcampus\logs\crash.log）。
///
/// 桌面端（尤其 Windows）native 层崩溃无法被 Dart 捕获，但 Flutter/Dart
/// 层错误与 WebView 初始化等操作日志均可落盘，用于远程排查闪退。
class CrashLog {
  CrashLog._();

  static File? _logFile;

  /// 初始化：建日志文件 + 挂接全局错误处理器。应在 main() 最早调用。
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final root = Platform.isWindows
          ? (Platform.environment['APPDATA'] ?? '.')
          : Directory.systemTemp.path;
      final dir = Directory('$root/smartcampus/logs');
      await dir.create(recursive: true);
      _logFile = File('${dir.path}/crash.log');
      _write('===== App 启动 ${DateTime.now()} =====');
      _write('platform: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}');
      _write('executable: ${Platform.resolvedExecutable}');
    } catch (_) {
      // 日志不可用不阻塞启动
    }

    // Flutter 框架错误（布局溢出、断言等）
    FlutterError.onError = (details) {
      _write('FLUTTER_ERROR: ${details.exception}');
      _write('${details.stack}');
      FlutterError.presentError(details);
    };

    // 平台/异步错误（native channel 异常等）
    PlatformDispatcher.instance.onError = (error, stack) {
      _write('PLATFORM_ERROR: $error');
      _write('$stack');
      return true; // 已处理，不触发红屏
    };
  }

  /// 追加一条日志（同时 debugPrint 便于调试）。
  static void write(String msg) => _write(msg);

  static void _write(String msg) {
    try {
      _logFile?.writeAsStringSync(
        '[${DateTime.now()}] $msg\n',
        mode: FileMode.append,
      );
    } catch (_) {}
    debugPrint(msg);
  }
}
