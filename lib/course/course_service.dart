import 'dart:convert';

import '../core/http_client.dart';
import '../core/data_cache.dart';
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

  String get _host => Uri.parse(baseUrl).host;

  // ==================== 通用入口流程 ====================

  /// 执行入口流程（角色选择 + 模块 session），后续 API 调用不再重复执行
  Future<void> ensureSession() async {
    await _entranceFlow(_host);
    await client.get(
      Uri.parse('$baseUrl/jwapp/sys/wdkb/*default/index.do'),
      headers: _entryHeaders(_host),
    );
  }

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

  // ==================== 获取课表（主接口） ====================

  Future<List<Course>> fetchCourses({int? week, String? xnxqdm, bool forceRefresh = false}) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'course_list_${xnxqdm}_${week ?? "all"}';
    if (!forceRefresh) {
      final cached = DataCache().get<List<Course>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    await ensureSession();

    // 构建学期/学生上下文
    await _silentPost('/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do', host, {});
    if (userId != null && userId!.isNotEmpty) {
      await _silentPost('/jwapp/sys/wdkb/modules/xskcb/cxxsjbxx.do', host,
          {'XH': userId!});
    }

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
      final snippet = resp.body.length > 500
          ? resp.body.substring(0, 500)
          : resp.body;
      throw Exception('服务器拒绝访问（403）\n$snippet');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取课程数据失败：HTTP ${resp.statusCode}');
    }

    final result = _parseXskcbResponse(resp.body);
    DataCache().set(cacheKey, result);
    return result;
  }

  // ==================== 获取当前周次 ====================

  /// 返回当前周次（通过 dqzc.do 查询）
  Future<int> fetchCurrentWeek({bool forceRefresh = false}) async {
    const cacheKey = 'course_current_week';
    if (!forceRefresh) {
      final cached = DataCache().get<int>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    try {
      // 需要先获取学期信息获取 academic term ID
      final resp = await _silentPost(
        '/jwapp/sys/wdkb/modules/jshkcb/dqzc.do',
        host,
        {},
      );
      if (resp == null) return _calcCurrentWeek();
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'] as Map?;
      if (datas == null) return _calcCurrentWeek();
      final module = datas['dqzc'] as Map?;
      if (module == null) return _calcCurrentWeek();
      final rows = module['rows'] as List?;
      if (rows == null || rows.isEmpty) return _calcCurrentWeek();
      final row = rows[0] as Map<String, dynamic>;
      final zc = int.tryParse(row['ZC']?.toString() ?? '0') ?? _calcCurrentWeek();
      DataCache().set(cacheKey, zc);
      return zc;
    } catch (_) {
      return _calcCurrentWeek();
    }
  }

  /// 从学期起始日期推算当前周次
  int _calcCurrentWeek() {
    // 春季学期大约3月初开学（第1周），估算
    final now = DateTime.now();
    final semesterStart = DateTime(now.year, 3, 1);
    final diff = now.difference(semesterStart).inDays;
    if (diff < 0) return 1;
    return (diff ~/ 7) + 1;
  }

  // ==================== 获取学期列表 ====================

  Future<List<SemesterInfo>> fetchSemesters({bool forceRefresh = false}) async {
    const cacheKey = 'course_semesters';
    if (!forceRefresh) {
      final cached = DataCache().get<List<SemesterInfo>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    try {
      final resp = await _silentPost(
        '/jwapp/sys/wdkb/modules/jshkcb/xnxqcx.do',
        host,
        {},
      );
      if (resp == null) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'] as Map?;
      if (datas == null) return [];
      final module = datas['xnxqcx'] as Map?;
      if (module == null) return [];
      final rows = module['rows'] as List?;
      if (rows == null) return [];
      final result = rows
          .map((r) => SemesterInfo.fromJson(r as Map<String, dynamic>))
          .toList();
      DataCache().set(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  // ==================== 获取调课/停课信息 ====================

  Future<List<CourseChange>> fetchCourseChanges({String? xnxqdm, bool forceRefresh = false}) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'course_changes_$xnxqdm';
    if (!forceRefresh) {
      final cached = DataCache().get<List<CourseChange>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/wdkb/modules/xskcb/xsdkkc.do'),
        body: {'XNXQDM': xnxqdm},
        headers: _formHeaders(host),
        noRedirect: true,
      );
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'] as Map?;
      if (datas == null) return [];
      final module = datas['xsdkkc'] as Map?;
      if (module == null) return [];
      final rows = module['rows'] as List?;
      if (rows == null) return [];
      final result = rows
          .map((r) => CourseChange.fromJson(r as Map<String, dynamic>))
          .toList();
      DataCache().set(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  // ==================== 获取未安排课程 ====================

  Future<List<UnarrangedCourse>> fetchUnarrangedCourses({String? xnxqdm, bool forceRefresh = false}) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'course_unarranged_$xnxqdm';
    if (!forceRefresh) {
      final cached = DataCache().get<List<UnarrangedCourse>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/wdkb/modules/xskcb/xswpkc.do'),
        body: {'XNXQDM': xnxqdm},
        headers: _formHeaders(host),
        noRedirect: true,
      );
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'] as Map?;
      if (datas == null) return [];
      final module = datas['xswpkc'] as Map?;
      if (module == null) return [];
      final rows = module['rows'] as List?;
      if (rows == null) return [];
      final result = rows
          .map((r) => UnarrangedCourse.fromJson(r as Map<String, dynamic>))
          .toList();
      DataCache().set(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  // ==================== 获取节次时间 ====================

  Future<Map<int, List<String>>> fetchPeriodTimes({bool forceRefresh = false}) async {
    const cacheKey = 'course_period_times';
    if (!forceRefresh) {
      final cached = DataCache().get<Map<int, List<String>>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    try {
      final resp = await _silentPost(
        '/jwapp/sys/wdkb/modules/jshkcb/jc.do',
        host,
        {},
      );
      if (resp == null) return periodTimeRanges;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'] as Map?;
      if (datas == null) return periodTimeRanges;
      final module = datas['jc'] as Map?;
      if (module == null) return periodTimeRanges;
      final rows = module['rows'] as List?;
      if (rows == null) return periodTimeRanges;
      final result = <int, List<String>>{};
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final dm = int.tryParse(row['DM']?.toString() ?? '0') ?? 0;
        if (dm == 0) continue;
        result[dm] = [
          row['KSSJ']?.toString() ?? '',
          row['JSSJ']?.toString() ?? '',
        ];
      }
      DataCache().set(cacheKey, result);
      return result;
    } catch (_) {
      return periodTimeRanges;
    }
  }

  // ==================== 内部工具 ====================

  Future<HttpResponse?> _silentPost(
      String path, String host, Map<String, String> params) async {
    try {
      final resp = await client.postForm(Uri.parse('$baseUrl$path'),
          body: params,
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Host': host,
            'Origin': 'https://ehall.yibinu.edu.cn',
            'Referer':
                'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
            'X-Requested-With': 'XMLHttpRequest',
          });
      return resp;
    } catch (_) {
      return null;
    }
  }

  List<Course> _parseXskcbResponse(String body) {
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
            courses.add(Course.fromJson(
                rows[i] as Map<String, dynamic>,
                colorIndex: i));
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
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };

  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/wdkb/*default/index.do',
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
  0xFF191999, // 校徽蓝
  0xFF1E1EB5,
  0xFF2323D1,
  0xFF2A2AE8,
  0xFF3D3DF0,
  0xFF5555F5,
  0xFF6D6DFA,
  0xFF8585FF,
  0xFF9999FF,
  0xFFADADFF,
  0xFFC2C2FF,
  0xFFD6D6FF,
];
