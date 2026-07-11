import 'package:flutter/material.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/smooth_styles.dart';
import '../core/theme_utils.dart';
import 'course.dart';
import 'course_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class CourseTablePage extends StatefulWidget {
  final SharedHttpClient client;
  final String? userId;

  const CourseTablePage({super.key, required this.client, this.userId});

  @override
  State<CourseTablePage> createState() => _CourseTablePageState();
}

class _CourseTablePageState extends State<CourseTablePage> {
  // ---- 服务 ----
  late final CourseService _service;

  // ---- 数据 ----
  List<Course>? _courses;
  List<CourseChange> _courseChanges = [];
  List<UnarrangedCourse> _unarrangedCourses = [];
  List<SemesterInfo> _semesters = [];
  int _currentWeek = 1;
  int _maxWeek = 1;
  int _todayWeek = 1;
  int _todayDay = 0; // 今天是星期几（1-7）
  DateTime _firstMonday = DateTime.now(); // 学期第一周周一

  // ---- 视图状态 ----
  bool _isLoading = true;
  String? _error;
  bool _isWeeklyView = true;
  String? _selectedSemester;
  bool _isLoadingSemester = false;
  bool _showCourseChanges = false;
  bool _showUnarranged = false;

  static const _dayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _service = CourseService(
      client: widget.client,
      userId: widget.userId,
    );
    _todayDay = DateTime.now().weekday; // 1=Mon, 7=Sun
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 先获取学期列表，得到当前学期代码
      final semesters = await _service.fetchSemesters();

      // 确定当前学期（基于今天日期计算当前应处的学期代码）
      String? activeSemester;
      if (semesters.isNotEmpty) {
        final now = DateTime.now();
        final currentDm = now.month >= 2 && now.month <= 7
            ? '${now.year - 1}-${now.year}-2'
            : now.month >= 8
                ? '${now.year}-${now.year + 1}-1'
                : '${now.year - 1}-${now.year}-1';
        // 优先匹配计算出的当前学期
        final matched = semesters.where((s) => s.dm == currentDm).firstOrNull;
        if (matched != null) {
          activeSemester = matched.dm;
        } else {
          // 回退：isActive 标记，再回退到列表第一个
          final active = semesters.where((s) => s.isActive).firstOrNull;
          activeSemester = active?.dm ?? semesters.first.dm;
        }
      }

      // 并行获取课表 + 当前周（传入学期代码以获取准确日期）
      final results = await Future.wait([
        _service.fetchCourses(xnxqdm: activeSemester),
        _service.fetchCurrentWeek(xnxqdm: activeSemester),
      ]);

      if (!mounted) return;

      final courses = results[0] as List<Course>;
      final weekInfo = results[1] as CurrentWeekInfo;
      final currentWeek = weekInfo.week;

      // 计算最大周次
      int maxW = 1;
      for (final c in courses) {
        for (final w in c.weeks) {
          if (w > maxW) maxW = w;
        }
      }

      setState(() {
        _courses = courses;
        _currentWeek = currentWeek;
        _todayWeek = currentWeek;
        _firstMonday = weekInfo.firstMonday;
        _maxWeek = maxW;
        _semesters = semesters;
        _selectedSemester = activeSemester;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCourseChanges() async {
    final show = !_showCourseChanges;
    setState(() => _showCourseChanges = show);
    if (show && _courseChanges.isEmpty) {
      try {
        final changes = await _service.fetchCourseChanges();
        if (mounted) {
          setState(() => _courseChanges = changes);
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleUnarranged() async {
    final show = !_showUnarranged;
    setState(() => _showUnarranged = show);
    if (show && _unarrangedCourses.isEmpty) {
      try {
        final courses = await _service.fetchUnarrangedCourses();
        if (mounted) {
          setState(() => _unarrangedCourses = courses);
        }
      } catch (_) {}
    }
  }

  void _jumpToToday() {
    setState(() => _currentWeek = _todayWeek);
  }

  /// 切换学期，重新加载课表
  Future<void> _switchSemester(String xnxqdm) async {
    setState(() {
      _selectedSemester = xnxqdm;
      _isLoadingSemester = true;
    });

    try {
      final results = await Future.wait([
        _service.fetchCourses(xnxqdm: xnxqdm),
        _service.fetchCurrentWeek(xnxqdm: xnxqdm, forceRefresh: true),
      ]);
      if (!mounted) return;

      final courses = results[0] as List<Course>;
      final weekInfo = results[1] as CurrentWeekInfo;

      // 重新计算最大周次
      int maxW = 1;
      for (final c in courses) {
        for (final w in c.weeks) {
          if (w > maxW) maxW = w;
        }
      }

      setState(() {
        _courses = courses;
        _maxWeek = maxW;
        _currentWeek = 1;
        _firstMonday = weekInfo.firstMonday;
        _isLoadingSemester = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSemester = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载学期课表失败: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('课程表'),
      centerTitle: true,
      actions: [
        if (!_isLoading && _courses != null)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { DataCache().invalidateAll(); _loadAll(); },
            tooltip: '刷新',
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _buildToggleBar(),
      ),
    );
  }

  Widget _buildToggleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: dividerColor(context)),
        ),
      ),
      child: Row(
        children: [
          // 周课表 / 学期课表 切换
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('周课表', style: TextStyle(fontSize: 13))),
                ButtonSegment(value: false, label: Text('学期课表', style: TextStyle(fontSize: 13))),
              ],
              selected: {_isWeeklyView},
              onSelectionChanged: (v) => setState(() => _isWeeklyView = v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 调课信息 toggle
          _buildToggleChip(
            label: '调课',
            icon: Icons.swap_horiz,
            selected: _showCourseChanges,
            onTap: _toggleCourseChanges,
          ),
          const SizedBox(width: 4),
          // 未安排课程 toggle
          _buildToggleChip(
            label: '未安排',
            icon: Icons.unpublished,
            selected: _showUnarranged,
            onTap: _toggleUnarranged,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : isDark(context) ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : isDark(context) ? const Color(0xFF4A4A5E) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Theme.of(context).colorScheme.primary : textHint(context)),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: 11, color: selected ? Theme.of(context).colorScheme.primary : textHint(context))),
          ],
        ),
      ),
    );
  }

  // ==================== BODY ====================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('获取课程表失败',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () { DataCache().invalidateAll(); _loadAll(); },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses == null || _courses!.isEmpty) {
      return const Center(
        child: Text('暂无课程数据', style: TextStyle(fontSize: 16)),
      );
    }

    return Column(
      children: [
        // 顶部工具条
        _isWeeklyView ? _buildWeekBar() : _buildSemesterBar(),
        // 主内容
        Expanded(
          child: _isWeeklyView ? _buildWeeklyView() : _buildSemesterView(),
        ),
        // 底部额外信息
        if (!_isWeeklyView && (_showCourseChanges || _showUnarranged))
          _buildExtraInfoPanel(),
      ],
    );
  }

  // ==================== 周课表工具条 ====================

  Widget _buildWeekBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor(context))),
      ),
      child: Row(
        children: [
          Text('第 $_currentWeek 周', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          if (_currentWeek != _todayWeek)
            GestureDetector(
              onTap: _jumpToToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('回到本周', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _currentWeek > 1 ? () => setState(() => _currentWeek--) : null,
            child: Icon(Icons.chevron_left, size: 20, color: _currentWeek > 1 ? textSecondary(context) : isDark(context) ? const Color(0xFF4A4A5E) : Colors.grey.shade300),
          ),
          Text('$_currentWeek/$_maxWeek', style: TextStyle(color: textSecondary(context))),
          GestureDetector(
            onTap: _currentWeek < _maxWeek ? () => setState(() => _currentWeek++) : null,
            child: Icon(Icons.chevron_right, size: 20, color: _currentWeek < _maxWeek ? textSecondary(context) : isDark(context) ? const Color(0xFF4A4A5E) : Colors.grey.shade300),
          ),
        ],
      ),
    );
  }

  // ==================== 学期课表工具条 ====================

  Widget _buildSemesterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor(context))),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 8),
            child: Text('学期', style: TextStyle(fontSize: 13, color: Color(0x99191999))),
          ),
          if (_isLoadingSemester)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Expanded(
              child: SmoothSelect<String>(
                value: _selectedSemester,
                hint: const Text('选择学期', style: TextStyle(color: Color(0x66191999))),
                style: smoothStyle(context),
                highlight: smoothHighlight(context),
                menuMaxHeight: 300,
                items: _semesters.map((s) {
                  return SmoothSelectItem<String>(
                    value: s.dm,
                    child: Text(s.mc, style: TextStyle(color: textPrimary(context))),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) _switchSemester(v);
                },
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 周课表视图 ====================

  Widget _buildWeeklyView() {
    final weekCourses =
        _courses!.where((c) => c.weeks.contains(_currentWeek)).toList();
    return _buildWeekContent(weekCourses);
  }

  // ---- 滑动切换周次 ----
  double? _swipeStartX;

  Widget _buildWeekContent(List<Course> weekCourses) {

    // 计算最大节次
    int maxSection = 12;
    for (final c in weekCourses) {
      for (final s in c.sections) {
        if (s > maxSection) maxSection = s;
      }
    }

    return Listener(
      onPointerDown: (event) {
        _swipeStartX = event.position.dx;
      },
      onPointerUp: (event) {
        if (_swipeStartX == null) return;
        final dx = event.position.dx - _swipeStartX!;
        _swipeStartX = null;
        if (dx.abs() < 50) return;
        if (dx < 0 && _currentWeek < _maxWeek) {
          setState(() => _currentWeek++);
        } else if (dx > 0 && _currentWeek > 1) {
          setState(() => _currentWeek--);
        }
      },
      child: Cue.onChange(
        value: _currentWeek,
        motion: .smooth(),
        fromCurrentValue: true,
        acts: [.fadeIn()],
        child: LayoutBuilder(
          key: ValueKey('week_$_currentWeek'),
      builder: (context, constraints) {
        final dayWidth = (constraints.maxWidth - 44) / 7;
        const rowHeight = 120.0;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: ClipRect(
            child: SizedBox(
            width: 44 + dayWidth * 7,
              child: Column(
                children: [
                  // 表头：星期 + 日期
                  Row(
                    children: [
                      const SizedBox(
                        width: 44,
                        height: 42,
                        child: Center(
                            child: Text('节次',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11))),
                      ),
                      ...List.generate(7, (i) {
                        final day = i + 1;
                        final isToday = _todayWeek == _currentWeek && day == _todayDay;
                        final isWeekend = i >= 5;
                        final date = _getDateForWeekday(day, _currentWeek);

                        return Expanded(
                          child: SizedBox(
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : isWeekend
                                      ? isDark(context) ? const Color(0xFF2A2A3E) : Colors.grey.shade100
                                      : _yibinBlue.withValues(alpha: 0.06),
                              border: Border.all(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : isDark(context) ? const Color(0xFF4A4A5E) : Colors.grey.shade300,
                                  width: isToday ? 1.5 : 0.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '周${_dayLabels[day]}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : isWeekend
                                            ? textHint(context)
                                            : textPrimary(context),
                                  ),
                                ),
                                if (date != null)
                                  Text(
                                    date,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isToday
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).scaffoldBackgroundColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ));
                      }),
                    ],
                  ),
                  // 行：每节课
                  ...List.generate(maxSection, (rowIdx) {
                    final period = rowIdx + 1;
                    final isOdd = period.isOdd;

                    return SizedBox(
                      height: rowHeight,
                      child: Row(
                        children: [
                          // 左侧节次标签
                          SizedBox(
                            width: 44,
                            height: rowHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isOdd
                                    ? Theme.of(context).scaffoldBackgroundColor
                                    : Colors.white,
                                border: Border.all(
                                    color: isDark(context) ? const Color(0xFF4A4A5E) : Colors.grey.shade300, width: 0.5),
                              ),
                              child: Center(
                                child: Text(
                                  '$period\n${formatPeriodTime(period, short: true)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 10, height: 1.2),
                                ),
                              ),
                            ),
                          ),
                          // 每天该节次的课程
                          ...List.generate(7, (dayIdx) {
                            final day = dayIdx + 1;
                            final coursesInCell = weekCourses
                                .where((c) =>
                                    c.day == day &&
                                    c.sections.contains(period))
                                .toList();

                            return Expanded(
                              child: SizedBox(
                              height: rowHeight,
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minHeight: rowHeight,
                                maxHeight: double.infinity,
                                child: Container(
                                decoration: BoxDecoration(
                                  color: (_todayWeek == _currentWeek &&
                                          day == _todayDay)
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.3)
                                      : null,
                                  border: Border.all(
                                      color: isDark(context) ? const Color(0xFF4A4A5E) : Colors.grey.shade300,
                                      width: 0.5),
                                ),
                                child: coursesInCell.isEmpty
                                    ? null
                                    : _buildCourseCard(
                                        coursesInCell.first, dayWidth),
                              ),
                            ),
                            ));
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
      ),
    ),
  );
}

  /// 根据周次和星期计算日期字符串（基于 API 返回的学期起始日期）
  String? _getDateForWeekday(int weekday, int week) {
    try {
      final targetDate =
          _firstMonday.add(Duration(days: (week - 1) * 7 + (weekday - 1)));
      return '${targetDate.month}/${targetDate.day}';
    } catch (_) {
      return null;
    }
  }

  Widget _buildCourseCard(Course course, double width) {
    final color = Color(courseColors[course.colorIndex % courseColors.length]);

    return Container(
      width: width,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            course.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (course.position.isNotEmpty)
            Text(
              course.position,
              style: TextStyle(
                  fontSize: 9, color: color.withValues(alpha: 0.8)),
            ),
        ],
      ),
    );
  }

  // ==================== 学期课表视图 ====================

  Widget _buildSemesterView() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 学期课程总览卡片
        ..._buildSemesterCourseCards(),
      ],
    );
  }

  List<Widget> _buildSemesterCourseCards() {
    if (_courses == null || _courses!.isEmpty) {
      return [
        const Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无课程数据', style: TextStyle(fontSize: 16)),
        )),
      ];
    }

    // 按星期分组
    final byDay = <int, List<Course>>{};
    for (final c in _courses!) {
      if (c.day >= 1 && c.day <= 7) {
        byDay.putIfAbsent(c.day, () => []).add(c);
      }
    }

    final widgets = <Widget>[];
    // 标题
    widgets.add(Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        '共 ${_courses!.length} 门课程',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    ));

    for (int day = 1; day <= 7; day++) {
      final dayCourses = byDay[day] ?? [];
      if (dayCourses.isEmpty) continue;

      final isWeekend = day >= 6;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isWeekend ? isDark(context) ? const Color(0xFF2A2A3E) : Colors.grey.shade100 : _yibinBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '周${_dayLabels[day]}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isWeekend ? textHint(context) : textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ));

      for (final course in dayCourses) {
        widgets.add(Cue.onMount(
          motion: .smooth(),
          acts: [.fadeIn(), .slideY(from: 0.08)],
          child: _buildSemesterCourseCard(course),
        ));
      }
    }

    return widgets;
  }

  Widget _buildSemesterCourseCard(Course course) {
    final color = Color(courseColors[course.colorIndex % courseColors.length]);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧色条
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // 课程信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: textHint(context)),
                      const SizedBox(width: 4),
                      Text(course.teacher,
                          style: TextStyle(fontSize: 12, color: textHint(context))),
                    ],
                  ),
                  if (course.position.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.room, size: 14, color: textHint(context)),
                        const SizedBox(width: 4),
                        Text(course.position,
                            style: TextStyle(fontSize: 12, color: textHint(context))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '${course.sectionRange}  ${course.weeksDisplay}',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 额外信息面板 ====================

  Widget _buildExtraInfoPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: dividerColor(context))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        shrinkWrap: true,
        children: [
          if (_showCourseChanges && _courseChanges.isNotEmpty) ...[
            _buildSectionTitle('调课/停课信息', Icons.swap_horiz, Colors.orange),
            ..._courseChanges.map((c) => _buildChangeCard(c)),
          ],
          if (_showUnarranged && _unarrangedCourses.isNotEmpty) ...[
            _buildSectionTitle('未安排课程', Icons.unpublished, textHint(context)),
            ..._unarrangedCourses.map((c) => _buildUnarrangedCard(c)),
          ],
          if ((_showCourseChanges && _courseChanges.isEmpty) ||
              (_showUnarranged && _unarrangedCourses.isEmpty))
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('暂无数据', style: TextStyle(color: textHint(context)))),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildChangeCard(CourseChange change) {
    final color = change.isSuspended ? Colors.red : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(change.changeType,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(change.courseName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (change.isSuspended) ...[
              _buildChangeRow('原安排', change.originalWeekText, change.originalDay,
                  change.originalStartPeriod, change.originalEndPeriod, change.originalRoom),
            ] else ...[
              _buildChangeRow('原安排', change.originalWeekText, change.originalDay,
                  change.originalStartPeriod, change.originalEndPeriod, change.originalRoom),
              _buildChangeRow('新安排', change.newWeekText, change.newDay,
                  change.newStartPeriod, change.newEndPeriod, change.newRoom,
                  isNew: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChangeRow(String label, String weekText, int day,
      int startPeriod, int endPeriod, String room,
      {bool isNew = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isNew ? Colors.green : textHint(context),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              '周${_dayLabels[day]} ${startPeriod}-${endPeriod}节 ${formatPeriodTime(startPeriod)} '
              '${weekText.isNotEmpty ? weekText : ''}'
              '${room.isNotEmpty ? ' $room' : ''}',
              style: TextStyle(fontSize: 11, color: isNew ? Colors.green.shade700 : textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnarrangedCard(UnarrangedCourse course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('教师: ${course.teacher}  学分: ${course.credits}  学时: ${course.hours}',
                      style: TextStyle(fontSize: 11, color: textHint(context))),
                  if (course.weekRange.isNotEmpty)
                    Text('周次: ${course.weekRange}',
                        style: TextStyle(fontSize: 11, color: textHint(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
