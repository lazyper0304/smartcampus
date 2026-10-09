import 'dart:convert';


import '../core/bingo/bingo_client.dart';
import '../core/bingo/bingo_config.dart';
import 'course.dart';

/// Bingo 课表服务（`/semester/info`、`/course/*`）。
///
/// 替代原ehall `xskcb.do` + scjx2 实验课两路直连：Bingo 后端已聚合
/// 理论课与实验课（`schedule_type` 区分），一次请求即得整学期课表。
///
/// 输出沿用既有 UI 模型（[Course] / [SemesterInfo] / [TodayCourses]），
/// 因此课表页、首页「今日课程」、桌面组件等调用方无需改动。
class BingoCourseService {
  BingoCourseService._();

  static final BingoCourseService instance = BingoCourseService._();

  final BingoClient _client = BingoClient.instance;

  // ==================== 学期 ====================

  /// 当前学期信息（含周次、开学日期、节次时间）
  Future<BingoSemester> fetchSemester({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = DataCacheHolder.get<BingoSemester>(BingoConfig.keySemesterInfo);
      if (cached != null) return cached;
    }
    final data = await _client.getMap('/semester/info');
    final semester = BingoSemester.fromJson(data);
    DataCacheHolder.set(BingoConfig.keySemesterInfo, semester);
    return semester;
  }

  /// 当前学期标识（如 `2025-2026-2`），空串表示让后端取 current
  Future<String> currentSemesterCode() async {
    try {
      final s = await fetchSemester();
      return s.semester;
    } catch (_) {
      return '';
    }
  }

  /// 学期列表：**由当前学期码往前推 8 个**（含当前，共 8 项）。
  ///
  /// Bingo 后端未提供学期列表端点（`/semester/info` 只回当前学期与周次），
  /// 故沿用参考工程 `buildCourseSemesterList()` 的推导算法：按
  /// `YYYY-YYYY-N` 规则逐个回退（N=2 → N=1 → 学年减 1 → N=2 …）。
  ///
  /// 下拉框展示全部推导线，选中非当前学期时由 `/course/semester/{semester}`
  /// 按该学期取数——**空课表属于正常情况**（推导线含尚未修读的学期）。
  static List<String> buildSemesterList(String current, {int count = 8}) {
    final m = RegExp(r'^(\d{4})-(\d{4})-(\d)$').firstMatch(current);
    if (m == null) return current.isEmpty ? const [] : [current];
    var y1 = int.parse(m.group(1)!);
    var y2 = int.parse(m.group(2)!);
    var term = int.parse(m.group(3)!);
    final list = <String>[];
    for (var i = 0; i < count; i++) {
      list.add('$y1-$y2-$term');
      if (term == 2) {
        term = 1;
      } else {
        term = 2;
        y1--;
        y2--;
      }
    }
    return list;
  }

  /// 学期列表（含当前学期），失败时回退为仅当前学期
  Future<List<String>> fetchSemesterList({int count = 8}) async {
    final current = await currentSemesterCode();
    return buildSemesterList(current, count: count);
  }

  // ==================== 课表 ====================

  /// 整学期课表（一次拉取，本地按周过滤）。
  ///
  /// [semester] 为空时用后端 `current`。
  Future<BingoCourseResult> fetchSemesterCourses({String? semester, bool forceRefresh = false}) async {
    final sem = (semester ?? '').trim();
    final cacheKey = 'bingo_course_${sem.isEmpty ? 'current' : sem}';
    if (!forceRefresh) {
      final cached = DataCacheHolder.get<BingoCourseResult>(cacheKey);
      if (cached != null) return cached;
    }

    final path = sem.isEmpty ? 'current' : Uri.encodeComponent(sem);
    final data = await _client.getMap('/course/semester/$path');

    // 兼容 items / courses 两种字段名
    final rawItems = (data['items'] ?? data['courses']) as List<dynamic>? ?? const [];
    final items = rawItems
        .map((e) => BingoCourseItem.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();
    final maxWeek = (data['max_week'] as num?)?.toInt() ??
        items.fold<int>(0, (m, e) => e.endWeek > m ? e.endWeek : m);

    final result = BingoCourseResult(items: items, maxWeek: maxWeek <= 0 ? 20 : maxWeek);
    DataCacheHolder.set(cacheKey, result);
    return result;
  }

  /// 转为既有 UI 模型
  List<Course> toUiCourses(List<BingoCourseItem> items, {String? semester}) {
    final result = <Course>[];
    for (final item in items) {
      if (item.isCustom) continue; // 自定义课程不在课表页展示入口
      result.add(item.toCourse(semester: semester));
    }
    return result;
  }

  /// 触发后台同步教务数据
  Future<void> refresh({String? semester}) async {
    await _client.postMap('/course/refresh',
        body: {if (semester != null && semester.isNotEmpty) 'semester': semester});
  }

  /// 课表同步状态
  Future<BingoCourseSyncStatus> fetchSyncStatus() async {
    final data = await _client.getMap('/course/sync-status');
    return BingoCourseSyncStatus.fromJson(data);
  }

  // ==================== 今日课程 ====================

  /// 今日课程：优先用学期周次判定，失败时仅按星期过滤。
  ///
  /// 保持与原 `fetchTodayCourses` 相同的降级语义：任何一步失败都只影响
  /// 「周次未知」这一维度，不阻断今日课程展示。
  Future<TodayCourses> fetchTodayCourses({DateTime? now}) async {
    final dt = now ?? DateTime.now();
    final today = dt.weekday; // 1=Mon .. 7=Sun

    int week = 0;
    DateTime? firstMonday;
    String semester = '';
    try {
      final sem = await fetchSemester();
      week = sem.currentWeek;
      semester = sem.semester;
      final start = DateTime.tryParse(sem.startDate);
      if (start != null) {
        firstMonday = start.subtract(Duration(days: start.weekday - 1));
      }
    } catch (_) {
      week = 0;
    }

    // 周次以设备日期现算为准，避免跨周后后端缓存滞后
    if (firstMonday != null) {
      final computed = _weekFromFirstMonday(firstMonday);
      if (computed > 0) week = computed;
    }

    final courses = await fetchUiCourses(semester: semester);
    return TodayCourses(
      courses: pickToday(courses, today, week),
      week: week,
    );
  }

  /// 供首页 / 课表页共用的 UI 课表
  Future<List<Course>> fetchUiCourses({String? semester, bool forceRefresh = false}) async {
    final result = await fetchSemesterCourses(
        semester: semester, forceRefresh: forceRefresh);
    return toUiCourses(result.items, semester: semester);
  }

  /// 当前周次（复用 `/semester/info`）
  Future<CurrentWeekInfo> fetchCurrentWeek({bool forceRefresh = false}) async {
    final sem = await fetchSemester(forceRefresh: forceRefresh);
    final start = DateTime.tryParse(sem.startDate);
    final firstMonday = start != null
        ? start.subtract(Duration(days: start.weekday - 1))
        : DateTime.now();
    var week = sem.currentWeek;
    if (week <= 0) {
      final computed = _weekFromFirstMonday(firstMonday);
      week = computed > 0 ? computed : 1;
    }
    return CurrentWeekInfo(week: week, firstMonday: firstMonday);
  }

  /// 节次时间对照（后端 `period_times` 优先，缺失时回落到本地常量）
  Future<Map<int, List<String>>> fetchPeriodTimes({bool forceRefresh = false}) async {
    try {
      final sem = await fetchSemester(forceRefresh: forceRefresh);
      if (sem.periodTimes.isNotEmpty) {
        final map = <int, List<String>>{};
        sem.periodTimes.forEach((k, v) {
          final period = int.tryParse(k);
          if (period != null && period > 0) {
            map[period] = [v.start, v.end];
          }
        });
        if (map.isNotEmpty) return map;
      }
    } catch (_) {}
    return Map<int, List<String>>.from(periodTimeRanges);
  }

  /// 按「星期 + 当前教学周」过滤并按上课时间排序
  static List<Course> pickToday(List<Course> courses, int weekday, int week) {
    final result = courses.where((c) {
      if (c.day != weekday) return false;
      if (week <= 0) return true;
      return c.weeks.contains(week);
    }).toList();
    result.sort((a, b) {
      final byStart = _firstSection(a).compareTo(_firstSection(b));
      if (byStart != 0) return byStart;
      final byEnd = _lastSection(a).compareTo(_lastSection(b));
      if (byEnd != 0) return byEnd;
      return a.name.compareTo(b.name);
    });
    return result;
  }

  static int _firstSection(Course c) => c.sections.isEmpty ? 0 : c.sections.first;
  static int _lastSection(Course c) => c.sections.isEmpty ? 0 : c.sections.last;

  static int _weekFromFirstMonday(DateTime firstMonday) {
    final now = DateTime.now();
    final fm = DateTime(firstMonday.year, firstMonday.month, firstMonday.day);
    final today = DateTime(now.year, now.month, now.day);
    if (fm.isAfter(today)) return 0;
    final week = today.difference(fm).inDays ~/ 7 + 1;
    return (week < 1 || week > 30) ? 0 : week;
  }
}

/// Bingo 侧学期信息
class BingoSemester {
  final String semester;
  final String startDate;
  final int currentWeek;
  final Map<String, BingoPeriodTime> periodTimes;

  const BingoSemester({
    this.semester = '',
    this.startDate = '',
    this.currentWeek = 0,
    this.periodTimes = const {},
  });

  factory BingoSemester.fromJson(Map<String, dynamic> j) {
    final raw = j['period_times'] as Map<String, dynamic>? ?? const {};
    return BingoSemester(
      semester: j['semester']?.toString() ?? '',
      startDate: j['start_date']?.toString() ?? '',
      currentWeek: (j['current_week'] as num?)?.toInt() ?? 0,
      periodTimes: raw.map((k, v) => MapEntry(
          k, BingoPeriodTime.fromJson(v is Map<String, dynamic> ? v : const {}))),
    );
  }

  Map<String, dynamic> toJson() => {
        'semester': semester,
        'start_date': startDate,
        'current_week': currentWeek,
        'period_times': periodTimes.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class BingoPeriodTime {
  final String start;
  final String end;
  const BingoPeriodTime({this.start = '', this.end = ''});

  factory BingoPeriodTime.fromJson(Map<String, dynamic> j) => BingoPeriodTime(
        start: j['start']?.toString() ?? '',
        end: j['end']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

/// Bingo 侧课表条目
class BingoCourseItem {
  final int id;
  final String semester;
  final String courseName;
  final String courseCode;
  final String courseType;
  final String scheduleType; // normal / experiment
  final String expName;
  final String teacher;
  final String classroom;
  final int dayOfWeek;
  final int startPeriod;
  final int endPeriod;
  final String periodLabel;
  final int startWeek;
  final int endWeek;
  final List<int> weeks;
  final String weekRange;
  final double credit;
  final bool isCustom;

  const BingoCourseItem({
    this.id = 0,
    this.semester = '',
    this.courseName = '',
    this.courseCode = '',
    this.courseType = '',
    this.scheduleType = 'normal',
    this.expName = '',
    this.teacher = '',
    this.classroom = '',
    this.dayOfWeek = 0,
    this.startPeriod = 0,
    this.endPeriod = 0,
    this.periodLabel = '',
    this.startWeek = 0,
    this.endWeek = 0,
    this.weeks = const [],
    this.weekRange = '',
    this.credit = 0,
    this.isCustom = false,
  });

  factory BingoCourseItem.fromJson(Map<String, dynamic> j) {
    // weeks 优先解析 JSON 数组字符串；缺失时由 start/end_week 推导
    var weeks = <int>[];
    final rawWeeks = j['weeks']?.toString() ?? '';
    if (rawWeeks.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawWeeks);
        if (decoded is List) {
          weeks = decoded.whereType<num>().map((e) => e.toInt()).toList();
        }
      } catch (_) {
        weeks = _parseWeekText(rawWeeks);
      }
    }
    if (weeks.isEmpty) weeks = _parseWeekText(j['week_range']?.toString() ?? '');

    final startWeek = (j['start_week'] as num?)?.toInt() ?? 0;
    final endWeek = (j['end_week'] as num?)?.toInt() ?? 0;
    if (weeks.isEmpty && startWeek > 0 && endWeek >= startWeek) {
      weeks = [for (int w = startWeek; w <= endWeek; w++) w];
    }

    return BingoCourseItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      semester: j['semester']?.toString() ?? '',
      courseName: j['course_name']?.toString() ?? '',
      courseCode: j['course_code']?.toString() ?? '',
      courseType: j['course_type']?.toString() ?? '',
      scheduleType: j['schedule_type']?.toString() ?? 'normal',
      expName: j['exp_name']?.toString() ?? '',
      teacher: j['teacher']?.toString() ?? '',
      classroom: j['classroom']?.toString() ?? '',
      dayOfWeek: (j['day_of_week'] as num?)?.toInt() ?? 0,
      startPeriod: (j['start_period'] as num?)?.toInt() ?? 0,
      endPeriod: (j['end_period'] as num?)?.toInt() ?? 0,
      periodLabel: j['period_label']?.toString() ?? '',
      startWeek: startWeek,
      endWeek: endWeek,
      weeks: weeks,
      weekRange: j['week_range']?.toString() ?? '',
      credit: (j['credit'] as num?)?.toDouble() ?? 0,
      isCustom: j['is_custom'] as bool? ?? false,
    );
  }

  /// 解析「1-8周,单周」这类周次描述
  static List<int> _parseWeekText(String text) {
    if (text.trim().isEmpty) return const [];
    final weeks = <int>{};
    for (final part in text.replaceAll('周', '').split(',')) {
      final clean = part.trim();
      if (clean.isEmpty) continue;
      if (clean.contains('-')) {
        final range = clean.replaceAll(RegExp(r'[^\d\-]'), '').split('-');
        if (range.length == 2) {
          final s = int.tryParse(range[0]);
          final e = int.tryParse(range[1]);
          if (s != null && e != null && e >= s) {
            for (var w = s; w <= e; w++) {
              weeks.add(w);
            }
          }
        }
      } else {
        final w = int.tryParse(clean.replaceAll(RegExp(r'\D'), ''));
        if (w != null) weeks.add(w);
      }
    }
    final list = weeks.toList()..sort();
    return list;
  }

  bool get isExperiment => scheduleType == 'experiment';

  bool get hasWeek => weeks.isNotEmpty;

  /// 转为既有 UI 模型
  Course toCourse({String? semester}) {
    final sections = <int>[];
    for (var s = startPeriod; s <= endPeriod && s > 0; s++) {
      sections.add(s);
    }
    // ⚠️ 同一课程必须稳定取到同一颜色：按课程名做哈希，不用列表下标
    // （下标会因课程增删/排序而整体错位，同一门课每学期换色）。
    final colorIndex = colorIndexOf(courseName);
    // 实验课的独立时段（如「下午1」）不占主网格节次，用 label 承载
    final label = periodLabel.trim();
    if (isExperiment && label.isNotEmpty) {
      return Course(
        name: _normalize(courseName),
        teacher: _normalize(teacher),
        position: _normalize(classroom),
        day: dayOfWeek,
        weeks: weeks,
        sections: const [],
        colorIndex: colorIndex,
        tag: '实验',
        remark: _normalize(expName.isNotEmpty ? expName : label),
      );
    }
    return Course(
      name: _normalize(courseName),
      teacher: _normalize(teacher),
      position: _normalize(classroom),
      day: dayOfWeek,
      weeks: weeks,
      sections: sections,
      colorIndex: colorIndex,
      tag: isExperiment ? '实验' : '',
      remark: _normalize(expName),
    );
  }

  static String _normalize(String s) =>
      s.replaceAll(RegExp(r'[\t\r\n\u3000]+'), ' ')
          .replaceAll(RegExp(r' {2,}'), ' ')
          .trim();
}

class BingoCourseResult {
  final List<BingoCourseItem> items;
  final int maxWeek;
  const BingoCourseResult({this.items = const [], this.maxWeek = 20});
}

class BingoCourseSyncStatus {
  final bool syncing;
  final int? lastSync;
  final String? errorMsg;
  final String? stage;
  final String? progressMsg;

  const BingoCourseSyncStatus({
    this.syncing = false,
    this.lastSync,
    this.errorMsg,
    this.stage,
    this.progressMsg,
  });

  factory BingoCourseSyncStatus.fromJson(Map<String, dynamic> j) =>
      BingoCourseSyncStatus(
        syncing: j['syncing'] as bool? ?? false,
        lastSync: (j['last_sync'] as num?)?.toInt(),
        errorMsg: j['error_msg'] as String?,
        stage: j['stage'] as String?,
        progressMsg: j['progress_msg'] as String?,
      );
}

/// 轻量内存缓存（替代 DataCache，避免课表模块再依赖直连相关封装）
class DataCacheHolder {
  DataCacheHolder._();

  static final Map<String, Object> _map = {};

  static T? get<T>(String key) {
    final v = _map[key];
    return v is T ? v : null;
  }

  static void set(String key, Object value) => _map[key] = value;

  static void clear() => _map.clear();
}