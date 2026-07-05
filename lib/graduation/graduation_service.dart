import 'dart:convert';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'graduation.dart';

/// 学业完成情况查询服务
/// API 调用顺序（参考浏览器 DevTools）：
///   1. cxxkxnxq.do → 选课学年学期
///   2. cxdqxnxq.do → 当前学年学期
///   3. grpyfacx.do → 个人培养方案（含 PYFADM）
///   4. cxscfakz.do → 课程组完成情况（需 PYFADM）
class GraduationService {
  final SharedHttpClient client;
  final String baseUrl;

  GraduationService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  /// 获取学业完成情况（含总览 + 课程组列表）
  Future<GraduationResult> fetchResult({bool forceRefresh = false}) async {
    const cacheKey = 'graduation_result';
    if (!forceRefresh) {
      final cached = DataCache().get<GraduationResult>(cacheKey);
      if (cached != null) return cached;
    }
    final host = Uri.parse(baseUrl).host;

    // 1. 角色选择（建立 ehall HTTPS 模块 session）
    await _entranceFlow(host);

    // 2. 访问入口页
    await client.get(
      Uri.parse('$baseUrl/jwapp/sys/xywccx/*default/index.do'),
      headers: _entryHeaders(host),
    );

    // 3. 获取当前学年学期
    await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/xywccx/modules/xywccx/cxxkxnxq.do'),
      body: {},
      headers: _formHeaders(host),
    );

    // 4. 获取当前学期
    await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/xywccx/modules/xywccx/cxdqxnxq.do'),
      body: {},
      headers: _formHeaders(host),
    );

    // 5. 获取学期参数先查培养方案概要（cxxsscfa.do）
    final xnxqdm = _calcXnxqdm();
    final pyfaResp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/xywccx/modules/xywccx/cxxsscfa.do'),
      body: {'XNXQDM': xnxqdm},
      headers: _formHeaders(host),
    );
    if (pyfaResp.statusCode != 200) {
      throw Exception('获取培养方案失败：HTTP ${pyfaResp.statusCode}');
    }
    final pyfaJson = jsonDecode(pyfaResp.body) as Map<String, dynamic>;
    if (pyfaJson['code']?.toString() != '0') {
      throw Exception('培养方案返回错误：${pyfaJson['code']} ${pyfaJson['msg'] ?? ''}');
    }
    var pyfadm = '';
    var sclbdm = '';
    var bynjdm = '';
    final datas = pyfaJson['datas'];
    if (datas is Map) {
      final cxxsscfa = datas['cxxsscfa'];
      if (cxxsscfa is Map) {
        final rows = cxxsscfa['rows'];
        if (rows is List && rows.isNotEmpty) {
          final row = rows[0] as Map;
          pyfadm = row['PYFADM']?.toString() ?? '';
          sclbdm = row['SCLBDM']?.toString() ?? '';
          bynjdm = row['BYNJDM']?.toString() ?? '';
          _totalCredits = double.tryParse(row['YQXF']?.toString() ?? '0') ?? 0;
          _earnedCredits = double.tryParse(row['WCXF']?.toString() ?? '0') ?? 0;
          _pyfaName = row['PYFAMC']?.toString() ?? '';
        }
      }
    }
    if (pyfadm.isEmpty) {
      throw Exception('未获取到培养方案信息，响应：${pyfaResp.body.length > 200 ? pyfaResp.body.substring(0, 200) : pyfaResp.body}');
    }

    // 6. 查询课程组完成情况（需 PYFADM + SCLBDM + BYNJDM）
    final bodyParams = <String, String>{
      'PYFADM': pyfadm,
      '*search': 'true',
      'pageSize': '999',
      'pageNumber': '1',
    };
    if (sclbdm.isNotEmpty) bodyParams['SCLBDM'] = sclbdm;
    if (bynjdm.isNotEmpty) bodyParams['BYNJDM'] = bynjdm;
    if (bodyParams['SCLBDM'] == null) bodyParams['SCLBDM'] = '04';
    if (bodyParams['BYNJDM'] == null) bodyParams['BYNJDM'] = '-';

    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/xywccx/modules/xywccx/cxscfakz.do'),
      body: bodyParams,
      headers: _formHeaders(host),
      noRedirect: true,
    );

    if (resp.statusCode == 403) {
      throw Exception('服务器拒绝访问（403），请重新登录');
    }
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取学业数据失败：HTTP ${resp.statusCode}');
    }

    final categories = _parseResponse(resp.body);

    // 构建层级树
    final rootCategories = _buildTree(categories);

    // 构建总览
    final summary = GraduationSummary(
      planName: _pyfaName,
      totalCredits: _totalCredits,
      earnedCredits: _earnedCredits,
      studentName: _studentName,
    );

    final result = GraduationResult(summary: summary, rootCategories: rootCategories);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 将 flat list 构建为层级树（递归）
  List<GraduationCategory> _buildTree(List<GraduationCategory> all) {
    // 按 parentId 分组
    final byParent = <String, List<GraduationCategory>>{};
    for (final cat in all) {
      byParent.putIfAbsent(cat.parentId, () => []);
      byParent[cat.parentId]!.add(cat);
    }

    // 递归为每个节点构建子节点
    GraduationCategory _withChildren(GraduationCategory node) {
      final kids = byParent[node.controlId] ?? [];
      return GraduationCategory(
        name: node.name,
        categoryType: node.categoryType,
        requiredCredits: node.requiredCredits,
        completedCredits: node.completedCredits,
        expectCredits: node.expectCredits,
        completedCount: node.completedCount,
        isPassed: node.isPassed,
        remark: node.remark,
        optionalCourseCount: node.optionalCourseCount,
        controlId: node.controlId,
        parentId: node.parentId,
        categoryLevel: node.categoryLevel,
        children: kids.map(_withChildren).toList(),
      );
    }

    // 只返回根节点
    return all.where((c) => c.isRoot).map(_withChildren).toList();
  }

  // 缓存从 cxxsscfa.do 获取的培养方案信息
  String _pyfaName = '';
  double _totalCredits = 0;
  double _earnedCredits = 0;
  String _studentName = '';

  /// 角色选择
  Future<void> _entranceFlow(String host) async {
    try {
      final resp = await client.get(
        Uri.parse('$baseUrl/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=4768574631264620&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer': '$baseUrl/jwapp/sys/cjcx/*default/index.do',
          'X-Requested-With': 'XMLHttpRequest',
        },
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
                await client.get(Uri.parse(targetUrl));
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  String _calcXnxqdm() {
    final now = DateTime.now();
    return now.month >= 2 && now.month <= 7
        ? '${now.year - 1}-${now.year}-2'
        : '${now.year}-${now.year + 1}-1';
  }

  List<GraduationCategory> _parseResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      final msg = json['msg']?.toString() ?? '';
      throw Exception(
          'API 返回错误: ${json['code']}${msg.isNotEmpty ? ' $msg' : ''}');
    }
    final datas = json['datas'];
    if (datas is Map) {
      final module = datas['cxscfakz'];
      if (module is Map) {
        final rows = module['rows'];
        if (rows is List && rows.isNotEmpty) {
          return rows
              .map((r) =>
                  GraduationCategory.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }
    }
    return [];
  }

  Map<String, String> _entryHeaders(String host) => {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Host': host,
        'Upgrade-Insecure-Requests': '1',
      };

  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/xywccx/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}
