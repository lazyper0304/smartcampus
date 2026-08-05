import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../core/http_client.dart';
import 'wspj.dart';

/// 网上评教（wspj / jwwspj）服务
///
/// 对应 ehall jwapp 应用「网上评教」（入口 appShow?appId=5077744448763966）：
/// - [ensureSession]：走应用入口链（appMultiGroupEntranceList）建立 `_WEU`
///   网关会话 + GET jwwspj 首页预热
/// - [fetchModules]：评教模块列表（emappagelog/config/jwwspj.do）
/// - [fetchConfig]：评教系统参数（cxcssz.do，评教时间窗口等）
/// - [fetchSemesters]：学年学期查询（xnxqcx.do）
/// - [fetchQuestionnaires]：学生评教问卷列表（cxxspjwjlb.do）
///
/// ⚠️ ehall 网关（rump/e）对业务 POST 校验 `_WEU` 会话 cookie（同 kccx /
/// qxfacx），缺失/失效返回 403；`_WEU` 只能通过有效 ehall 登录链获得，
/// 403 时自动重登（[AuthService.autoRelogin]）刷新会话后重试一次。
class WspjService {
  final SharedHttpClient client;
  final String baseUrl;

  /// 网上评教应用 ID（appShow?appId=5077744448763966）
  static const String appId = '5077744448763966';

  WspjService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  String get _host => Uri.parse(baseUrl).host;

  // ==================== 会话预热 ====================

  /// 访问 ehall 应用入口链 + 门户 + jwwspj 首页，建立/刷新模块级会话
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
    await _warmUrl(Uri.parse('$baseUrl/jwapp/sys/jwwspj/*default/index.do'),
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

  // ==================== 评教模块列表 ====================

  /// 查询网上评教模块列表（config/jwwspj.do）
  ///
  /// 返回学生评教（pj）、评教历史查看（pjls）、教师评教（jspj）等模块，
  /// 该响应是**裸数组**（无 datas/code 包装）。
  Future<List<WspjModule>> fetchModules({int retryCount = 0}) async {
    await ensureSession();
    final host = _host;
    final resp = await client.get(
      Uri.parse('$baseUrl/jwapp/sys/emappagelog/config/jwwspj.do'),
      headers: {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': baseUrl,
        'Referer': '$baseUrl/jwapp/sys/jwwspj/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      },
      noRedirect: true,
    );
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode == 403) {
      if (retryCount < 1 && await _tryAutoRelogin()) {
        return fetchModules(retryCount: retryCount + 1);
      }
      throw Exception('登录已过期，请重新登录后重试（403）');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取评教模块失败：HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return <WspjModule>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WspjModule.fromJson)
        .toList();
  }

  // ==================== 评教系统参数 ====================

  /// 查询评教管理系统参数（cxcssz.do）
  ///
  /// 与网页端一致的条件：CSDM=PJGLPJSJ（评教管理评教设置）+
  /// ZCSDM 多值（PJXNXQ 当前学期 / PJKSSJ 开始 / PJJSSJ 结束 /
  /// XSSFKXG 提交后可否修改 / ZGPJSFBT 主观题必填 / SFSY 是否使用 /
  /// XSFS 学生分数 / XSBL 学生比例 / DZTBL 点赞题比例 / TMXZ 题目限制）。
  Future<List<WspjConfigItem>> fetchConfig({int retryCount = 0}) async {
    await ensureSession();
    final host = _host;
    final setting = jsonEncode([
      {
        'name': 'CSDM',
        'value': 'PJGLPJSJ',
        'builder': 'equal',
        'linkOpt': 'AND',
      },
      {
        'name': 'ZCSDM',
        'value': 'PJXNXQ,PJKSSJ,PJJSSJ,XSSFKXG,ZGPJSFBT,SFSY,XSFS,XSBL,DZTBL,TMXZ',
        'builder': 'm_value_equal',
        'linkOpt': 'AND',
      },
    ]);
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwwspj/modules/pj/cxcssz.do'),
      body: {'setting': setting},
      headers: _formHeaders(host),
      noRedirect: true,
    );
    return _parseRows<WspjConfigItem>(
      resp,
      'cxcssz',
      WspjConfigItem.fromJson,
      retryCount: retryCount,
      onRetry: () => fetchConfig(retryCount: retryCount + 1),
      apiLabel: '评教系统参数',
    );
  }

  // ==================== 学年学期 ====================

  /// 查询学年学期（xnxqcx.do）
  ///
  /// 网页端按 DM（如 "2025-2026-2"）查询单条；留空时服务端返回全部学期，
  /// 用于学期切换。
  Future<List<WspjSemester>> fetchSemesters({String? dm, int retryCount = 0}) async {
    await ensureSession();
    final host = _host;
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwwspj/modules/pj/xnxqcx.do'),
      body: {if (dm != null && dm.isNotEmpty) 'DM': dm},
      headers: _formHeaders(host),
      noRedirect: true,
    );
    return _parseRows<WspjSemester>(
      resp,
      'xnxqcx',
      WspjSemester.fromJson,
      retryCount: retryCount,
      onRetry: () => fetchSemesters(dm: dm, retryCount: retryCount + 1),
      apiLabel: '学年学期',
    );
  }

  // ==================== 学生评教问卷列表 ====================

  /// 查询学生评教问卷列表（cxxspjwjlb.do）
  ///
  /// - [cpr]：评教学号（学生本人学号，来自登录账号）
  /// - [xnxqdm]：学年学期代码（如 "2025-2026-2"）
  /// - [sffb]：是否已发布（网页端固定传 1）
  Future<List<WspjQuestionnaire>> fetchQuestionnaires({
    required String cpr,
    required String xnxqdm,
    String sffb = '1',
    int retryCount = 0,
  }) async {
    await ensureSession();
    final host = _host;
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwwspj/modules/pj/cxxspjwjlb.do'),
      body: {
        'CPR': cpr,
        'XNXQDM': xnxqdm,
        'SFFB': sffb,
      },
      headers: _formHeaders(host),
      noRedirect: true,
    );
    return _parseRows<WspjQuestionnaire>(
      resp,
      'cxxspjwjlb',
      WspjQuestionnaire.fromJson,
      retryCount: retryCount,
      onRetry: () => fetchQuestionnaires(
        cpr: cpr,
        xnxqdm: xnxqdm,
        sffb: sffb,
        retryCount: retryCount + 1,
      ),
      apiLabel: '学生评教问卷',
    );
  }

  // ==================== 通用解析 ====================

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
      debugPrint('Wspj: autoRelogin on 403 failed: $e');
    }
    return false;
  }

  /// wspj 模块表单请求头（Referer 指向 jwwspj 首页）
  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': baseUrl,
        'Referer': '$baseUrl/jwapp/sys/jwwspj/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}
