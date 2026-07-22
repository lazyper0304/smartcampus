import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../scjx2/scjx2_api_service.dart';
import 'course.dart';

class CourseService {
  final SharedHttpClient client;
  final String baseUrl;
  final String? userId;

  /// scjx2 通用 API 客户端（实验教学）
  late final Scjx2ApiService _scjx2;

  /// TEACH 模块的当前路由路径（用于签名头）
  static const String _teachRoutePath =
      '/6001/modules/teach/stu/result/result';

  /// TEACH 模块标识
  static const String _teachModuleId = 'teach';

  CourseService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
    this.userId,
  }) {
    _scjx2 = Scjx2ApiService(client: client);
  }

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

  /// 从 xnxqdm (如 "2025-2026-2") 解析 XN 和 XQ
  List<String> _parseXnxq(String xnxqdm) {
    final parts = xnxqdm.split('-');
    if (parts.length >= 3) {
      return ['${parts[0]}-${parts[1]}', parts[2]];
    }
    return ['', ''];
  }

  /// 获取当前学期的校历信息（总周次 + 学期起始日期 + 各周日期）
  Future<Map<String, dynamic>> fetchSemesterCalendar(
      String xnxqdm, {bool forceRefresh = false}) async {
    const cacheKey = 'course_calendar';
    if (!forceRefresh) {
      final cached = DataCache().get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    final xnq = _parseXnxq(xnxqdm);
    try {
      final resp = await _silentPost(
        '/jwapp/sys/wdkb/modules/xskcb/cxxljc.do',
        host,
        {'XN': xnq[0], 'XQ': xnq[1]},
      );
      if (resp != null) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final datas = json['datas'] as Map?;
        final module = datas?['cxxljc'] as Map?;
        final rows = module?['rows'] as List?;
        if (rows != null && rows.isNotEmpty) {
          final result = rows[0] as Map<String, dynamic>;
          DataCache().set(cacheKey, result);
          return result;
        }
      }
    } catch (_) {}
    return {};
  }

  /// 返回当前周次和学期第一周周一日期
  Future<CurrentWeekInfo> fetchCurrentWeek({String? xnxqdm, bool forceRefresh = false}) async {
    const cacheKey = 'course_current_week';
    if (!forceRefresh) {
      final cached = DataCache().get<CurrentWeekInfo>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    try {
      // 构造 dqzc.do 参数（JS 源码：需要 XN + XQ + RQ）
      final today = DateTime.now();
      final params = <String, String>{
        'RQ': '${today.year}-${today.month}-${today.day}',
      };
      if (xnxqdm != null && xnxqdm.isNotEmpty) {
        final xnq = _parseXnxq(xnxqdm);
        params['XN'] = xnq[0];
        params['XQ'] = xnq[1];
      }

      final resp = await _silentPost(
        '/jwapp/sys/wdkb/modules/jshkcb/dqzc.do',
        host,
        params,
      );
      if (resp != null) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final datas = json['datas'] as Map?;
        final module = datas?['dqzc'] as Map?;
        final rows = module?['rows'] as List?;
        if (rows != null && rows.isNotEmpty) {
          final row = rows[0] as Map<String, dynamic>;
          final zc =
              int.tryParse(row['ZC']?.toString() ?? '0') ?? _calcCurrentWeek();

          // 动态推算第1周周一
          // 公式：firstMonday = 今天 - (当前周-1)*7 - (今天星期-1)
          final todayWeekday = today.weekday; // 1=Mon..7=Sun
          final firstMonday = today.subtract(Duration(
            days: (zc - 1) * 7 + (todayWeekday - 1),
          ));

          final info = CurrentWeekInfo(week: zc, firstMonday: firstMonday);
          DataCache().set(cacheKey, info);
          return info;
        }
      }
    } catch (_) {}
    // 回退
    return CurrentWeekInfo(
      week: _calcCurrentWeek(),
      firstMonday: DateTime(DateTime.now().year, 3, 1),
    );
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

  // ==================== 获取实验教学（scjx2 TEACH 模块） ====================

  /// 获取实验教学列表
  ///
  /// 调用 scjx2 `teach/stuTime/listStuTimePage` 接口，返回的每条记录是
  /// 「单次实验」（单周次 + 单节次范围），转成 Course 列表后可直接
  /// 与普通课程合并显示。
  ///
  /// - [xnxqdm]: 学期代码，如 "2025-2026-2"
  /// - [week]: 周次（null 表示全部），用于缓存 key
  /// - [courseId]: 可选，按课程 ID 过滤
  /// - [forceRefresh]: 强制刷新
  Future<List<Course>> fetchExperiments({
    String? xnxqdm,
    int? week,
    String courseId = '',
    bool forceRefresh = false,
  }) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'course_experiments_${xnxqdm}_${week ?? "all"}_$courseId';
    if (!forceRefresh) {
      final cached = DataCache().get<List<Course>>(cacheKey);
      if (cached != null) return cached;
    }

    // 未登录时不抛错，返回空列表（用户可能没登录 scjx2）
    if (!await _scjx2.isLoggedIn(moduleId: _teachModuleId)) {
      return [];
    }

    final body = <String, dynamic>{
      'yearterm': xnxqdm,
      'course_id': courseId,
      'week': week,
      'currpage': 1,
      'pagesize': 200, // 一次拿完所有实验记录
    };

    try {
      final json = await _scjx2.request(
        path: '/teach/teach/stuTime/listStuTimePage',
        data: body,
        currentRoutePath: _teachRoutePath,
        apiName: 'TEACH',
        moduleId: _teachModuleId,
      );
      final result = (json['result'] as Map<String, dynamic>?)?['list'] as List?;
      if (result == null) return [];

      final courses = <Course>[];
      for (int i = 0; i < result.length; i++) {
        courses.add(Course.fromExperimentJson(
          result[i] as Map<String, dynamic>,
          colorIndex: i,
        ));
      }
      DataCache().set(cacheKey, courses);
      return courses;
    } catch (e) {
      debugPrint('fetchExperiments error: $e');
      return [];
    }
  }

  /// 引导登录 scjx2（实验教学需要）
  Future<bool> bootstrapScjx2() => _scjx2.bootstrapLogin();

  // ==================== 全校课表查询（kcbcx / bjkcb 模块） ====================

  /// 当前学期代码（对外可读）
  String get defaultXnxqdm => _calcXnxqdm();

  /// 建立 kcbcx（全校课表查询）模块会话
  ///
  /// 与 wdkb 模块类似：先走入口分组列表（appId=4766960573884517），
  /// 再 GET kcbcx 首页以建立模块级会话（后续 POST 需要）。
  Future<void> ensureKcbcxSession() async {
    final host = _host;
    try {
      final resp = await client.get(
        Uri.parse('$baseUrl/appMultiGroupEntranceList'
            '?r_t=${DateTime.now().millisecondsSinceEpoch}'
            '&appId=4766960573884517&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer':
              '$baseUrl/jwapp/sys/kcbcx/*default/index.do',
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
    try {
      await client.get(
        Uri.parse('$baseUrl/jwapp/sys/kcbcx/*default/index.do'),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Host': host,
          'Upgrade-Insecure-Requests': '1',
        },
      );
    } catch (_) {}
  }

  /// 获取全校班级列表（bjcx.do）
  ///
  /// 默认 pageSize=200 循环拉取全量并缓存，便于客户端搜索/学院筛选。
  Future<List<SchoolClass>> fetchAllClasses({
    String? xnxqdm,
    int pageSize = 200,
    bool forceRefresh = false,
  }) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'all_classes_$xnxqdm';
    if (!forceRefresh) {
      final cached = DataCache().get<List<SchoolClass>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    await ensureKcbcxSession();

    final classes = <SchoolClass>[];
    int page = 1;
    int total = 0;
    while (true) {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kcbcx/modules/bjkcb/bjcx.do'),
        body: {
          'XNXQDM': xnxqdm,
          'SFSY': '1',
          'SFYPK': '1',
          '*order': '-NJ,+YXPX,+ZYPX,+PX',
          'pageSize': pageSize.toString(),
          'pageNumber': page.toString(),
        },
        headers: _formHeadersKcbcx(host),
        noRedirect: true,
      );
      if (resp.statusCode != 200) break;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['code']?.toString() != '0') break;
      final datas = json['datas'];
      if (datas is! Map) break;
      final module = datas['bjcx'];
      if (module is! Map) break;
      final rows = module['rows'];
      if (rows is! List || rows.isEmpty) break;
      classes.addAll(rows
          .map((r) => SchoolClass.fromJson(r as Map<String, dynamic>)));
      total = int.tryParse(module['totalSize']?.toString() ?? '0') ?? 0;
      if (classes.length >= total) break;
      page++;
    }
    DataCache().set(cacheKey, classes);
    return classes;
  }

  /// 获取指定班级的周课表（bjkcb.do）
  ///
  /// 返回的 row 字段（SKZC/SKXQ/KSJC/JSJC/KCM/SKJS/JASMC）与
  /// [Course.fromJson] 完全兼容，直接复用。
  Future<List<Course>> fetchClassSchedule({
    required String bjdm,
    String? xnxqdm,
    bool forceRefresh = false,
  }) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'class_schedule_${xnxqdm}_$bjdm';
    if (!forceRefresh) {
      final cached = DataCache().get<List<Course>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    await ensureKcbcxSession();
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/kcbcx/modules/bjkcb/bjkcb.do'),
      body: {'XNXQDM': xnxqdm, 'BJDM': bjdm},
      headers: _formHeadersKcbcx(host),
      noRedirect: true,
    );
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取班级课表失败：HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误：${json['code']}');
    }
    final datas = json['datas'];
    if (datas is! Map) return [];
    final module = datas['bjkcb'];
    if (module is! Map) return [];
    final rows = module['rows'];
    if (rows is! List) return [];
    final courses = <Course>[];
    for (int i = 0; i < rows.length; i++) {
      courses.add(Course.fromJson(rows[i] as Map<String, dynamic>,
          colorIndex: i));
    }
    DataCache().set(cacheKey, courses);
    return courses;
  }

  /// 获取班级未排课程（bjwpkc.do）：仅有课程信息，无具体时间地点
  Future<List<UnarrangedCourse>> fetchClassUnarranged({
    required String bjdm,
    String? xnxqdm,
    bool forceRefresh = false,
  }) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'class_unarranged_${xnxqdm}_$bjdm';
    if (!forceRefresh) {
      final cached = DataCache().get<List<UnarrangedCourse>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    await ensureKcbcxSession();
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kcbcx/modules/bjkcb/bjwpkc.do'),
        body: {'XNXQDM': xnxqdm, 'BJDM': bjdm},
        headers: _formHeadersKcbcx(host),
        noRedirect: true,
      );
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'];
      if (datas is! Map) return [];
      final module = datas['bjwpkc'];
      if (module is! Map) return [];
      final rows = module['rows'];
      if (rows is! List) return [];
      final result = rows
          .map((r) => UnarrangedCourse.fromJson(r as Map<String, dynamic>))
          .toList();
      DataCache().set(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  /// 获取班级调/停/补课程记录（bjdkkc.do）
  Future<List<ClassCourseChange>> fetchClassChanges({
    required String bjdm,
    String? xnxqdm,
    bool forceRefresh = false,
  }) async {
    xnxqdm ??= _calcXnxqdm();
    final cacheKey = 'class_changes_${xnxqdm}_$bjdm';
    if (!forceRefresh) {
      final cached = DataCache().get<List<ClassCourseChange>>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    await ensureKcbcxSession();
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kcbcx/modules/bjkcb/bjdkkc.do'),
        body: {'XNXQDM': xnxqdm, 'BJDM': bjdm},
        headers: _formHeadersKcbcx(host),
        noRedirect: true,
      );
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'];
      if (datas is! Map) return [];
      final module = datas['bjdkkc'];
      if (module is! Map) return [];
      final rows = module['rows'];
      if (rows is! List) return [];
      final result = rows
          .map((r) => ClassCourseChange.fromJson(r as Map<String, dynamic>))
          .toList();
      DataCache().set(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  /// 获取班级课表学期信息：总周次 + 开学日期（cxxljc.do，xskcb 模块）
  Future<ClassSemesterInfo> fetchClassSemesterInfo(String xnxqdm,
      {bool forceRefresh = false}) async {
    const cacheKey = 'class_semester_info';
    if (!forceRefresh) {
      final cached = DataCache().get<ClassSemesterInfo>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    final xnq = _parseXnxq(xnxqdm);
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kcbcx/modules/xskcb/cxxljc.do'),
        body: {'XN': xnq[0], 'XQ': xnq[1]},
        headers: _formHeadersKcbcx(host),
        noRedirect: true,
      );
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final datas = json['datas'];
        if (datas is Map) {
          final m = datas['cxxljc'];
          if (m is Map) {
            final rows = m['rows'];
            if (rows is List && rows.isNotEmpty) {
              final row = rows[0] as Map<String, dynamic>;
              final info = ClassSemesterInfo(
                totalWeeks:
                    int.tryParse(row['ZZC']?.toString() ?? '0') ?? 0,
                startDateStr: row['XQKSRQ']?.toString() ?? '',
              );
              DataCache().set(cacheKey, info);
              return info;
            }
          }
        }
      }
    } catch (_) {}
    return const ClassSemesterInfo();
  }

  /// 获取当前教学周次（dqzc.do，bjkcb 模块），用于班级课表默认高亮
  Future<int> fetchClassCurrentWeek(String xnxqdm,
      {bool forceRefresh = false}) async {
    const cacheKey = 'class_current_week';
    if (!forceRefresh) {
      final cached = DataCache().get<int>(cacheKey);
      if (cached != null) return cached;
    }
    final host = _host;
    final xnq = _parseXnxq(xnxqdm);
    final today = DateTime.now();
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kcbcx/modules/bjkcb/dqzc.do'),
        body: {
          'XN': xnq[0],
          'XQ': xnq[1],
          'RQ': '${today.year}-${today.month}-${today.day}',
        },
        headers: _formHeadersKcbcx(host),
        noRedirect: true,
      );
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final datas = json['datas'];
        if (datas is Map) {
          final m = datas['dqzc'];
          if (m is Map) {
            final rows = m['rows'];
            if (rows is List && rows.isNotEmpty) {
              final zc = int.tryParse(
                      (rows[0] as Map)['ZC']?.toString() ?? '0') ??
                  1;
              DataCache().set(cacheKey, zc);
              return zc;
            }
          }
        }
      }
    } catch (_) {}
    return 1;
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

  /// kcbcx 模块的表单请求头（Referer 指向 kcbcx 首页）
  Map<String, String> _formHeadersKcbcx(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/kcbcx/*default/index.do',
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
