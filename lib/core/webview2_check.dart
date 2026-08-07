import 'dart:io';

import 'package:flutter/foundation.dart';

/// Windows 端 WebView2 Runtime 可用性检测（结果缓存）。
///
/// flutter_inappwebview 在 Windows 上依赖 Microsoft Edge WebView2 Runtime，
/// 系统缺失时创建 WebView 会在 native 层崩溃导致整个 App 闪退。
/// 打开内置 WebView 前调用 [available] 预检，缺失时引导用户安装。
class WebView2Check {
  WebView2Check._();

  static bool? _cached;

  /// WebView2 Evergreen Runtime 的注册表安装键（pv 值存在即已安装）。
  static const List<String> _regKeys = [
    r'HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    r'HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
  ];

  /// 是否可用。非 Windows / 检测失败时返回 true（不阻塞使用，
  /// 安装包已内置 WebView2 自动安装兜底）。
  static Future<bool> available() async {
    if (_cached != null) return _cached!;
    if (kIsWeb || !Platform.isWindows) return _cached = true;
    var ok = false;
    for (final key in _regKeys) {
      try {
        final r = await Process.run('reg', ['query', key, '/v', 'pv']);
        if (r.exitCode == 0) {
          ok = true;
          break;
        }
      } catch (_) {
        // reg 不可用（异常环境）→ 放行，避免误拦截
      }
    }
    return _cached = ok;
  }
}
