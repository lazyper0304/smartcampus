import 'dart:convert';

import '../core/http_client.dart';
import 'course.dart';

class CourseService {
  final SharedHttpClient client;
  final String baseUrl;
  final String? userId;

  CourseService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
    this.userId,
  });

  Future<List<Course>> fetchCourses({int? week}) async {
    final xnxqdm = _calcXnxqdm();
    final host = Uri.parse(baseUrl).host;

    // 1. 角色选择（建立 ehall 模块级 session，否则任何 HTTPS API 都 403）
    await _entranceFlow(host);

    // 2. 获取课表入口页，建立模块级 session
    await client.get(
      Uri.parse('$baseUrl/jwapp/sys/wdkb/*default/index.do'),
      headers: _entryHeaders(host),
    );

    // 3. 获取当前学期信息
    _silentPost('/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do', host, {});

    // 4. 获取学生信息，建立用户上下文
    if (userId != null && userId!.isNotEmpty) {
      _silentPost('/jwapp/sys/wdkb/modules/xskcb/cxxsjbxx.do', host,
          {'XH': userId!});
    }

    // 5. 获取课表（form-urlencoded，匹配浏览器实际请求）
    final params = <String, String>{'XNXQDM': xnxqdm};
    if (week != null) params['SKZC'] = week.toString();

    var resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/wdkb/modules/xskcb/xskcb.do'),
      body: params,
      headers: _formHeaders(host),
      noRedirect: true,
    );

    if (resp.statusCode == 403) {
      resp = await client.postJson(
        Uri.parse('$baseUrl/jwapp/sys/wdkb/modules/xskcb/xskcb.do'),
        body: params,
        headers: _jsonHeaders(host),
        noRedirect: true,
      );
    }

    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode == 403) {
      final snippet = resp.body.length > 500 ? resp.body.substring(0, 500) : resp.body;
      throw Exception('服务器拒绝访问（403）\n$snippet');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取课程数据失败：HTTP ${resp.statusCode}');
    }

    return _parseResponse(resp.body);
  }

  /// 角色选择流程：调用 appMultiGroupEntranceList 建立模块级 session
  /// 参考 ScoreService 实现。无此步骤时 HTTPS 的 ehall API 返回 403。
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
    } catch (_) {
      // 角色选择失败不影响主流程
    }
  }

  Future<void> _silentPost(String path, String host, Map<String, String> params) async {
    try {
      await client.postForm(Uri.parse('$baseUrl$path'),
          body: params, headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Host': host,
            'Origin': 'https://ehall.yibinu.edu.cn',
            'Referer': 'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
            'X-Requested-With': 'XMLHttpRequest',
          });
    } catch (_) {}
  }

  List<Course> _parseResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误：${json['code']}');
    }
    final datas = json['datas'];
    if (datas is Map) {
      final module = datas['xskcb'];
      if (module is Map) {
        final rows = module['rows'];
        if (rows is List && rows.isNotEmpty) {
          final courses = <Course>[];
          for (int i = 0; i < rows.length; i++) {
            courses.add(Course.fromJson(rows[i] as Map<String, dynamic>, colorIndex: i));
          }
          return courses;
        }
      }
    }
    return [];
  }

  Map<String, String> _entryHeaders(String host) => {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Upgrade-Insecure-Requests': '1',
      };

  Map<String, String> _jsonHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/json; charset=UTF-8',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer': 'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };

  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer': 'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };

  String _calcXnxqdm() {
    final now = DateTime.now();
    return now.month >= 2 && now.month <= 7
        ? '${now.year - 1}-${now.year}-2'
        : '${now.year}-${now.year + 1}-1';
  }
}

const List<int> courseColors = [
  0xFF4A90D9,
  0xFFE67E22,
  0xFF2ECC71,
  0xFFE74C3C,
  0xFF9B59B6,
  0xFF1ABC9C,
  0xFFF39C12,
  0xFF3498DB,
  0xFFE91E63,
  0xFF795548,
  0xFF607D8B,
  0xFF00BCD4,
];
