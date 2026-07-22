import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/theme_utils.dart';
import '../core/smooth_styles.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'course.dart';
import 'course_service.dart';
import 'course_config.dart';
import 'course_grid.dart';

/// 全校课表查询：先浏览/搜索全校班级，再查看任意班级的周课表
class AllClassSchedulePage extends StatefulWidget {
  final SharedHttpClient client;
  final String? userId;

  const AllClassSchedulePage(
      {super.key, required this.client, this.userId});

  @override
  State<AllClassSchedulePage> createState() => _AllClassSchedulePageState();
}

class _AllClassSchedulePageState extends State<AllClassSchedulePage> {
  late final CourseService _service;
  final CourseTableConfig _config = CourseTableConfig();

  // ---- 列表态 ----
  bool _loadingClasses = true;
  String? _classesError;
  List<SchoolClass> _allClasses = [];
  List<SchoolClass> _filtered = [];
  String _keyword = '';
  String? _collegeFilter;
  List<String> _colleges = [];
  List<SemesterInfo> _semesters = [];
  String _listXnxqdm = '';

  // ---- 详情态 ----
  SchoolClass? _selected;
  bool _loadingSchedule = false;
  String? _scheduleError;
  List<Course> _courses = [];
  List<UnarrangedCourse> _unarranged = [];
  List<ClassCourseChange> _changes = [];
  int _currentWeek = 1;
  int _maxWeek = 20;
  int _todayWeek = 1;
  int _todayDay = 0;
  DateTime _firstMonday = DateTime.now();
  String? _detailXnxqdm;

  @override
  void initState() {
    super.initState();
    _service =
        CourseService(client: widget.client, userId: widget.userId);
    _loadSemestersAndClasses();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadSemestersAndClasses({String? xnxqdm}) async {
    if (xnxqdm != null) _listXnxqdm = xnxqdm;
    if (_listXnxqdm.isEmpty) _listXnxqdm = _service.defaultXnxqdm;
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchSemesters(),
        _service.fetchAllClasses(xnxqdm: _listXnxqdm),
      ]);
      _semesters = results[0] as List<SemesterInfo>;
      _allClasses = results[1] as List<SchoolClass>;
      _colleges = _allClasses
          .map((c) => c.yxmc)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _applyFilter();
    } catch (e) {
      _classesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  void _applyFilter() {
    final kw = _keyword.trim().toLowerCase();
    _filtered = _allClasses.where((c) {
      if (_collegeFilter != null && c.yxmc != _collegeFilter) return false;
      if (kw.isNotEmpty) {
        final hay =
            '${c.bjmc} ${c.zymc} ${c.yxmc} ${c.njDisplay} ${c.nj}'
                .toLowerCase();
        if (!hay.contains(kw)) return false;
      }
      return true;
    }).toList();
    if (mounted) setState(() {});
  }

  Future<void> _openClass(SchoolClass c) async {
    final xnxqdm = _detailXnxqdm ?? _listXnxqdm;
    setState(() {
      _selected = c;
      _loadingSchedule = true;
      _scheduleError = null;
      _courses = [];
      _unarranged = [];
      _changes = [];
    });
    try {
      final results = await Future.wait([
        _service.fetchClassSchedule(bjdm: c.bjdm, xnxqdm: xnxqdm),
        _service.fetchClassUnarranged(bjdm: c.bjdm, xnxqdm: xnxqdm),
        _service.fetchClassChanges(bjdm: c.bjdm, xnxqdm: xnxqdm),
        _service.fetchClassSemesterInfo(xnxqdm),
        _service.fetchClassCurrentWeek(xnxqdm),
      ]);
      final courses = results[0] as List<Course>;
      final unarranged = results[1] as List<UnarrangedCourse>;
      final changes = results[2] as List<ClassCourseChange>;
      final sem = results[3] as ClassSemesterInfo;
      final curWeek = results[4] as int;

      int maxW = sem.totalWeeks > 0 ? sem.totalWeeks : 20;
      for (final crs in courses) {
        for (final w in crs.weeks) {
          if (w > maxW) maxW = w;
        }
      }
      if (curWeek > maxW) maxW = curWeek;

      final today = DateTime.now();
      final todayWeekday = today.weekday;
      final firstMonday = today.subtract(
          Duration(days: (curWeek - 1) * 7 + (todayWeekday - 1)));

      if (mounted) {
        setState(() {
          _courses = courses;
          _unarranged = unarranged;
          _changes = changes;
          _maxWeek = maxW;
          _currentWeek = curWeek;
          _todayWeek = curWeek;
          _todayDay = todayWeekday;
          _firstMonday = firstMonday;
          _loadingSchedule = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scheduleError = e.toString().replaceFirst('Exception: ', '');
          _loadingSchedule = false;
        });
      }
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _selected == null ? _buildList() : _buildDetail(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: _selected != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selected = null),
              tooltip: '返回班级列表',
            )
          : null,
      title: Text(_selected == null ? '全校课表' : _selected!.bjmc),
      centerTitle: true,
      actions: [
        if (_selected == null)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              DataCache().invalidateAll();
              _loadSemestersAndClasses();
            },
            tooltip: '刷新',
          ),
      ],
    );
  }

  // ==================== 列表态 ====================

  Widget _buildList() {
    if (_loadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_classesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载班级列表失败',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_classesError!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSemestersAndClasses,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildListSemesterBar(),
        _buildSearchBar(),
        _buildCollegeChips(),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('没有匹配的班级'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _buildClassCard(_filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildListSemesterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor(context))),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text('学期',
                style: TextStyle(
                    fontSize: 13,
                    color: accentColorNotifier.value
                        .withValues(alpha: 0.6))),
          ),
          Expanded(
            child: SmoothSelect<String>(
              value: _listXnxqdm,
              hint: Text('选择学期',
                  style: TextStyle(
                      color: accentColorNotifier.value
                          .withValues(alpha: 0.4))),
              style: smoothStyle(context),
              highlight: smoothHighlight(context),
              menuMaxHeight: 300,
              items: _semesters.map((s) {
                return SmoothSelectItem<String>(
                  value: s.dm,
                  child: Text(s.mc,
                      style: TextStyle(color: textPrimary(context))),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) _loadSemestersAndClasses(xnxqdm: v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索班级 / 专业 / 学院',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          fillColor: isDark(context)
              ? const Color(0xFF2A2A3E)
              : Colors.grey.shade100,
          filled: true,
        ),
        onChanged: (v) {
          _keyword = v;
          _applyFilter();
        },
      ),
    );
  }

  Widget _buildCollegeChips() {
    final chips = <Widget>[
      _collegeChip('全部', _collegeFilter == null),
    ];
    for (final c in _colleges) {
      chips.add(_collegeChip(c, _collegeFilter == c));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(spacing: 8, children: chips),
    );
  }

  Widget _collegeChip(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _collegeFilter = selected ? null : (label == '全部' ? null : label);
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accentColorNotifier.value
              : accentColorNotifier.value.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(SchoolClass c) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openClass(c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.bjmc,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${c.yxmc} · ${c.zymc} · ${c.njDisplay}',
                      style: TextStyle(
                          fontSize: 12, color: textHint(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.sfypk
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c.sfypk ? '已排课' : '未排课',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.sfypk ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${c.sjrs}/${c.csrs}人',
                      style: TextStyle(
                          fontSize: 12, color: textHint(context))),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 详情态 ====================

  Widget _buildDetail() {
    if (_loadingSchedule) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_scheduleError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('加载班级课表失败',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(_scheduleError!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final weekCourses =
        _courses.where((c) => c.weeks.contains(_currentWeek)).toList();

    return Column(
      children: [
        _buildDetailSemesterBar(),
        CourseWeekBar(
          currentWeek: _currentWeek,
          maxWeek: _maxWeek,
          todayWeek: _todayWeek,
          onJumpToday: () => setState(() => _currentWeek = _todayWeek),
          onPrev: () {
            if (_currentWeek > 1) setState(() => _currentWeek--);
          },
          onNext: () {
            if (_currentWeek < _maxWeek) setState(() => _currentWeek++);
          },
        ),
        Expanded(
          child: ListView(
            children: [
              if (weekCourses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('本周无课程')),
                )
              else
                CourseScheduleGrid(
                  courses: weekCourses,
                  config: _config,
                  currentWeek: _currentWeek,
                  todayWeek: _todayWeek,
                  todayDay: _todayDay,
                  firstMonday: _firstMonday,
                  maxWeek: _maxWeek,
                ),
              if (_unarranged.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('未排课程',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                ..._unarranged.map(_buildUnarrangedCard),
              ],
              if (_changes.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('调停补记录',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                ..._changes.map(_buildChangeCard),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSemesterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor(context))),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text('学期',
                style: TextStyle(
                    fontSize: 13,
                    color: accentColorNotifier.value
                        .withValues(alpha: 0.6))),
          ),
          Expanded(
            child: SmoothSelect<String>(
              value: _detailXnxqdm ?? _listXnxqdm,
              hint: Text('选择学期',
                  style: TextStyle(
                      color: accentColorNotifier.value
                          .withValues(alpha: 0.4))),
              style: smoothStyle(context),
              highlight: smoothHighlight(context),
              menuMaxHeight: 300,
              items: _semesters.map((s) {
                return SmoothSelectItem<String>(
                  value: s.dm,
                  child: Text(s.mc,
                      style: TextStyle(color: textPrimary(context))),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null && _selected != null) {
                  _detailXnxqdm = v;
                  _openClass(_selected!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnarrangedCard(UnarrangedCourse c) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('教师：${c.teacher.isEmpty ? '—' : c.teacher}',
                style: TextStyle(fontSize: 12, color: textHint(context))),
            Text('周次：${c.weekRange.isEmpty ? '—' : c.weekRange}',
                style: TextStyle(fontSize: 12, color: textHint(context))),
            Text(
                '学分：${c.credits.toStringAsFixed(1)}　学时：${c.hours}',
                style: TextStyle(fontSize: 12, color: textHint(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeCard(ClassCourseChange c) {
    final typeColor = c.changeType == '停课'
        ? Colors.red
        : c.changeType == '补课'
            ? Colors.green
            : Colors.orange;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(c.changeType,
                      style: TextStyle(fontSize: 11, color: typeColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.courseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (c.teacher.isNotEmpty)
              Text('教师：${c.teacher}',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            if (c.room.isNotEmpty)
              Text('地点：${c.room}',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            if (c.weekText.isNotEmpty)
              Text('周次：${c.weekText}',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            if (c.sections.isNotEmpty)
              Text('节次：${c.sectionRangesCompact}',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
          ],
        ),
      ),
    );
  }
}
