import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';
import 'dart:convert';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/smooth_styles.dart';
import '../core/theme_utils.dart';
import '../core/local_storage.dart';
import 'course.dart';
import 'course_service.dart';
import 'course_grid.dart';
import 'course_config.dart';
import 'course_config_page.dart';
import 'course_changes_page.dart';
import 'course_semester_view.dart';
import '../main.dart';
import '../core/navigation.dart';
import '../core/simple_page.dart';
import '../core/glass_category_bar.dart';
import '../widget/widget_service.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 从当前主题色生成 12 级课程卡片色阶的逻辑已抽到 course_grid.dart 的
/// [generateCourseColors]，本文件统一复用。
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

  /// 本地快照最后获取时间（页面顶部显示"数据更新于"）
  String? _updatedAt;

  /// 课表本地长期缓存 key（获取一次长期存储，仅手动刷新才重新获取）
  static const _snapshotKey = 'course_table_snapshot';

  @override
  void initState() {
    super.initState();
    _service = CourseService(
      client: widget.client,
      userId: widget.userId,
    );
    _todayDay = DateTime.now().weekday;
    _loadConfig();
    _loadInitial();
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
              activeThumbColor: accentColorNotifier.value,
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

  /// 进入页面：优先使用本地长期缓存（获取一次长期存储），无缓存才网络获取。
  Future<void> _loadInitial() async {
    final raw = await LocalStorage.getString(_snapshotKey);
    Map<String, dynamic>? snap;
    if (raw != null && raw.isNotEmpty) {
      try {
        snap = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        snap = null;
      }
    }

    if (snap != null) {
      final s = snap;
      try {
        final courses = (s['courses'] as List)
            .map((e) => Course.fromSnapshot(e as Map<String, dynamic>))
            .toList();
        final semesters = (s['semesters'] as List)
            .map((e) => SemesterInfo.fromSnapshot(e as Map<String, dynamic>))
            .toList();
        final week = (s['currentWeek'] as num).toInt();
        if (!mounted) return;
        setState(() {
          _courses = courses;
          _semesters = semesters;
          _currentWeek = week;
          _todayWeek = week;
          _maxWeek = (s['maxWeek'] as num?)?.toInt() ?? 1;
          _firstMonday =
              DateTime.tryParse(s['firstMonday']?.toString() ?? '') ??
                  DateTime.now();
          _selectedSemester = s['selectedSemester']?.toString();
          _updatedAt = s['updatedAt']?.toString();
          _isLoading = false;
        });
        return;
      } catch (_) {
        // 快照损坏则走网络重新获取
      }
    }
    await _loadAll();
  }

  /// 把当前课表数据写入本地长期缓存。
  Future<void> _saveSnapshot() async {
    try {
      final snap = {
        'updatedAt': _updatedAt,
        'courses': _courses?.map((c) => c.toSnapshot()).toList() ?? [],
        'semesters': _semesters.map((s) => s.toSnapshot()).toList(),
        'selectedSemester': _selectedSemester,
        'currentWeek': _currentWeek,
        'maxWeek': _maxWeek,
        'firstMonday': _firstMonday.toIso8601String(),
      };
      await LocalStorage.setString(_snapshotKey, jsonEncode(snap));
    } catch (_) {}
  }

  /// 手动刷新：清除内存缓存并强制重新获取（同时更新长期缓存与获取日期）。
  void _manualRefresh() {
    DataCache().invalidateAll();
    _loadAll();
  }

  String _formatNow() {
    final n = DateTime.now();
    final hh = n.hour.toString().padLeft(2, '0');
    final mm = n.minute.toString().padLeft(2, '0');
    return '${n.month}月${n.day}日 $hh:$mm';
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
        _updatedAt = _formatNow();
      });

      await _saveSnapshot();

      // 桌面组件：课表加载成功后同步「今日课程」快照（非阻塞）
      WidgetService.saveCourseData(
        WidgetService.buildCourseData(
          courses: allCourses,
          currentWeek: currentWeek,
          firstMonday: weekInfo.firstMonday,
        ),
      );
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
        _updatedAt = _formatNow();
      });
      await _saveSnapshot();
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
            onPressed: _manualRefresh,
            tooltip: '重新获取课表',
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
    // 周课表 / 学期课表切换：统一玻璃分类栏（GlassCategoryBar）
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: GlassCategoryBar(
        items: const [
          GlassCategoryItem(label: '周课表', icon: Icons.view_week_outlined),
          GlassCategoryItem(
              label: '学期课表', icon: Icons.calendar_view_month_outlined),
        ],
        selectedIndex: _isWeeklyView ? 0 : 1,
        onSelected: (i) => setState(() => _isWeeklyView = i == 0),
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
                onPressed: _manualRefresh,
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
        // 数据获取日期提示（长期缓存模式：仅手动刷新才会重新获取）
        if (_updatedAt != null && _updatedAt!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 11, color: textHint(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '数据获取于 $_updatedAt · 点右上角刷新可重新获取',
                    style: TextStyle(fontSize: 10.5, color: textHint(context)),
                  ),
                ),
              ],
            ),
          ),
        // 学期选择器（周课表/学期课表共享）
        _buildSemesterSelector(),
        // 周课表导航（仅周课表模式）
        if (_isWeeklyView)
          CourseWeekBar(
            currentWeek: _currentWeek,
            maxWeek: _maxWeek,
            todayWeek: _todayWeek,
            onJumpToday: _jumpToToday,
            onPrev: () {
              if (_currentWeek > 1) setState(() => _currentWeek--);
            },
            onNext: () {
              if (_currentWeek < _maxWeek) setState(() => _currentWeek++);
            },
          ),
        // 主内容
        Expanded(
          child: _isWeeklyView ? _buildWeeklyView() : _buildSemesterView(),
        ),
      ],
    );
  }

  /// 学期选择器（共享栏）
  Widget _buildSemesterSelector() {
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
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Expanded(
              child: SmoothSelect<String>(
                value: _selectedSemester,
                hint: Text('选择学期', style: TextStyle(color: accentColorNotifier.value.withValues(alpha: 0.4))),
                // 玻璃化：背景同色填充（公共 smoothGlassStyle）
                style: smoothGlassStyle(context),
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
    return CourseScheduleGrid(
      courses: weekCourses,
      config: _config,
      currentWeek: _currentWeek,
      todayWeek: _todayWeek,
      todayDay: _todayDay,
      firstMonday: _firstMonday,
      maxWeek: _maxWeek,
      onSwipe: (d) {
        if (d > 0 && _currentWeek < _maxWeek) {
          setState(() => _currentWeek++);
        } else if (d < 0 && _currentWeek > 1) {
          setState(() => _currentWeek--);
        }
      },
    );
  }


  // ==================== 学期课表视图 ====================

  Widget _buildSemesterView() {
    return SemesterCourseListView(
      courses: _courses!,
      config: _config,
    );
  }
}
