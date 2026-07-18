import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/smooth_styles.dart';
import '../core/theme_utils.dart';
import 'course.dart';
import 'course_service.dart';
import 'course_config.dart';
import 'course_config_page.dart';
import 'course_changes_page.dart';
import '../main.dart';
import '../core/navigation.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 从当前主题色生成 12 级课程卡片色阶，若配置了自定义颜色则优先使用
List<Color> _generateCourseColors(CourseTableConfig? config) {
  if (config != null && config.customColors.length >= 12) {
    return config.customColors;
  }
  final base = accentColorNotifier.value;
  return List.generate(12, (i) {
    final t = i / 11;
    return Color.lerp(base, Colors.white, t * 0.55)!;
  });
}class CourseTablePage extends StatefulWidget {
  final SharedHttpClient client;
  final String? userId;

  const CourseTablePage({super.key, required this.client, this.userId});

  @override
  State<CourseTablePage> createState() => _CourseTablePageState();
}

class _CourseTablePageState extends State<CourseTablePage> {
  // ---- 服务 ----
  late final CourseService _service;

  // ---- 配置 ----
  CourseTableConfig _config = CourseTableConfig();

  // ---- 数据 ----
  List<Course>? _courses;
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

  static const _dayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _service = CourseService(
      client: widget.client,
      userId: widget.userId,
    );
    _todayDay = DateTime.now().weekday;
    _loadConfig();
    _loadAll();
  }

  Future<void> _loadConfig() async {
    final cfg = await CourseTableConfig.load();
    if (mounted) setState(() => _config = cfg);
  }

  void _openConfig() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _buildConfigSheet(sheetContext),
    );
  }

  Widget _buildConfigSheet(BuildContext sheetContext) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        void update() {
          _config.save();
          setState(() {});
          setSheetState(() {});
        }

        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.40,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // 拖动条
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textHint(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('课程表设置',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _cfgSection('布局'),
                  const SizedBox(height: 6),
                  _cfgSwitch('显示调课入口', '在顶部栏显示「调课」按钮',
                      _config.showChangesButton, (v) {
                    _config.showChangesButton = v;
                    update();
                  }),
                  const SizedBox(height: 20),
                  _cfgSection('显示'),
                  const SizedBox(height: 6),
                  _cfgSwitch('隐藏时间段', '隐藏左侧节次标签列',
                      _config.hideTimeLabels, (v) {
                    _config.hideTimeLabels = v;
                    update();
                  }),
                  const SizedBox(height: 6),
                  _cfgSwitch('隐藏日期', '隐藏表头的日期文字', _config.hideDate,
                      (v) {
                    _config.hideDate = v;
                    update();
                  }),
                  const SizedBox(height: 6),
                  _cfgSwitch('显示网格线', '显示单元格边框分隔线',
                      _config.showGridLines, (v) {
                    _config.showGridLines = v;
                    update();
                  }),
                  const SizedBox(height: 6),
                  _cfgSwitch('隐藏教师', '隐藏卡片上的教师姓名',
                      _config.hideTeacher, (v) {
                    _config.hideTeacher = v;
                    update();
                  }),
                  const SizedBox(height: 20),
                  _cfgSection('尺寸'),
                  const SizedBox(height: 6),
                  _cfgSlider(
                      '单元格高度: ${_config.cellHeight.toInt()}px',
                      _config.cellHeight, 80, 200, (v) {
                    _config.cellHeight = v;
                    update();
                  }),
                  const SizedBox(height: 6),
                  _cfgSlider(
                      '头部高度: ${_config.headerHeight.toInt()}px',
                      _config.headerHeight, 35, 60, (v) {
                    _config.headerHeight = v;
                    update();
                  }),
                  const SizedBox(height: 6),
                  _cfgSlider(
                      '文字缩放: ${_config.textScale.toStringAsFixed(2)}x',
                      _config.textScale, 0.7, 1.5, (v) {
                    _config.textScale = v;
                    update();
                  }, divisions: 8),
                  const SizedBox(height: 20),
                  _cfgSection('样式'),
                  const SizedBox(height: 6),
                  _cfgSlider(
                      '圆角半径: ${_config.cardRadius.toInt()}px',
                      _config.cardRadius, 0, 16, (v) {
                    _config.cardRadius = v;
                    update();
                  }),
                  const SizedBox(height: 20),
                  _cfgSection('课程颜色'),
                  const SizedBox(height: 6),
                  _cfgColorGrid(update),
                  const SizedBox(height: 20),
                ],
              ),     // ListView
            );       // Container
        },         // StatefulBuilder builder
      );           // StatefulBuilder
  }

  Widget _cfgSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary(context),
        ),
      ),
    );
  }

  Widget _cfgSwitch(
      String label, String? subtitle, bool value, ValueChanged<bool> onChanged) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColorNotifier.value.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle,
                          style: TextStyle(
                              fontSize: 11, color: textHint(context))),
                    ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: accentColorNotifier.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cfgSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColorNotifier.value.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions:
                  divisions ?? ((max - min) / 1).round().clamp(1, 200),
              onChanged: onChanged,
              activeColor: accentColorNotifier.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cfgColorGrid(VoidCallback update) {
    final colors = _config.customColors;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: accentColorNotifier.value.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('课程卡片配色（点击换色，长按恢复默认）',
                style: TextStyle(fontSize: 12, color: textHint(context))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(12, (i) {
                final color = colors[i];
                return GestureDetector(
                  onTap: () => _pickConfigColor(i, update),
                  onLongPress: () {
                    colors[i] = CourseTableConfig.defaultColors[i];
                    update();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickConfigColor(int index, VoidCallback update) async {
    final initial = _config.customColors[index];
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPickerDialog(initialColor: initial),
    );
    if (result != null && mounted) {
      _config.customColors[index] = result;
      update();
    }
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

      // 并行获取课表 + 当前周 + 实验教学（传入学期代码以获取准确日期）
      final results = await Future.wait([
        _service.fetchCourses(xnxqdm: activeSemester),
        _service.fetchCurrentWeek(xnxqdm: activeSemester),
        _service.fetchExperiments(xnxqdm: activeSemester),
      ]);

      if (!mounted) return;

      final courses = results[0] as List<Course>;
      final weekInfo = results[1] as CurrentWeekInfo;
      final experiments = results[2] as List<Course>;
      final currentWeek = weekInfo.week;

      // 合并实验教学到课程表
      final allCourses = [...courses, ...experiments];

      // 计算最大周次
      int maxW = 1;
      for (final c in allCourses) {
        for (final w in c.weeks) {
          if (w > maxW) maxW = w;
        }
      }

      setState(() {
        _courses = allCourses;
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

  void _openChangesPage() {
    pushPage(context, CourseChangesPage(
      service: _service,
      semesters: _semesters,
      initialSemester: _selectedSemester,
    ));
  }

  void _jumpToToday() {
    setState(() => _currentWeek = _todayWeek);
  }

  void _showCourseDetail(Course course) {
    final dayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final tagColor = course.tag.isNotEmpty
            ? (course.tag == '实验'
                ? Colors.orange.shade500
                : accentColorNotifier.value)
            : null;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: textHint(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  if (course.tag.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(course.tag,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  Expanded(
                    child: Text(course.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (course.teacher.isNotEmpty)
                _detailRow(Icons.person_outline, course.teacher),
              if (course.position.isNotEmpty)
                _detailRow(Icons.room_outlined, course.position),
              _detailRow(Icons.schedule_outlined,
                  '周${dayLabels[course.day]}  ${course.sectionRangesCompact}'),
              _detailRow(Icons.date_range_outlined, course.weeksDisplay),
              if (course.remark.isNotEmpty)
                _detailRow(Icons.notes_rounded, course.remark),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textHint(context)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text,
                style: TextStyle(fontSize: 14, color: textPrimary(context))),
          ),
        ],
      ),
    );
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
        _service.fetchExperiments(xnxqdm: xnxqdm, forceRefresh: true),
      ]);
      if (!mounted) return;

      final courses = results[0] as List<Course>;
      final weekInfo = results[1] as CurrentWeekInfo;
      final experiments = results[2] as List<Course>;
      final allCourses = [...courses, ...experiments];

      // 重新计算最大周次
      int maxW = 1;
      for (final c in allCourses) {
        for (final w in c.weeks) {
          if (w > maxW) maxW = w;
        }
      }

      setState(() {
        _courses = allCourses;
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
    return SimplePage(
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
        if (!_isLoading && _courses != null) ...[
          if (_config.showChangesButton)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: _openChangesPage,
              tooltip: '调课 & 未安排课程',
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openConfig,
            tooltip: '课程表设置',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { DataCache().invalidateAll(); _loadAll(); },
            tooltip: '刷新',
          ),
        ],
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
        color: accentColorNotifier.value.withValues(alpha: isDark(context) ? 0.08 : 0.04),
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
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return accentColorNotifier.value.withValues(alpha: 0.12);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return accentColorNotifier.value;
                  }
                  return textHint(context);
                }),
              ),
            ),
          ),
        ],
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
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text('学期', style: TextStyle(fontSize: 13, color: accentColorNotifier.value.withValues(alpha: 0.6))),
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
                hint: Text('选择学期', style: TextStyle(color: accentColorNotifier.value.withValues(alpha: 0.4))),
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

    final cfg = _config;
    final cColors = _generateCourseColors(cfg);
    final cellH = cfg.cellHeight;
    final headH = cfg.headerHeight;
    final showTimeCol = !cfg.hideTimeLabels;
    final timeColWidth = showTimeCol ? 44.0 : 8.0;
    final showDates = !cfg.hideDate;
    final showGrid = cfg.showGridLines;
    final textScale = cfg.textScale;

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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: LayoutBuilder(
          key: ValueKey('week_$_currentWeek'),
          builder: (context, constraints) {
            final dayWidth = (constraints.maxWidth - timeColWidth) / 7;
            final totalWidth = timeColWidth + dayWidth * 7;
            final gridHeight = maxSection * cellH;

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    // 表头：星期 + 日期
                    _buildWeekHeader(
                      dayWidth, headH, showTimeCol, timeColWidth,
                      showDates, showGrid, textScale,
                    ),
                    // 网格背景 + 课程卡片（Stack 布局）
                    SizedBox(
                      height: gridHeight,
                      child: Stack(
                        children: [
                          // 背景网格行
                          Column(
                            children: List.generate(maxSection, (rowIdx) {
                              final period = rowIdx + 1;
                              return _buildGridRow(
                                period, dayWidth, cellH, showTimeCol,
                                timeColWidth, showGrid, textScale,
                              );
                            }),
                          ),
                          // 课程卡片（按 sections 跨行定位）
                          ...weekCourses.map((course) {
                            final firstSec = course.sections.isNotEmpty
                                ? course.sections.first
                                : 1;
                            final lastSec = course.sections.isNotEmpty
                                ? course.sections.last
                                : firstSec;
                            final sectionCount = lastSec - firstSec + 1;
                            final dayIdx = course.day - 1;
                            if (dayIdx < 0 || dayIdx > 6) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: timeColWidth + dayIdx * dayWidth,
                              top: (firstSec - 1) * cellH,
                              width: dayWidth,
                              height: sectionCount * cellH,
                              child: _buildCourseCard(course, cColors),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建周课表表头行（星期 + 日期）
  Widget _buildWeekHeader(
    double dayWidth,
    double headH,
    bool showTimeCol,
    double timeColWidth,
    bool showDates,
    bool showGrid,
    double textScale,
  ) {
    return Row(
      children: [
        if (showTimeCol)
          Container(
            width: timeColWidth,
            height: headH,
            decoration: BoxDecoration(
              color: accentColorNotifier.value.withValues(alpha: 0.06),
              border: showGrid
                  ? Border.all(
                      color: isDark(context)
                          ? const Color(0xFF4A4A5E)
                          : Colors.grey.shade300,
                      width: 0.5)
                  : null,
            ),
            child: Center(
                child: Text('节次',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11))),
          ),
        ...List.generate(7, (i) {
          final day = i + 1;
          final isToday =
              _todayWeek == _currentWeek && day == _todayDay;
          final isWeekend = i >= 5;
          final date = _getDateForWeekday(day, _currentWeek);

          return Expanded(
            child: SizedBox(
              height: headH,
              child: Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context).colorScheme.primaryContainer
                      : accentColorNotifier.value
                          .withValues(alpha: 0.06),
                  border: showGrid
                      ? Border.all(
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : isDark(context)
                                  ? const Color(0xFF4A4A5E)
                                  : Colors.grey.shade300,
                          width: isToday ? 1.5 : 0.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '周${_dayLabels[day]}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13 * textScale,
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : isWeekend
                                ? textHint(context)
                                : textPrimary(context),
                      ),
                    ),
                    if (showDates && date != null)
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 9 * textScale,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 构建一节次背景行（左侧时间标签 + 7 天空单元格）
  Widget _buildGridRow(
    int period,
    double dayWidth,
    double cellH,
    bool showTimeCol,
    double timeColWidth,
    bool showGrid,
    double textScale,
  ) {
    final unifiedBg = accentColorNotifier.value.withValues(alpha: 0.06);
    return SizedBox(
      height: cellH,
      child: Row(
        children: [
          if (showTimeCol)
            Container(
              width: timeColWidth,
              height: cellH,
              decoration: BoxDecoration(
                color: unifiedBg,
                border: showGrid
                    ? Border.all(
                        color: isDark(context)
                            ? const Color(0xFF4A4A5E)
                            : Colors.grey.shade300,
                        width: 0.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '第$period节',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10 * textScale, height: 1.2),
                ),
              ),
            ),
          ...List.generate(7, (dayIdx) {
            final day = dayIdx + 1;
            final isToday =
                _todayWeek == _currentWeek && day == _todayDay;
            return Expanded(
              child: Container(
                height: cellH,
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35)
                      : null,
                  border: showGrid
                      ? Border.all(
                          color: isDark(context)
                              ? const Color(0xFF4A4A5E)
                              : Colors.grey.shade300,
                          width: 0.5)
                      : isToday
                          ? Border(
                              bottom: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                width: 0.5,
                              ),
                            )
                          : const Border(
                              bottom: BorderSide(
                                  color: Colors.transparent,
                                  width: 0),
                            ),
                ),
              ),
            );
          }),
        ],
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

  Widget _buildCourseCard(Course course, List<Color> cColors) {
    final color = cColors[course.colorIndex % cColors.length];
    final cfg = _config;
    final ts = cfg.textScale;
    final radius = cfg.cardRadius;
    final hideTeacher = cfg.hideTeacher;
    final showTag = course.tag.isNotEmpty;

    // 磨玻璃效果：半透明彩色背景 + 高斯模糊 + 描边
    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _showCourseDetail(course),
          child: Padding(
            padding: EdgeInsets.all(radius > 0 ? 4 : 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showTag)
                  Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 0),
                    decoration: BoxDecoration(
                      color: tagBadgeColor(course.tag),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      course.tag,
                      style: TextStyle(
                          fontSize: 7 * ts,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.3),
                    ),
                  ),
                const SizedBox(height: 1),
                Text(
                  course.name,
                  style: TextStyle(
                    fontSize: 11 * ts,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (!hideTeacher && course.teacher.isNotEmpty)
                  Text(
                    course.teacher,
                    style: TextStyle(
                      fontSize: 8 * ts,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                if (course.position.isNotEmpty)
                  Text(
                    course.position,
                    style: TextStyle(
                        fontSize: 8 * ts,
                        color: Colors.white.withValues(alpha: 0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // 磨玻璃效果：用 BackdropFilter 添加模糊
    if (radius > 0) {
      cardBody = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: cardBody,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(radius > 0 ? 1.5 : 1),
      child: cardBody,
    );
  }

  /// 根据 tag 返回标签底色
  Color tagBadgeColor(String tag) {
    switch (tag) {
      case '实验':
        return Colors.orange.shade500;
      default:
        return accentColorNotifier.value;
    }
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

      // 同一天 + 相同课程名 + 相同教师 + 相同类型（实验/普通）→ 合并
      // 合并后节次/周次/教室都取并集，理论课和实验课天然按 tag 分开
      final merged = _mergeSameCourses(dayCourses);

      final isWeekend = day >= 6;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColorNotifier.value.withValues(alpha: 0.06),
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

      for (final course in merged) {
        widgets.add(TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _buildSemesterCourseCard(course),
        ));
      }
    }

    return widgets;
  }

  /// 同一天内，将「课程名+教师+类型」相同的多个时间片合并为一张卡片。
  ///
  /// 合并后：
  /// - sections: 所有节次并集（去重 + 排序）
  /// - weeks: 所有周次并集（去重 + 排序）
  /// - position: 全部去重后用「、」拼接
  /// - teacher/remark: 取第一个
  /// - tag/colorIndex: 不变（理论课和实验课 tag 不同会天然分开）
  List<Course> _mergeSameCourses(List<Course> courses) {
    final groups = <String, List<Course>>{};
    for (final c in courses) {
      final key = '${c.name}|${c.teacher}|${c.tag}';
      groups.putIfAbsent(key, () => []).add(c);
    }

    return groups.values.map((group) {
      if (group.length == 1) return group.first;
      final first = group.first;
      final allSections = <int>{};
      final allWeeks = <int>{};
      final positions = <String>{};
      for (final c in group) {
        allSections.addAll(c.sections);
        allWeeks.addAll(c.weeks);
        if (c.position.isNotEmpty) positions.add(c.position);
      }
      return Course(
        name: first.name,
        teacher: first.teacher,
        position: positions.join('、'),
        day: first.day,
        weeks: allWeeks.toList()..sort(),
        sections: allSections.toList()..sort(),
        colorIndex: first.colorIndex,
        tag: first.tag,
        remark: first.remark,
      );
    }).toList();
  }

  Widget _buildSemesterCourseCard(Course course) {
    final cfg = _config;
    final cColors = _generateCourseColors(cfg);
    final color = cColors[course.colorIndex % cColors.length];
    final ts = cfg.textScale;
    final radius = cfg.cardRadius;
    final hideTeacher = cfg.hideTeacher;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius > 0 ? radius : 4),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: radius > 0 ? 1 : 0,
      child: InkWell(
        onTap: () => _showCourseDetail(course),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (course.tag.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: tagBadgeColor(course.tag),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            course.tag,
                            style: TextStyle(
                              fontSize: 10 * ts,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          course.name,
                          style: TextStyle(
                            fontSize: 15 * ts,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!hideTeacher && course.teacher.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person,
                            size: 14 * ts, color: textHint(context)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(course.teacher,
                              style: TextStyle(
                                  fontSize: 12 * ts,
                                  color: textHint(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  if (course.position.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.room,
                            size: 14 * ts, color: textHint(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(course.position,
                              style: TextStyle(
                                  fontSize: 12 * ts,
                                  color: textHint(context))),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14 * ts, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${course.sectionRangesCompact}  ${course.weeksDisplay}',
                          style: TextStyle(fontSize: 12 * ts, color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),     // Row
      ),       // Padding
    ),         // InkWell
    );         // Card   
  }




}
