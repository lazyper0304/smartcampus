import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Windows 端 zju-connect 内核管理。
///
/// 首次使用时从 GitHub Releases 下载 windows-amd64 内核（约 5MB，
/// 依次尝试直连与国内镜像加速），解压到应用支持目录后以子进程方式
/// 运行：本地 SOCKS5 127.0.0.1:1080 / HTTP 127.0.0.1:1081 代理。
class VpnWindowsCore {
  VpnWindowsCore._();
  static final VpnWindowsCore instance = VpnWindowsCore._();

  static const _version = 'v1.3.0';
  static const _downloadUrl =
      'https://github.com/Mythologyli/zju-connect/releases/download/'
      '$_version/zju-connect-windows-amd64.zip';
  static const _mirrors = [
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
  ];

  Process? _process;
  bool _starting = false;

  bool get isRunning => _process != null;

  /// 内核可执行文件所在目录
  Future<Directory> _coreDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}vpn_core')
        .create(recursive: true);
  }

  Future<String> _exePath() async {
    final dir = await _coreDir();
    return '${dir.path}${Platform.pathSeparator}zju-connect.exe';
  }

  /// 确保内核已下载；返回 exe 路径。下载失败抛异常。
  Future<String> ensureCore() async {
    final exe = await _exePath();
    if (File(exe).existsSync()) return exe;

    final dir = await _coreDir();
    final zipPath = '${dir.path}${Platform.pathSeparator}zju-connect.zip';
    final zipFile = File(zipPath);

    // 直连 + 镜像逐个尝试
    final urls = [_downloadUrl, ..._mirrors.map((m) => '$m$_downloadUrl')];
    Object? lastError;
    for (final url in urls) {
      try {
        final resp = await http.get(Uri.parse(url)).timeout(
              const Duration(minutes: 5),
            );
        if (resp.statusCode == 200 && resp.bodyBytes.length > 1024 * 1024) {
          await zipFile.writeAsBytes(resp.bodyBytes, flush: true);
          lastError = null;
          break;
        }
        lastError = 'HTTP ${resp.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null || !zipFile.existsSync()) {
      throw Exception('下载 VPN 内核失败：$lastError');
    }

    // Windows 10+ 自带 tar.exe 可解压 zip，无需额外依赖
    final tar = await Process.run(
      'tar',
      ['-xf', zipPath, '-C', dir.path],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (tar.exitCode != 0 || !File(exe).existsSync()) {
      throw Exception('解压 VPN 内核失败：${tar.stderr}');
    }
    await zipFile.delete();
    return exe;
  }

  /// 启动内核子进程并等待本地代理端口就绪。
  ///
  /// [onProgress] 用于向 UI 反馈「下载内核中」等中间状态。
  Future<bool> start({
    required String server,
    required String username,
    required String password,
    void Function(String message)? onProgress,
  }) async {
    if (_starting) return false;
    if (isRunning) return true;
    _starting = true;

    try {
      String exe;
      try {
        exe = await ensureCore();
      } catch (e) {
        onProgress?.call('VPN 内核下载失败，请检查网络后重试');
        return false;
      }

      final dir = await _coreDir();
      final uri = Uri.parse(server);

      // 认证阶段可能需要数十秒（选路 + 登录），进程存活即认为启动成功；
      // 真正的连通性由 SOCKS 端口探测确认
      _process = await Process.start(
        exe,
        [
          '-server', uri.host,
          '-port', '${uri.port == 0 ? 443 : uri.port}',
          '-username', username,
          '-password', password,
          '-socks-bind', '127.0.0.1:1080',
          '-http-bind', '127.0.0.1:1081',
          '-disable-zju-config',
          '-disable-multi-line',
        ],
        workingDirectory: dir.path,
      );

      var gotError = '';
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          onProgress?.call(line);
          if (line.contains('Login failed') ||
              line.toLowerCase().contains('auth failed')) {
            gotError = line;
          }
        },
      );
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(onProgress);

      // 监听退出：异常退出时清空句柄
      unawaited(_process!.exitCode.then((code) {
        _process = null;
        onProgress?.call('VPN 内核已退出（exit $code）${gotError.isEmpty ? '' : '：$gotError'}');
      }));

      // 探测 SOCKS5 端口就绪（最长 30s）
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (_process == null) return false; // 进程已退出
        if (gotError.isNotEmpty) return false;
        if (await _probePort(1080)) return true;
      }
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<bool> _probePort(int port) async {
    try {
      final sock = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(milliseconds: 400));
      sock.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 停止内核进程
  Future<void> stop() async {
    _process?.kill();
    _process = null;
  }
}
