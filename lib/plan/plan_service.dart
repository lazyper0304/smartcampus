import 'dart:convert';

import '../core/http_client.dart';
import 'plan.dart';

/// 个人培养方案查询服务
class PlanService {
  final SharedHttpClient client;
  final String baseUrl;

  PlanService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  Future<PlanResult> fetchPlan() async {
    final host = Uri.parse(baseUrl).host;

    // 1. 角色选择（方案查询专属 appId）
    await _entranceFlow(host);

    // 2. 访问入口页
    await client.get(
      Uri.parse('$baseUrl/jwapp/sys/xsfacx/*default/index.do'),
      headers: _entryHeaders(host),
    );

    // 3. 获取个人培养方案概要（grpyfacx）
    final grResp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/xsfacx/modules/pyfacxepg/grpyfacx.do'),
      body: {},
      headers: _formHeaders(host),
    );
    PlanSummary summary;
    if (grResp.statusCode == 200) {
      final j = jsonDecode(grResp.body) as Map<String, dynamic>;
      if (j['code']?.toString() == '0') {
        final datas = j['datas'];
        if (datas is Map) {
          final rows = (datas['grpyfacx'] as Map?)?['rows'] as List?;
          if (rows != null && rows.isNotEmpty) {
            summary = PlanSummary.fromJson(rows[0] as Map<String, dynamic>);
          } else {
            throw Exception('未获取到培养方案信息');
          }
        } else {
          throw Exception('培养方案接口数据异常');
        }
      } else {
        throw Exception('培养方案接口返回错误：${j['code']}');
      }
    } else {
      throw Exception('获取培养方案失败：HTTP ${grResp.statusCode}');
    }

    // 4. 查询系统参数
    await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwpubapp/modules/pyfa/cxxtcs.do'),
      body: {'*search': 'true'},
      headers: _formHeaders(host),
    );

    // 5. 获取方案详情（qxpyfacx）
    final qxResp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwpubapp/modules/pyfa/qxpyfacx.do'),
      body: {'*search': 'true', 'pageSize': '1', 'pageNumber': '1'},
      headers: _formHeaders(host),
    );
    PlanDetail? detail;
    if (qxResp.statusCode == 200) {
      final j = jsonDecode(qxResp.body) as Map<String, dynamic>;
      if (j['code']?.toString() == '0') {
        final datas = j['datas'];
        if (datas is Map) {
          final rows = (datas['qxpyfacx'] as Map?)?['rows'] as List?;
          if (rows != null && rows.isNotEmpty) {
            detail = PlanDetail.fromJson(rows[0] as Map<String, dynamic>);
          }
        }
      }
    }

    // 6. 获取课程组（kzcx）
    final kzResp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwpubapp/modules/pyfa/kzcx.do'),
      body: {'*search': 'true', 'pageSize': '999', 'pageNumber': '1'},
      headers: _formHeaders(host),
    );
    List<PlanGroup> groups = [];
    if (kzResp.statusCode == 200) {
      final j = jsonDecode(kzResp.body) as Map<String, dynamic>;
      if (j['code']?.toString() == '0') {
        final datas = j['datas'];
        if (datas is Map) {
          final rows = (datas['kzcx'] as Map?)?['rows'] as List?;
          if (rows != null) {
            groups = rows
                .map((r) => PlanGroup.fromJson(r as Map<String, dynamic>))
                .toList();
          }
        }
      }
    }

    // 7. 获取课程详情（kzkccx）
    final kcResp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/jwpubapp/modules/pyfa/kzkccx.do'),
      body: {'*search': 'true', 'pageSize': '999', 'pageNumber': '1'},
      headers: _formHeaders(host),
    );
    if (kcResp.statusCode == 200) {
      final j = jsonDecode(kcResp.body) as Map<String, dynamic>;
      if (j['code']?.toString() == '0') {
        final datas = j['datas'];
        if (datas is Map) {
          final rows = (datas['kzkccx'] as Map?)?['rows'] as List?;
          if (rows != null) {
            final courses = rows
                .map((r) => PlanCourse.fromJson(r as Map<String, dynamic>))
                .toList();
            // 将课程挂载到对应的课程组
            _attachCourses(groups, courses);
          }
        }
      }
    }

    // 8. 构建层级树
    final tree = _buildTree(groups);

    return PlanResult(
      summary: summary,
      detail: detail,
      groups: tree,
    );
  }

  void _attachCourses(List<PlanGroup> groups, List<PlanCourse> courses) {
    for (final group in groups) {
      final matched = courses.where((c) => c.groupId == group.groupId).toList();
      if (matched.isNotEmpty) {
        final idx = groups.indexOf(group);
        groups[idx] = group.copyWith(courses: matched);
      }
    }
  }

  List<PlanGroup> _buildTree(List<PlanGroup> all) {
    final byParent = <String, List<PlanGroup>>{};
    for (final g in all) {
      byParent.putIfAbsent(g.parentId, () => []);
      byParent[g.parentId]!.add(g);
    }

    PlanGroup _assignChildren(PlanGroup node) {
      final kids = byParent[node.groupId] ?? [];
      if (kids.isEmpty) return node;
      return node.copyWith(children: kids.map(_assignChildren).toList());
    }

    return byParent['-1']?.map(_assignChildren).toList() ?? [];
  }

  Future<void> _entranceFlow(String host) async {
    try {
      final resp = await client.get(
        Uri.parse('$baseUrl/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=4766859113956613&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer': '$baseUrl/jwapp/sys/xsfacx/*default/index.do',
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
            'https://ehall.yibinu.edu.cn/jwapp/sys/xsfacx/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}

class PlanResult {
  final PlanSummary summary;
  final PlanDetail? detail;
  final List<PlanGroup> groups;

  const PlanResult({
    required this.summary,
    this.detail,
    this.groups = const [],
  });
}
