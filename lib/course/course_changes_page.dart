import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/smooth_styles.dart';
import '../core/theme_utils.dart';
import 'course.dart';
import 'course_service.dart';
import '../main.dart';

/// 调课/停课 & 未安排课程 — 独立全屏页面
///
/// 与学期绑定：切换学期下拉框自动重新加载对应学期的数据。
class CourseChangesPage extends StatefulWidget {
  final CourseService service;
  final List<SemesterInfo> semesters;
  final String? initialSemester;

  const CourseChangesPage({
    super.key,
    required this.service,
    required this.semesters,
    this.initialSemester,
  });

  @override
  State<CourseChangesPage> createState() => _CourseChangesPageState();
}

class _CourseChangesPageState extends State<CourseChangesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _selectedSemester;
  bool _isLoadingSemester = false;

  List<CourseChange> _courseChanges = [];
  bool _isLoadingChanges = false;
  String? _changesError;

  List<UnarrangedCourse> _unarrangedCourses = [];
  bool _isLoadingUnarranged = false;
  String? _unarrangedError;

  static const _dayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedSemester = widget.initialSemester;
    if (_selectedSemester != null) {
      _loadAllData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final semester = _selectedSemester;
    if (semester == null) return;
    setState(() {
      _isLoadingChanges = true;
      _isLoadingUnarranged = true;
      _changesError = null;
      _unarrangedError = null;
    });

    await Future.wait([
      _loadCourseChanges(semester),
      _loadUnarrangedCourses(semester),
    ]);
  }

  Future<void> _loadCourseChanges(String xnxqdm) async {
    try {
      final data = await widget.service.fetchCourseChanges(xnxqdm: xnxqdm, forceRefresh: true);
      if (mounted) setState(() => _courseChanges = data);
    } catch (e) {
      if (mounted) setState(() => _changesError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingChanges = false);
    }
  }

  Future<void> _loadUnarrangedCourses(String xnxqdm) async {
    try {
      final data = await widget.service.fetchUnarrangedCourses(xnxqdm: xnxqdm, forceRefresh: true);
      if (mounted) setState(() => _unarrangedCourses = data);
    } catch (e) {
      if (mounted) setState(() => _unarrangedError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingUnarranged = false);
    }
  }

  void _switchSemester(String xnxqdm) {
    setState(() {
      _selectedSemester = xnxqdm;
      _isLoadingSemester = true;
    });
    _loadAllData().then((_) {
      if (mounted) setState(() => _isLoadingSemester = false);
    });
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final currentSemester = widget.semesters
        .where((s) => s.dm == _selectedSemester)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('调课 & 未安排课程'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 学期选择器
              _buildSemesterSelector(currentSemester),
              // Tab 栏
              _buildTabBar(),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCourseChangesTab(),
          _buildUnarrangedTab(),
        ],
      ),
    );
  }

  // ==================== 学期选择器 ====================

  Widget _buildSemesterSelector(SemesterInfo? current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: dividerColor(context)),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.school, size: 18, color: accentColorNotifier.value),
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
                hint: Text('选择学期',
                    style: TextStyle(color: accentColorNotifier.value.withValues(alpha: 0.4))),
                style: smoothStyle(context),
                highlight: smoothHighlight(context),
                menuMaxHeight: 300,
                items: widget.semesters.map((s) {
                  return SmoothSelectItem<String>(
                    value: s.dm,
                    child: Text(s.mc,
                        style: TextStyle(color: textPrimary(context))),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null && v != _selectedSemester) {
                    _switchSemester(v);
                  }
                },
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: current != null && current.isActive
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              current != null && current.isActive ? '当前学期' : '历史学期',
              style: TextStyle(
                fontSize: 11,
                color: current != null && current.isActive ? Colors.green.shade700 : textHint(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Tab 栏 ====================

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: dividerColor(context)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: accentColorNotifier.value,
        unselectedLabelColor: textHint(context),
        indicatorColor: accentColorNotifier.value,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swap_horiz, size: 18),
                const SizedBox(width: 4),
                Text('调课/停课'),
                if (_courseChanges.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_courseChanges.length}',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.unpublished, size: 18),
                const SizedBox(width: 4),
                Text('未安排课程'),
                if (_unarrangedCourses.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: textHint(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_unarrangedCourses.length}',
                      style: TextStyle(fontSize: 11, color: textHint(context)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 调课/停课 Tab ====================

  Widget _buildCourseChangesTab() {
    if (_isLoadingChanges) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_changesError != null) {
      return _buildErrorState(
        error: _changesError!,
        onRetry: () => _loadCourseChanges(_selectedSemester!),
      );
    }

    if (_courseChanges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        message: '本学期暂无调课/停课信息',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCourseChanges(_selectedSemester!),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _courseChanges.length,
        itemBuilder: (context, index) {
          return _buildChangeCard(_courseChanges[index]);
        },
      ),
    );
  }

  // ==================== 未安排课程 Tab ====================

  Widget _buildUnarrangedTab() {
    if (_isLoadingUnarranged) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_unarrangedError != null) {
      return _buildErrorState(
        error: _unarrangedError!,
        onRetry: () => _loadUnarrangedCourses(_selectedSemester!),
      );
    }

    if (_unarrangedCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        message: '本学期所有课程已安排',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadUnarrangedCourses(_selectedSemester!),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _unarrangedCourses.length,
        itemBuilder: (context, index) {
          return _buildUnarrangedCard(_unarrangedCourses[index]);
        },
      ),
    );
  }

  // ==================== 公共组件 ====================

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(fontSize: 15, color: textHint(context))),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required String error,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(fontSize: 16, color: textHint(context))),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textHint(context))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 调课卡片 ====================

  Widget _buildChangeCard(CourseChange change) {
    final color = change.isSuspended ? Colors.red : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：类型标签 + 课程名
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(change.changeType,
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(change.courseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (change.teacher.isNotEmpty)
                  Text(change.teacher,
                      style: TextStyle(fontSize: 12, color: textHint(context))),
              ],
            ),
            const SizedBox(height: 10),
            // 时间线式信息展示
            if (change.isSuspended)
              _buildTimelineRow(
                icon: Icons.cancel,
                iconColor: Colors.red,
                label: '原安排',
                text: _formatSchedule(
                    change.originalWeekText,
                    change.originalDay,
                    change.originalStartPeriod,
                    change.originalEndPeriod,
                    change.originalRoom),
              )
            else ...[
              _buildTimelineRow(
                icon: Icons.schedule,
                iconColor: textHint(context),
                label: '原安排',
                text: _formatSchedule(
                    change.originalWeekText,
                    change.originalDay,
                    change.originalStartPeriod,
                    change.originalEndPeriod,
                    change.originalRoom),
              ),
              const SizedBox(height: 6),
              _buildTimelineRow(
                icon: Icons.update,
                iconColor: Colors.green,
                label: '新安排',
                text: _formatSchedule(
                    change.newWeekText,
                    change.newDay,
                    change.newStartPeriod,
                    change.newEndPeriod,
                    change.newRoom),
                isNew: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
    bool isNew = false,
  }) {
    // 左侧时间线装饰
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            Container(
              width: 1,
              height: 20,
              color: dividerColor(context),
            ),
          ],
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isNew ? Colors.green.shade600 : textHint(context),
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: isNew ? Colors.green.shade700 : textSecondary(context),
                  height: 1.4)),
        ),
      ],
    );
  }

  String _formatSchedule(
      String weekText, int day, int startPeriod, int endPeriod, String room) {
    final sb = StringBuffer();
    if (day >= 1 && day <= 7) {
      sb.write('周${_dayLabels[day]} ');
    }
    if (startPeriod > 0) {
      sb.write('$startPeriod-$endPeriod节');
    }
    if (weekText.isNotEmpty) {
      sb.write('  $weekText');
    }
    if (room.isNotEmpty) {
      sb.write('  $room');
    }
    return sb.toString().trim();
  }

  // ==================== 未安排课程卡片 ====================

  Widget _buildUnarrangedCard(UnarrangedCourse course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 左侧图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColorNotifier.value.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.unpublished,
                color: accentColorNotifier.value.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildInfoChip(Icons.person_outline, course.teacher),
                      if (course.credits > 0) ...[
                        const SizedBox(width: 12),
                        _buildInfoChip(Icons.grade_outlined,
                            '${course.credits} 学分'),
                      ],
                      if (course.hours > 0) ...[
                        const SizedBox(width: 12),
                        _buildInfoChip(
                            Icons.timer_outlined, '${course.hours} 学时'),
                      ],
                    ],
                  ),
                  if (course.weekRange.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.date_range,
                            size: 14, color: textHint(context)),
                        const SizedBox(width: 4),
                        Text('周次: ${course.weekRange}',
                            style:
                                TextStyle(fontSize: 12, color: textHint(context))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: textHint(context)),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 12, color: textHint(context))),
      ],
    );
  }
}
