import 'dart:convert';

import '../core/http_client.dart';
import 'exam.dart';

/// 考试安排查询服务
class ExamService {
  final SharedHttpClient client;
  final String baseUrl;

  ExamService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  Future<List<Exam>> fetchExams() async {
    final host = Uri.parse(baseUrl).host;

    // 1. 角色选择（使用考试模块的 appId）
    await _entranceFlow(host);

    // 2. 访问入口页
    await client.get(
      Uri.parse('$baseUrl/jwapp/sys/studentWdksapApp/*default/index.do'),
      headers: _entryHeaders(host),
    );

    // 3. 查询系统参数
    await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/cxxtcs.do'),
      body: {},
      headers: _formHeaders(host),
    );

    // 4. 获取当前学期
    await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/dqxnxq.do'),
      body: {},
      headers: _formHeaders(host),
    );

    // 5. 获取学生信息
    await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/cxxsjbxx.do'),
      body: {'*search': 'true'},
      headers: _formHeaders(host),
    );

    // 6. 查考试安排（需要 XNXQDM 学期参数）
    final xnxqdm = _calcXnxqdm();
    final resp = await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/wdksap.do'),
      body: {
        '*search': 'true',
        'pageSize': '999',
        'pageNumber': '1',
        'XNXQDM': xnxqdm,
      },
      headers: _formHeaders(host),
      noRedirect: true,
    );

    if (resp.statusCode == 403) {
      throw Exception('服务器拒绝访问（403）');
    }
    if (resp.statusCode == 302) {
      throw Exception('会话已过期');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取考试安排失败：HTTP ${resp.statusCode}');
    }

    return _parseResponse(resp.body);
  }

  List<Exam> _parseResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误: ${json['code']} ${json['msg'] ?? ''}');
    }
    final datas = json['datas'];
    if (datas is Map) {
      final module = datas['wdksap'];
      if (module is Map) {
        final rows = module['rows'];
        if (rows is List && rows.isNotEmpty) {
          return rows
              .map((r) => Exam.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }
    }
    return [];
  }

  /// 计算当前学期代码
  String _calcXnxqdm() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    if (month >= 2 && month <= 8) {
      return '${year - 1}-$year-2';
    } else if (month >= 9) {
      return '$year-${year + 1}-1';
    } else {
      return '${year - 1}-$year-1';
    }
  }

  Future<void> _entranceFlow(String host) async {
    try {
      final resp = await client.get(
        Uri.parse('$baseUrl/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=4768687067472349&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer': '$baseUrl/jwapp/sys/studentWdksapApp/*default/index.do',
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
            'https://ehall.yibinu.edu.cn/jwapp/sys/studentWdksapApp/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}
