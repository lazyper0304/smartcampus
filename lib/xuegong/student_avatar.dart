import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../core/http_client.dart';
import '../main.dart';
import 'student_info_manager.dart';

/// 学生头像：优先显示已缓存的照片（photoBytes），否则显示姓氏首字占位，
/// 并在有登录会话（client）时异步拉取 ehall 学籍照片：
///   https://ehall.yibinu.edu.cn/jwapp/sys/jwpubapp/showImageBydsForZPGL.do?XH=<学号>&&ZPLX=XJZP
/// 拉取成功后会写回本地缓存，下次进入秒开显示。
class StudentAvatar extends StatefulWidget {
  final StudentInfo info;

  /// 登录会话客户端（携带 ehall cookie）；null 时不发起学籍照片拉取
  final SharedHttpClient? client;

  /// 尺寸缩放（设置页卡片自适应）
  final double scale;

  /// 圆角半径
  final double radius;

  /// 姓氏占位字号
  final double fontSize;

  const StudentAvatar({
    super.key,
    required this.info,
    this.client,
    this.scale = 1.0,
    this.radius = 12,
    this.fontSize = 28,
  });

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  /// 异步拉取到的学籍照片（null = 未拉取/失败）
  Uint8List? _fetched;

  @override
  void initState() {
    super.initState();
    final info = widget.info;
    // 早期 bug：登录页 HTML 曾被当照片写入缓存（hasPhoto=true 且非图片）
    // → 清掉脏缓存并重新拉取，否则会一直跳过拉取
    final cacheCorrupt = info.hasPhoto && !_looksLikeImage(info.photoBytes);
    if (cacheCorrupt) {
      unawaited(
        StudentInfoManager.saveInfo(info.copyWith(photoBytes: [])),
      );
    }
    if ((!info.hasPhoto || cacheCorrupt) && widget.client != null) {
      _fetchXjzp();
    }
  }

  Future<void> _fetchXjzp() async {
    final client = widget.client;
    final studentId = widget.info.studentId;
    if (client == null || studentId.isEmpty) return;
    try {
      // 1. CAS 会话预热：照片接口无有效会话会 302 → 登录页（返回 HTML）。
      //    authserver TGC 空闲约 30 分钟即过期，先探测/静默重登保证 CAS 会话新鲜
      if (client.hasCastgc()) {
        try {
          await AuthService(sharedClient: client).ensureFreshSession();
        } catch (_) {}
      }
      // 2. jwapp 网关会话预热：照片接口位于 /jwapp/ 下，浏览器请求携带
      //    `_WEU`（path=/jwapp/）才返回 200 图片；该 cookie 由 ehall 应用
      //    入口链（appMultiGroupEntranceList → 带 gid_ 的 targetUrl）下发
      await _ensureJwappSession(client);
      // 3. 拉取学籍照片：手动跟随重定向链（Dart 自动跟随会丢弃中间响应的
      //    Set-Cookie，ehall 在 SSO 回跳时下发的 JSESSIONID/MOD_AUTH_CAS 会丢，
      //    导致最终请求仍无有效会话 → 拿到登录页 HTML）
      final uri = Uri.parse(
        'https://ehall.yibinu.edu.cn/jwapp/sys/jwpubapp/'
        'showImageBydsForZPGL.do?XH=$studentId&ZPLX=XJZP',
      );
      final bytes = await _getImageFollowingRedirects(client, uri);
      // 4. 仅接受真实图片（登录页 HTML / 错误页不缓存，避免"粘性坏缓存"）
      if (bytes == null || bytes.isEmpty || !_looksLikeImage(bytes)) return;
      if (!mounted) return;
      setState(() => _fetched = Uint8List.fromList(bytes));
      // 写回本地缓存，下次进入直接显示照片
      await StudentInfoManager.saveInfo(
        widget.info.copyWith(photoBytes: bytes),
      );
    } catch (e) {
      debugPrint('学籍照片拉取失败: $e');
    }
  }

  /// 走 ehall 应用入口链建立 jwapp 网关会话（`_WEU`）。
  /// appId 任意 jwapp 应用均可（`_WEU` 是整站网关 cookie，path=/jwapp/）。
  Future<void> _ensureJwappSession(SharedHttpClient client) async {
    const base = 'https://ehall.yibinu.edu.cn';
    const host = 'ehall.yibinu.edu.cn';
    const htmlHeaders = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      'Host': host,
      'Upgrade-Insecure-Requests': '1',
    };
    try {
      // 应用入口分组列表 → GET 返回的 targetUrl（带 gid_）建立网关会话
      final resp = await client.get(
        Uri.parse('$base/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=4766960573884517&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer': '$base/new/index.html',
          'X-Requested-With': 'XMLHttpRequest',
        },
        noRedirect: true,
      );
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final groupList = (j['data'] as Map?)?['groupList'];
        if (groupList is List && groupList.isNotEmpty) {
          final targetUrl = (groupList[0] as Map?)?['targetUrl']?.toString();
          if (targetUrl != null && targetUrl.isNotEmpty) {
            await _warmUrl(client, Uri.parse(targetUrl), htmlHeaders);
          }
        }
      }
      // 门户 + 照片模块首页兜底
      await _warmUrl(client, Uri.parse('$base/new/index.html'), htmlHeaders);
      await _warmUrl(
          client, Uri.parse('$base/jwapp/sys/jwpubapp/*default/index.do'), htmlHeaders);
    } catch (e) {
      debugPrint('jwapp 会话预热失败: $e');
    }
  }

  /// GET 并手动跟随重定向链（每跳独立捕获 Set-Cookie）
  Future<void> _warmUrl(
      SharedHttpClient client, Uri uri, Map<String, String> headers) async {
    try {
      var r = await client.get(uri, headers: headers, noRedirect: true);
      var hops = 0;
      while ((r.statusCode == 301 || r.statusCode == 302 ||
              r.statusCode == 303) &&
          hops < 8) {
        hops++;
        final loc = r.header('location');
        if (loc == null || loc.isEmpty) break;
        r = await client.get(Uri.parse(loc),
            headers: headers, noRedirect: true);
      }
    } catch (_) {}
  }

  /// 拉取图片字节：手动跟随重定向，最终 200 时返回字节（图片校验由调用方做）
  Future<List<int>?> _getImageFollowingRedirects(
      SharedHttpClient client, Uri uri) async {
    const imgHeaders = {
      'Referer':
          'https://ehall.yibinu.edu.cn/jwapp/sys/jwpubapp/*default/index.do',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };
    var current = uri;
    for (var hop = 0; hop < 8; hop++) {
      final resp = await client.getRaw(current, headers: imgHeaders, noRedirect: true);
      final code = resp.statusCode;
      if (code >= 300 && code < 400) {
        final loc = resp.headers?.value('location');
        if (loc == null || loc.isEmpty) return null;
        current = Uri.parse(loc.startsWith('http') ? loc : current.resolve(loc).toString());
        continue;
      }
      return code == 200 ? resp.bodyBytes : null;
    }
    return null;
  }

  /// 校验响应为常见图片格式（JPEG/PNG/GIF/WebP/BMP），
  /// 防止 302 跟随重定向拿到的登录页 HTML 被当照片缓存。
  static bool _looksLikeImage(List<int> b) {
    if (b.length < 12) return false;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true; // JPEG
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true; // PNG
    }
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true; // GIF
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return true; // WebP
    }
    if (b[0] == 0x42 && b[1] == 0x4D) return true; // BMP
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final bytes = info.hasPhoto
        ? Uint8List.fromList(info.photoBytes)
        : _fetched;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          // 照片解码失败时回退姓氏占位
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final accent = accentColorNotifier.value;
    return Container(
      color: accent.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          widget.info.name.isNotEmpty ? widget.info.name[0] : '?',
          style: TextStyle(
            fontSize: widget.fontSize * widget.scale,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
      ),
    );
  }
}
