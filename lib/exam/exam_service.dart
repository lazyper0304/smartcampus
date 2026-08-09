import 'dart:convert';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'exam.dart';

/// 考试安排查询服务
class ExamService {
  final SharedHttpClient client;
  final String baseUrl;

  ExamService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  Future<List<Exam>> fetchExams({String? xnxqdm, bool forceRefresh = false}) async {
    final term = xnxqdm ?? _calcXnxqdm();
    final cacheKey = 'exam_list_$term';
    if (!forceRefresh) {
      final cached = DataCache().get<List<Exam>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = Uri.parse(baseUrl).host;

    // 1. 共享预热链路（角色选择 → 入口 → 系统参数 → 学期 → 学生信息）
    await _warmUp(host);

    // 6. 查考试安排（需要 XNXQDM 学期参数）
    final resp = await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/wdksap.do'),
      body: {
        '*search': 'true',
        'pageSize': '999',
        'pageNumber': '1',
        'XNXQDM': term,
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

    final result = _parseResponse(resp.body);
    DataCache().set(cacheKey, result);
    return result;
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

  /// 查询未安排考试（本学期已选但尚未排考场的课程）
  ///
  /// 接口 `cxyxkwapkwdkc.do`（POST XNXQDM），返回 rows 仅含
  /// KCM（课程名）/ KCH（课程号）/ ZJJSXM（教师），其余字段为 null。
  Future<List<UnarrangedExam>> fetchUnarrangedExams(
      {String? xnxqdm, bool forceRefresh = false}) async {
    final term = xnxqdm ?? _calcXnxqdm();
    final cacheKey = 'exam_unarranged_$term';
    if (!forceRefresh) {
      final cached = DataCache().get<List<UnarrangedExam>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = Uri.parse(baseUrl).host;

    // 与 fetchExams 共用同一预热链路（角色选择 → 入口 → 系统参数 → 学期）
    await _warmUp(host);

    final resp = await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/cxyxkwapkwdkc.do'),
      body: {'XNXQDM': term},
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
      throw Exception('获取未安排考试失败：HTTP ${resp.statusCode}');
    }

    final result = _parseUnarranged(resp.body);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 查询学年学期列表（xnxqcx.do，考试模块）
  ///
  /// 留空 body 时服务端返回全部学期，用于学期切换。
  Future<List<ExamSemester>> fetchSemesters({bool forceRefresh = false}) async {
    const cacheKey = 'exam_semesters';
    if (!forceRefresh) {
      final cached = DataCache().get<List<ExamSemester>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = Uri.parse(baseUrl).host;

    // 与查询共用同一预热链路（保证会话新鲜）
    await _warmUp(host);

    final resp = await client.postForm(
      Uri.parse(
          '$baseUrl/jwapp/sys/studentWdksapApp/modules/wdksap/xnxqcx.do'),
      body: {},
      headers: _formHeaders(host),
      noRedirect: true,
    );

    if (resp.statusCode != 200) {
      throw Exception('获取学年学期失败：HTTP ${resp.statusCode}');
    }

    final result = _parseSemesters(resp.body);
    DataCache().set(cacheKey, result);
    return result;
  }

  List<ExamSemester> _parseSemesters(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误: ${json['code']} ${json['msg'] ?? ''}');
    }
    final datas = json['datas'];
    if (datas is Map) {
      final module = datas['xnxqcx'];
      if (module is Map) {
        final rows = module['rows'];
        if (rows is List && rows.isNotEmpty) {
          return rows
              .map((r) => ExamSemester.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }
    }
    return [];
  }

  List<UnarrangedExam> _parseUnarranged(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误: ${json['code']} ${json['msg'] ?? ''}');
    }
    final datas = json['datas'];
    if (datas is Map) {
      final module = datas['cxyxkwapkwdkc'];
      if (module is Map) {
        final rows = module['rows'];
        if (rows is List && rows.isNotEmpty) {
          return rows
              .map((r) => UnarrangedExam.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }
    }
    return [];
  }

  /// 共享预热链路：角色选择 + 入口页 + 系统参数 + 当前学期 + 学生信息
  Future<void> _warmUp(String host) async {
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
