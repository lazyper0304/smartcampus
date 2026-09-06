import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, ValueNotifier;
import 'package:flutter/services.dart';

import '../core/local_storage.dart';
import 'vpn_windows_core.dart';

/// VPN 连接阶段
enum VpnPhase {
  /// 未连接
  idle,

  /// 正在认证（登录 EasyConnect 服务器）
  authenticating,

  /// 认证成功，正在建立隧道（Android TUN / Windows 本地代理）
  connecting,

  /// 已连接：可访问校内资源
  connected,

  /// 正在断开
  disconnecting,
}

/// 校园 VPN 服务。
///
/// 参考 hitsz-connect-verge 的思路，协议实现采用开源的 yibinu-connect（原 zju-connect，yibinu fork）：
/// - Android：官方发布的 gomobile AAR（Login/Logout/StartStack）+ 自建
///   VpnService 建立 TUN 网卡，分流模式仅路由内网网段（10/8、172.16/12、192.168/16）。
/// - Windows：随包分发 yibinu-connect 命令行内核作为子进程运行，本地暴露
///   SOCKS5(127.0.0.1:1080)/HTTP(127.0.0.1:1081) 代理。
///
/// 接入地址 https://vpn.yibinu.edu.cn（深信服 EasyConnect），账号同学校统一身份认证。
class VpnService {
  VpnService._();

  static const MethodChannel _channel =
      MethodChannel('com.smartcampus.smartcampus/vpn');

  /// 宜宾学院 EasyConnect 接入地址
  static const String kDefaultServer = 'https://vpn.yibinu.edu.cn';

  // LocalStorage key
  static const _kServer = 'vpn_server';
  static const _kUsername = 'vpn_username';
  static const _kPassword = 'vpn_password';
  static const _kRemember = 'vpn_remember_password';

  /// 当前连接阶段（页面监听此通知器刷新）
  static final ValueNotifier<VpnPhase> phase = ValueNotifier(VpnPhase.idle);

  /// 最近一次错误信息（连接失败 / 登录失败）
  static final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// 分配到的虚拟内网 IP（连接成功后填充）
  static final ValueNotifier<String?> clientIp = ValueNotifier<String?>(null);

  static bool _handlerRegistered = false;
  static Completer<void>? _tunnelCompleter;

  /// 当前平台是否支持 VPN 功能
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// 注册原生事件回调（幂等）。仅 Android 走 MethodChannel。
  static void _ensureHandler() {
    if (_handlerRegistered || !_isAndroid) return;
    _channel.setMethodCallHandler(_onNativeEvent);
    _handlerRegistered = true;
  }

  /// 图形验证码处理器（vpn_page 注入）：展示 base64 图片并返回用户输入，
  /// 空串表示取消。Go 侧线程阻塞等待，超时 3 分钟。
  static Future<String> Function(String base64Image)? captchaHandler;

  static Future<dynamic> _onNativeEvent(MethodCall call) async {
    // Go 线程阻塞等待验证码输入
    if (call.method == 'getCaptcha') {
      final image = call.arguments as String? ?? '';
      if (captchaHandler == null) return '';
      return await captchaHandler!(image);
    }
    if (call.method != 'onVpnEvent') return null;
    final args = Map<String, dynamic>.from(call.arguments ?? const {});
    switch (args['type']) {
      case 'tunnelStarted':
        phase.value = VpnPhase.connected;
        _tunnelCompleter?.complete();
        _tunnelCompleter = null;
      case 'tunnelStopped':
        // 主动断开流程由 disconnect() 收尾；这里只兜底异常掉线
        if (phase.value == VpnPhase.connected) {
          phase.value = VpnPhase.idle;
          clientIp.value = null;
          lastError.value = '连接已断开';
        }
      case 'error':
        lastError.value =
            _mapVpnError((args['message'] as String?) ?? '未知错误');
        if (phase.value == VpnPhase.authenticating ||
            phase.value == VpnPhase.connecting) {
          phase.value = VpnPhase.idle;
          _tunnelCompleter?.completeError(const VpnException('隧道建立失败'));
          _tunnelCompleter = null;
        }
    }
    return null;
  }

  /// 把 Go 侧原始错误串映射为友好中文提示。
  /// 深信服 ErrorCode 20023 = 图形验证码错误或已过期（原始串形如
  /// `Login failed: <Auth>...<ErrorCode>20023</ErrorCode>...CAPTCHA incorrect...`）。
  static String _mapVpnError(String raw) {
    if (raw.contains('20023') ||
        raw.contains('CAPTCHA incorrect') ||
        raw.contains('characters are incorrect')) {
      return '验证码错误或已过期，请重试';
    }
    // 其余剔除 "Login failed:" 前缀与 XML 噪音，只留关键信息
    final cleaned =
        raw.replaceFirst('Login failed:', '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return cleaned.isEmpty ? raw : cleaned;
  }

  /// 读取已保存的接入配置
  static Future<
      ({String server, String username, String password, bool rememberPassword})>
      loadConfig() async {
    final server = await LocalStorage.getString(_kServer);
    final username = await LocalStorage.getString(_kUsername);
    // 未显式关闭过记住密码时默认开启，兼容旧版本已保存密码的用户
    final rememberRaw = await LocalStorage.getString(_kRemember);
    final remember = rememberRaw == null || rememberRaw == 'true';
    final password =
        remember ? await LocalStorage.getString(_kPassword) : null;
    return (
      server: (server == null || server.isEmpty) ? kDefaultServer : server,
      username: username ?? '',
      password: password ?? '',
      rememberPassword: remember,
    );
  }

  /// 更新「记住密码」开关并持久化；关闭时立即清除已存密码
  static Future<void> setRememberPassword(bool value) async {
    await LocalStorage.setBool(_kRemember, value);
    if (!value) await LocalStorage.remove(_kPassword);
  }

  /// 连接。返回是否成功建立隧道。凭据持久化到本地，下次可一键重连；
  /// [rememberPassword] 为 false 时不保存密码（并清除已存密码）。
  static Future<bool> connect({
    required String username,
    required String password,
    String? server,
    bool rememberPassword = true,
  }) async {
    if (!isSupported) return false;
    if (username.isEmpty || password.isEmpty) {
      lastError.value = '请先填写用户名和密码';
      return false;
    }
    lastError.value = null;

    await LocalStorage.setString(_kServer, server ?? kDefaultServer);
    await LocalStorage.setString(_kUsername, username);
    if (rememberPassword) {
      await LocalStorage.setString(_kPassword, password);
    } else {
      await LocalStorage.remove(_kPassword);
    }

    phase.value = VpnPhase.authenticating;

    try {
      if (_isAndroid) {
        _ensureHandler();

        // 第一步：系统 VPN 授权（未授权时弹系统对话框，await 至用户选择）
        final granted =
            await _channel.invokeMethod<bool>('prepare') ?? false;
        if (!granted) {
          phase.value = VpnPhase.idle;
          lastError.value = '未授予 VPN 权限，无法建立隧道';
          return false;
        }

        // 第二步：认证 + 隧道
        final tunnel = Completer<void>();
        _tunnelCompleter = tunnel;

        final ip = await _channel.invokeMethod<String>('connect', {
          'username': username,
          'password': password,
          'server': server ?? kDefaultServer,
          // debug 构建开启 yibinu-connect 详细日志，定位 token/IP 阶段失败点
          'debug': kDebugMode,
        });
        if (ip == null || ip.isEmpty) {
          phase.value = VpnPhase.idle;
          _tunnelCompleter = null;
          // 错误事件（含验证码错等具体原因）先于本回调到达，仅在无信息时兜底
          lastError.value ??= '登录失败：检查账号密码与校园网环境';
          return false;
        }
        clientIp.value = ip;
        phase.value = VpnPhase.connecting;
        // 隧道结果经 native 事件返回
        await tunnel.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw const VpnException('建立隧道超时'),
        );
        return true;
      } else {
        final ok = await VpnWindowsCore.instance.start(
          server: server ?? kDefaultServer,
          username: username,
          password: password,
        );
        if (!ok) {
          phase.value = VpnPhase.idle;
          lastError.value ??= 'VPN 内核启动失败';
          return false;
        }
        clientIp.value = 'SOCKS5 · 127.0.0.1:1080';
        phase.value = VpnPhase.connected;
        return true;
      }
    } on PlatformException catch (e) {
      phase.value = VpnPhase.idle;
      lastError.value = _mapVpnError(e.message ?? '连接失败');
      return false;
    } on VpnException catch (e) {
      phase.value = VpnPhase.idle;
      if (lastError.value == null) lastError.value = e.message;
      return false;
    } catch (e) {
      phase.value = VpnPhase.idle;
      lastError.value = e.toString();
      return false;
    }
  }

  /// 断开连接并注销登录
  static Future<void> disconnect() async {
    if (!isSupported) return;
    phase.value = VpnPhase.disconnecting;
    try {
      if (_isAndroid) {
        await _channel.invokeMethod('disconnect');
      } else {
        await VpnWindowsCore.instance.stop();
      }
    } on PlatformException {
      // 忽略断开异常，状态强制归位
    } finally {
      phase.value = VpnPhase.idle;
      clientIp.value = null;
    }
  }
}

/// VPN 业务异常（区别于 PlatformException，用于超时等）
class VpnException implements Exception {
  final String message;
  const VpnException(this.message);
  @override
  String toString() => message;
}
