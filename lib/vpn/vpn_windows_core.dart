import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Windows 端 zju-connect 内核管理。
///
/// 内核为 yibinu fork（分支 yibinu-captcha）本地构建的 windows-amd64 exe，
/// 与 android/app/libs 的 AAR 同构：直接随仓库/安装包分发，不做运行时下载。
/// fork 相对上游补丁：
/// - `-captcha-stdio`：学校强制图形验证码（RndImg=1）时经 stdin/stdout
///   行协议 `@CAPTCHA:<base64>` / `@CAPTCHA_ANSWER:<text>` 交互；
/// - `-force-ipv4`：双栈解析下隧道 TLS 握手锁定 IPv4（本机 IPv6 直连被拒）。
/// 本地暴露 SOCKS5 127.0.0.1:1080 / HTTP 127.0.0.1:1081 代理。
class VpnWindowsCore {
  VpnWindowsCore._();
  static final VpnWindowsCore instance = VpnWindowsCore._();

  static const _version = 'yibinu-v1.3.0';

  Process? _process;
  bool _starting = false;
  IOSink? _stdin;
  Timer? _stdinDrain;
  final List<String> _pendingAnswers = [];

  bool get isRunning => _process != null;

  /// 内核 exe 路径：与应用主程序同目录（flutter run / Release 构建均成立），
  /// 兜底回退应用支持目录。
  Future<String> _exePath() async {
    final besideApp = File(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}zju-connect.exe');
    if (besideApp.existsSync()) return besideApp.path;

    final support = await getApplicationSupportDirectory();
    final fallback =
        '${support.path}${Platform.pathSeparator}vpn_core'
        '${Platform.pathSeparator}zju-connect.exe';
    if (!File(fallback).existsSync()) {
      throw Exception(
          'VPN 内核缺失（版本 $_version）：$fallback 不存在。'
          '请重新安装应用或从仓库 windows/vpn_core/ 获取。');
    }
    return fallback;
  }

  /// 启动内核子进程并等待本地代理端口就绪。
  ///
  /// [onProgress] 用于向 UI 反馈内核日志与「等待验证码输入」等中间状态。
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
        exe = await _exePath();
      } catch (e) {
        onProgress?.call('VPN 内核缺失：请重新安装应用后重试');
        return false;
      }

      final dir = File(exe).parent;
      final uri = Uri.parse(server);

      // 认证阶段可能需要数十秒（选路 + 登录 + 验证码交互），进程存活即认为
      // 启动流程进行中；真正的连通性由 SOCKS 端口探测确认
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
          // yibinu fork 补丁开关：图形验证码 stdio 协议 + 隧道锁定 IPv4
          '-captcha-stdio',
          '-force-ipv4',
        ],
        workingDirectory: dir.path,
      );
      _stdin = _process!.stdin;
      _pendingAnswers.clear();

      var gotError = '';
      var inCaptcha = false;
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          onProgress?.call(line);
          if (line.startsWith('@CAPTCHA:')) {
            inCaptcha = true;
            _dispatchCaptcha(line.substring('@CAPTCHA:'.length).trim(),
                (answer) {
              _pendingAnswers.add(answer);
              _drainStdin();
            }, onProgress);
          } else if (line.contains('Login failed') ||
              line.toLowerCase().contains('auth failed') ||
              line.contains('Invalid username or password')) {
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
        _stdin = null;
        onProgress?.call('VPN 内核已退出（exit $code）${gotError.isEmpty ? '' : '：$gotError'}');
      }));

      // 探测 SOCKS5 端口就绪（验证码交互可长达数分钟）
      for (var i = 0; i < 600; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (_process == null) return false; // 进程已退出
        if (gotError.isNotEmpty) return false;
        if (inCaptcha) continue; // 等用户输入验证码，不计失败
        if (await _probePort(1080)) return true;
      }
      return false;
    } finally {
      _starting = false;
    }
  }

  /// 把验证码图片交给 UI 弹窗，用户提交后回调写回内核 stdin。
  void _dispatchCaptcha(
    String base64Image,
    void Function(String answer) onAnswer,
    void Function(String message)? onProgress,
  ) {
    onProgress?.call('等待验证码输入…');
    // captchaHandler 由 vpn_page 注入；此刻 UI 必然在页面栈内
    // （VPN 是用户主动触发的功能），fire-and-forget 异步处理。
    () async {
      try {
        final handler = VpnWindowsCoreCaptchaBridge.handler;
        if (handler == null) {
          onProgress?.call('无法展示验证码：界面未就绪');
          return;
        }
        final answer = await handler(base64Image);
        if (answer.isNotEmpty) onAnswer(answer);
      } catch (_) {
        // 用户取消：不写回，由服务端超时/重试收口
      }
    }();
  }

  /// 批量把待写应答刷入 stdin（一次一行，Scanner 端逐行读取）
  void _drainStdin() {
    if (_stdin == null) return;
    if (_stdinDrain != null) return;
    _stdinDrain = Timer(Duration.zero, () {
      _stdinDrain = null;
      while (_pendingAnswers.isNotEmpty && _stdin != null) {
        final answer = _pendingAnswers.removeAt(0);
        _stdin!.writeln('@CAPTCHA_ANSWER:$answer');
      }
    });
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
    _stdinDrain?.cancel();
    _stdinDrain = null;
    _pendingAnswers.clear();
    _stdin = null;
    _process?.kill();
    _process = null;
  }
}

/// 解耦内核与 UI 的验证码回调桥：vpn_page 启动时注入，
/// 避免本文件反向依赖页面层。
class VpnWindowsCoreCaptchaBridge {
  VpnWindowsCoreCaptchaBridge._();

  static Future<String> Function(String base64Image)? handler;
}
