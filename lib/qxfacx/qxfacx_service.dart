import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../core/http_client.dart';
import 'qxfacx.dart';

/// 全校方案查询（qxfacx / 培养方案查询）服务
///
/// 对应 ehall jwapp 应用「全校方案查询」（入口 appShow?appId=4766860087431764）：
/// - [ensureSession]：走应用入口链（appMultiGroupEntranceList）建立 `_WEU`
///   网关会话 + GET qxfacx 首页预热
/// - [fetchPlans]：培养方案列表（qxpyfacx.do，默认过滤已发布 FAZTDM=99，
///   支持方案名包含搜索 + 分页）
///
/// ⚠️ ehall 网关（rump/e）对业务 POST 校验 `_WEU` 会话 cookie（同 kccx），
/// 缺失/失效返回 403；`_WEU` 只能通过有效 ehall 登录链获得，403 时自动重登
/// （[AuthService.autoRelogin]）刷新会话后重试一次。
class QxFacxService {
  final SharedHttpClient client;
  final String baseUrl;

  /// 全校方案查询应用 ID（appShow?appId=4766860087431764）
  static const String appId = '4766860087431764';

  /// 已发布方案状态码（FAZTDM，网页端默认过滤条件）
  static const String faStatePublished = '99';

  QxFacxService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  String get _host => Uri.parse(baseUrl).host;

  // ==================== 会话预热 ====================

  /// 访问 ehall 应用入口链 + 门户 + qxfacx 首页，建立/刷新模块级会话
  ///
  /// `_WEU` 网关会话由应用入口链（appMultiGroupEntranceList → 带 gid_ 的
  /// targetUrl）建立；手动跟随重定向（noRedirect + 逐跳 GET）确保中间响应的
  /// Set-Cookie 都被 [SharedHttpClient] 捕获（Dart 自动跟随会丢弃中间 Set-Cookie）。
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
    await _warmUrl(Uri.parse('$baseUrl/jwapp/sys/qxfacx/*default/index.do'),
        htmlHeaders);
  }

  /// 走 ehall 应用入口分组列表，GET 返回的 targetUrl（带 gid_）建立网关会话
  Future<void> _warmEntranceList() async {
    final host = _host;
    try {
      final resp = await client.get(
        Uri.parse('$baseUrl/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=$appId&param='),
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

  // ==================== 培养方案查询 ====================

  /// 查询培养方案列表（qxpyfacx.do）
  ///
  /// - [njd]：年级代码过滤（如 "2026" = 2026级，留空不筛选；与网页端
  ///   「点击年级分类」一致，条件插在 querySetting 首位）
  /// - [nameQuery]：方案名称包含匹配（PYFAMC include，留空不筛选）
  /// - [onlyPublished]：仅查已发布方案（FAZTDM=99，默认 true，与网页端一致）
  /// - 排序与网页端一致：`*order=-NJDM,+DWDM,+ZYDM`（年级倒序、院系、专业）
  Future<QxFacxPageResult> fetchPlans({
    String njd = '',
    String nameQuery = '',
    bool onlyPublished = true,
    int pageSize = 20,
    int pageNumber = 1,
    int retryCount = 0,
  }) async {
    await ensureSession();
    final host = _host;

    // 条件顺序与网页端一致：NJDM（年级）→ FAZTDM（已发布）→ PYFAMC（名称搜索）
    final conditions = <Map<String, String>>[
      if (njd.trim().isNotEmpty)
        {
          'name': 'NJDM',
          'caption': '年级',
          'linkOpt': 'AND',
          'builderList': 'cbl_String',
          'builder': 'equal',
          'value': njd.trim(),
          'value_display': '${njd.trim()}级',
        },
      if (onlyPublished)
        {
          'name': 'FAZTDM',
          'caption': '',
          'builder': 'equal',
          'linkOpt': 'AND',
          'value': faStatePublished,
        },
      if (nameQuery.trim().isNotEmpty)
        {
          'name': 'PYFAMC',
          'caption': '培养方案名称',
          'builder': 'include',
          'linkOpt': 'AND',
          'value': nameQuery.trim(),
        },
    ];

    final body = <String, String>{
      if (conditions.isNotEmpty) 'querySetting': jsonEncode(conditions),
      '*order': '-NJDM,+DWDM,+ZYDM',
      'pageSize': pageSize.toString(),
      'pageNumber': pageNumber.toString(),
    };

    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/qxfacx/modules/pyfacxepg/qxpyfacx.do'),
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
        return fetchPlans(
          njd: njd,
          nameQuery: nameQuery,
          onlyPublished: onlyPublished,
          pageSize: pageSize,
          pageNumber: pageNumber,
          retryCount: retryCount + 1,
        );
      }
      throw Exception('登录已过期，请重新登录后重试（403）');
    }
    if (resp.statusCode != 200) {
      throw Exception('查询培养方案失败：HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误：${json['code']}');
    }
    final datas = json['datas'];
    if (datas is! Map) {
      return const QxFacxPageResult(
          rows: [], totalSize: 0, pageNumber: 1, pageSize: 20);
    }
    final module = datas['qxpyfacx'];
    if (module is! Map) {
      return const QxFacxPageResult(
          rows: [], totalSize: 0, pageNumber: 1, pageSize: 20);
    }
    final rows = module['rows'];
    final plans = rows is List
        ? rows.map((r) => QxFacxPlan.fromJson(r as Map<String, dynamic>)).toList()
        : <QxFacxPlan>[];
    return QxFacxPageResult(
      rows: plans,
      totalSize: int.tryParse(module['totalSize']?.toString() ?? '') ?? 0,
      pageNumber:
          int.tryParse(module['pageNumber']?.toString() ?? '') ?? pageNumber,
      pageSize: int.tryParse(module['pageSize']?.toString() ?? '') ?? pageSize,
    );
  }

  // ==================== 课程组 / 课组课程（详情） ====================

  /// 查询培养方案下的课程组（kzcx.do，按方案代码 PYFADM）
  ///
  /// 返回全部课程组/平台（含层级：FKZH=-1 顶级平台，子组 FKZH=父组 KZH）。
  Future<List<QxFacxKz>> fetchKzcx(String pyfadm, {int retryCount = 0}) async {
    await ensureSession();
    final host = _host;
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/qxfacx/modules/pyfacxepg/kzcx.do'),
      body: {'PYFADM': pyfadm},
      headers: _formHeaders(host),
      noRedirect: true,
    );
    return _parseRows<QxFacxKz>(
      resp,
      'kzcx',
      QxFacxKz.fromJson,
      retryCount: retryCount,
      onRetry: () => fetchKzcx(pyfadm, retryCount: retryCount + 1),
      apiLabel: '课程组',
    );
  }

  /// 查询培养方案下的全部课组课程（kzkccx.do，按方案代码 PYFADM）
  Future<List<QxFacxKzCourse>> fetchKzkccx(String pyfadm,
      {int retryCount = 0}) async {
    await ensureSession();
    final host = _host;
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/qxfacx/modules/pyfacxepg/kzkccx.do'),
      body: {'PYFADM': pyfadm},
      headers: _formHeaders(host),
      noRedirect: true,
    );
    return _parseRows<QxFacxKzCourse>(
      resp,
      'kzkccx',
      QxFacxKzCourse.fromJson,
      retryCount: retryCount,
      onRetry: () => fetchKzkccx(pyfadm, retryCount: retryCount + 1),
      apiLabel: '课组课程',
    );
  }

  /// 通用列表解析：302 会话过期 / 403 重登重试 / 200 解析 `datas[module].rows`
  Future<List<T>> _parseRows<T>(
    dynamic resp,
    String module,
    T Function(Map<String, dynamic>) fromJson, {
    required int retryCount,
    required Future<List<T>> Function() onRetry,
    required String apiLabel,
  }) async {
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode == 403) {
      if (retryCount < 1 && await _tryAutoRelogin()) {
        return onRetry();
      }
      throw Exception('登录已过期，请重新登录后重试（403）');
    }
    if (resp.statusCode != 200) {
      throw Exception('查询$apiLabel失败：HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误：${json['code']}');
    }
    final datas = json['datas'];
    if (datas is! Map) return <T>[];
    final m = datas[module];
    if (m is! Map) return <T>[];
    final rows = m['rows'];
    return rows is List
        ? rows.map((r) => fromJson(r as Map<String, dynamic>)).toList()
        : <T>[];
  }

  // ==================== 内部工具 ====================

  /// 用已存账号密码自动重登刷新 ehall 会话
  Future<bool> _tryAutoRelogin() async {
    try {
      final auth = AuthService(sharedClient: client);
      if (await auth.autoRelogin()) {
        await ensureSession();
        return true;
      }
    } catch (e) {
      debugPrint('QxFacx: autoRelogin on 403 failed: $e');
    }
    return false;
  }

  /// qxfacx 模块表单请求头（Referer 指向 qxfacx 首页）
  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/qxfacx/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}
