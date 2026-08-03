import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../core/http_client.dart';
import 'kccx.dart';

/// 课程查询（kccx）服务
///
/// 对应 ehall jwapp 应用「课程查询」（入口 thirdAppIndexShell.html，无 appId）：
/// - [ensureSession]：GET ehall 门户 + kccx 首页预热模块会话
/// - [fetchCourses]：课程信息列表查询（kcxxcx.do，条件搜索 + 分页）
/// - [fetchCourseDetail]：课程详情（initKcdg.do，按课程号）
///
/// ⚠️ ehall 网关（rump/e）对 kccx 业务 POST 校验 `_WEU` 会话 cookie，
/// 缺失/失效时返回 403（实测无 _WEU 必 403；Referer 的 gid_ 无影响）。
/// `_WEU` 只能通过有效 ehall 登录链获得，故本服务在 403 时自动重登
/// （[AuthService.autoRelogin]）刷新会话后重试一次（scjx2 同款模式）。
class KccxService {
  final SharedHttpClient client;
  final String baseUrl;

  KccxService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  String get _host => Uri.parse(baseUrl).host;

  // ==================== 会话预热 ====================

  /// 访问 ehall 应用入口链 + 门户 + kccx 首页，建立/刷新模块级会话
  ///
  /// - ehall 网关会话 `_WEU` 由**应用入口链**（appMultiGroupEntranceList →
  ///   带 gid_ 的 targetUrl）建立；`gid_` 是**会话级**标识（实测不同应用
  ///   返回的 gid_ 相同），任意有效 appId 均可（kcbcx 全校课表已验证此链）。
  /// - 手动跟随重定向（noRedirect + 逐跳 GET），确保重定向链中间响应的
  ///   Set-Cookie 都被 [SharedHttpClient] 捕获——Dart HttpClient 自动跟随
  ///   重定向时会丢弃中间响应的 Set-Cookie。
  Future<void> ensureSession() async {
    final host = _host;
    final htmlHeaders = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      'Host': host,
      'Upgrade-Insecure-Requests': '1',
    };
    await _warmEntranceList();
    await _warmUrl(Uri.parse('$baseUrl/new/index.html'), htmlHeaders);
    await _warmUrl(Uri.parse('$baseUrl/jwapp/sys/kccx/*default/index.do'),
        htmlHeaders);
  }

  /// 走 ehall 应用入口分组列表，GET 返回的 targetUrl（带 gid_）建立网关会话
  Future<void> _warmEntranceList() async {
    final host = _host;
    try {
      final resp = await client.get(
        Uri.parse('$baseUrl/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=4766960573884517&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer': '$baseUrl/new/index.html',
          'X-Requested-With': 'XMLHttpRequest',
        },
        noRedirect: true,
      );
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = j['data'];
        if (data is Map) {
          final gl = data['groupList'];
          if (gl is List && gl.isNotEmpty) {
            final first = gl[0];
            if (first is Map) {
              final targetUrl = first['targetUrl']?.toString();
              if (targetUrl != null && targetUrl.isNotEmpty) {
                await _warmUrl(Uri.parse(targetUrl), {
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
                  'Host': host,
                  'Upgrade-Insecure-Requests': '1',
                });
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  /// GET 单个 URL 并手动跟随重定向链（每跳独立捕获 Set-Cookie）
  Future<void> _warmUrl(Uri uri, Map<String, String> headers) async {
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

  // ==================== 课程查询 ====================

  /// 查询课程信息（kcxxcx.do）
  ///
  /// - [kcm]：课程名（包含匹配，留空不筛选）
  /// - [kch]：课程号（包含匹配，留空不筛选）
  /// - [kslxdm]：考试类型代码（"1"=考试、"2"=考查，留空不筛选）
  /// - [kcccdm]：课程层次代码（如 "01"=本科，留空不筛选）
  /// - [onlyEnabled]：仅查询启用状态的课程（KCZTDM=1，默认 true，
  ///   与网页端默认行为一致）
  Future<KccxPageResult> fetchCourses({
    String kcm = '',
    String kch = '',
    String kslxdm = '',
    String kcccdm = '',
    bool onlyEnabled = true,
    int pageSize = 20,
    int pageNumber = 1,
    int retryCount = 0,
  }) async {
    await ensureSession();
    final host = _host;

    final conditions = <Map<String, String>>[
      if (kcm.isNotEmpty)
        {
          'name': 'KCM',
          'caption': '课程名',
          'builder': 'include',
          'linkOpt': 'AND',
          'value': kcm,
        },
      if (kch.isNotEmpty)
        {
          'name': 'KCH',
          'caption': '课程号',
          'builder': 'include',
          'linkOpt': 'AND',
          'value': kch,
        },
      if (kslxdm.isNotEmpty)
        {
          'name': 'KSLXDM',
          'caption': '考试类型',
          'builder': 'equal',
          'linkOpt': 'AND',
          'value': kslxdm,
        },
      if (kcccdm.isNotEmpty)
        {
          'name': 'KCCCDM',
          'caption': '课程层次',
          'builder': 'equal',
          'linkOpt': 'AND',
          'value': kcccdm,
        },
    ];

    final body = <String, String>{
      if (onlyEnabled) 'KCZTDM': '1',
      if (conditions.isNotEmpty) 'querySetting': jsonEncode(conditions),
      'pageSize': pageSize.toString(),
      'pageNumber': pageNumber.toString(),
    };

    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/kccx/modules/kccx/kcxxcx.do'),
      body: body,
      headers: _formHeaders(host),
      noRedirect: true,
    );
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode == 403) {
      // ehall 网关 _WEU 会话失效：自动重登刷新会话后重试一次
      if (retryCount < 1 && await _tryAutoRelogin()) {
        return fetchCourses(
          kcm: kcm,
          kch: kch,
          kslxdm: kslxdm,
          kcccdm: kcccdm,
          onlyEnabled: onlyEnabled,
          pageSize: pageSize,
          pageNumber: pageNumber,
          retryCount: retryCount + 1,
        );
      }
      throw Exception('登录已过期，请重新登录后重试（403）');
    }
    if (resp.statusCode != 200) {
      throw Exception('查询课程失败：HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误：${json['code']}');
    }
    final datas = json['datas'];
    if (datas is! Map) {
      return KccxPageResult(
          rows: const [], totalSize: 0, pageNumber: pageNumber, pageSize: pageSize);
    }
    final module = datas['kcxxcx'];
    if (module is! Map) {
      return KccxPageResult(
          rows: const [], totalSize: 0, pageNumber: pageNumber, pageSize: pageSize);
    }
    final rows = module['rows'];
    final courses = rows is List
        ? rows.map((r) => KccxCourse.fromJson(r as Map<String, dynamic>)).toList()
        : <KccxCourse>[];
    return KccxPageResult(
      rows: courses,
      totalSize: int.tryParse(module['totalSize']?.toString() ?? '') ?? 0,
      pageNumber: int.tryParse(module['pageNumber']?.toString() ?? '') ?? pageNumber,
      pageSize: int.tryParse(module['pageSize']?.toString() ?? '') ?? pageSize,
    );
  }

  // ==================== 课程详情 ====================

  /// 查询课程详细信息（initKcdg.do，按课程号 KCH）
  ///
  /// 响应为课程对象本身（无 datas/code 包装），字段与列表一致并更完整。
  Future<KccxCourse> fetchCourseDetail(String kch,
      {int retryCount = 0}) async {
    await ensureSession();
    final host = _host;

    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/kccx/kcxq/initKcdg.do'),
      body: {'KCH': kch},
      headers: _formHeaders(host),
      noRedirect: true,
    );
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode == 403) {
      if (retryCount < 1 && await _tryAutoRelogin()) {
        return fetchCourseDetail(kch, retryCount: retryCount + 1);
      }
      throw Exception('登录已过期，请重新登录后重试（403）');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取课程详情失败：HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body);
    if (json is! Map<String, dynamic>) {
      throw Exception('课程详情数据异常');
    }
    return KccxCourse.fromJson(json);
  }

  // ==================== 内部工具 ====================

  /// 用已存账号密码自动重登刷新 ehall 会话（记住密码时才生效）
  Future<bool> _tryAutoRelogin() async {
    _debugPrintCookies('before relogin');
    try {
      final auth = AuthService(sharedClient: client);
      if (await auth.autoRelogin()) {
        await ensureSession();
        _debugPrintCookies('after relogin');
        return true;
      }
    } catch (e) {
      debugPrint('Kccx: autoRelogin on 403 failed: $e');
    }
    return false;
  }

  /// 打印当前 SharedHttpClient 各域 cookie 名（调试 403 用）
  void _debugPrintCookies(String tag) {
    try {
      final all = client.getAllCookies();
      debugPrint('Kccx: cookies($tag):');
      for (final e in all.entries) {
        debugPrint('  ${e.key}: ${e.value.keys.toList().join(", ")}');
      }
    } catch (_) {}
  }

  /// kccx 模块表单请求头（Referer 指向 kccx 首页）
  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/kccx/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}
