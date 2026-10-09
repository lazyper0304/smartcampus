import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../main.dart';
import 'bingo_course_service.dart';
import 'course.dart';
import 'course_service.dart';

/// 课表获取过渡界面的最终产物（供课表页应用并写本地快照）
class CourseFetchResult {
  final List<Course> regular;
  final List<Course> experiments;
  final CurrentWeekInfo weekInfo;
  final List<SemesterInfo> semesters;
  final String? activeSemester;

  const CourseFetchResult({
    required this.regular,
    required this.experiments,
    required this.weekInfo,
    required this.semesters,
    required this.activeSemester,
  });

  /// 普通课程 + 实验教学合并后的完整课表
  List<Course> get merged => [...regular, ...experiments];

  /// 复制并替换学期列表（用于课表页补全异常列表，保持本类不可变）
  CourseFetchResult withSemesters(List<SemesterInfo> next) => CourseFetchResult(
        regular: regular,
        experiments: experiments,
        weekInfo: weekInfo,
        semesters: next,
        activeSemester: activeSemester,
      );
}

/// 课表获取过渡界面
///
/// ① 普通课表（学期解析 + 课表并行，当前周失败降级为第 1 周）→
/// ② 实验课表（scjx2 未登录显示「已跳过」，异常显示「失败」，均不影响普通课表）。
/// 每步实时提示成功与否；普通课表失败即终止并可重试。
/// 两步完成后短暂停留展示结果，自动带 [CourseFetchResult] 返回；
/// 用户手动返回则 pop null。
class CourseFetchPage extends StatefulWidget {
  final CourseService service;

  /// 指定学期（切换学期模式）：非 null 时跳过自动解析，直接获取该学期；
  /// null = 自动解析当前学期（首次获取 / 手动刷新）
  final String? xnxqdm;

  /// 强制刷新数据（切换学期时 true：当前周 / 实验课表绕过 DataCache）
  final bool forceRefreshData;

  const CourseFetchPage({
    super.key,
    required this.service,
    this.xnxqdm,
    this.forceRefreshData = false,
  });

  @override
  State<CourseFetchPage> createState() => _CourseFetchPageState();
}

enum _StepStatus { pending, running, success, skipped, failed }

class _CourseFetchPageState extends State<CourseFetchPage> {
  _StepStatus _regular = _StepStatus.pending;
  _StepStatus _experiments = _StepStatus.pending;
  String? _regularDetail; // 成功详情：N 门课程
  String? _expDetail; // 成功/跳过/失败详情
  String? _regularError; // 普通课表失败原因

  @override
  void initState() {
    super.initState();
    // 首帧渲染后再启动，让步骤行先以「待获取」状态可见
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _regular = _StepStatus.running;
      _experiments = _StepStatus.pending;
      _regularDetail = null;
      _expDetail = null;
      _regularError = null;
    });

    // Bingo 后端 `/course/semester/{sem}` 已聚合理论课与实验课
    // （`schedule_type` 区分），一次请求即得整学期课表：
    // ① 课表主数据（失败即终止，可重试）
    // ② 当前教学周（永不抛，失败降级为第 1 周）
    final bingo = BingoCourseService.instance;
    List<Course> regular = [];
    List<Course> experiments = [];
    List<SemesterInfo> semesters = [];
    CurrentWeekInfo weekInfo =
        CurrentWeekInfo(week: 1, firstMonday: DateTime.now());
    String? activeSemester = widget.xnxqdm;

    try {
      // 学期：指定学期优先，否则取当前学期
      final resolvedSemester = (widget.xnxqdm?.isNotEmpty ?? false)
          ? widget.xnxqdm!
          : await bingo.currentSemesterCode();
      activeSemester = resolvedSemester;

      // 学期列表（Bingo 无学期列表端点，由当前学期往前推 8 个，
      // 推导算法与参考工程 buildCourseSemesterList 一致）。
      //
      // ⚠️ 基准必须恒为**真实当前学期**，不能用 widget.xnxqdm（目标学期）：
      // 那样切到历史学期后列表会变成「从历史学期往前推」，把当前学期挤出
      // 列表，导致下拉框里找不到刚离开的学期、无法切回。
      // 这里始终重新解析当前学期（走内存缓存，成本可忽略）。
      final currentSemester = await bingo.currentSemesterCode();
      final listBase =
          currentSemester.isNotEmpty ? currentSemester : resolvedSemester;
      semesters = BingoCourseService.buildSemesterList(listBase)
          .map((dm) => SemesterInfo(
                wid: '',
                dm: dm,
                mc: formatSemesterLabel(dm),
                xndm: '',
                xqdm: '',
                isActive: dm == listBase,
              ))
          .toList();

      final result = await bingo.fetchSemesterCourses(
        semester: resolvedSemester,
        forceRefresh: widget.forceRefreshData,
      );

      // 按 schedule_type 拆分：实验课带 tag='实验'，普通课不带。
      // 保持既有 CourseFetchResult 的 regular / experiments 结构，
      // 课表页与快照逻辑无需改动。
      for (final item in result.items) {
        if (item.isCustom) continue;
        final course = item.toCourse(semester: resolvedSemester);
        if (course.tag == '实验') {
          experiments.add(course);
        } else {
          regular.add(course);
        }
      }

      weekInfo = await _weekSafe(forceRefresh: widget.forceRefreshData);

      if (!mounted) return;
      setState(() {
        _regular = _StepStatus.success;
        _regularDetail = '${regular.length} 门课程';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _regular = _StepStatus.failed;
        _regularError = e.toString().replaceFirst('Exception: ', '');
      });
      return; // 课表获取失败：终止
    }

    // 实验课已随主数据一并返回，此处仅汇报结果
    if (!mounted) return;
    setState(() {
      _experiments = _StepStatus.success;
      _expDetail = '${experiments.length} 个实验';
    });

    final result = CourseFetchResult(
      regular: regular,
      experiments: experiments,
      weekInfo: weekInfo,
      semesters: semesters,
      activeSemester: activeSemester,
    );

    // 短暂停留展示结果后自动返回
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop(result);
  }

  /// 当前周获取兜底：失败降级为第 1 周（学期起始日以今天占位）
  Future<CurrentWeekInfo> _weekSafe({bool forceRefresh = false}) async {
    try {
      return await BingoCourseService.instance
          .fetchCurrentWeek(forceRefresh: forceRefresh);
    } catch (_) {
      return CurrentWeekInfo(week: 1, firstMonday: DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = _regular == _StepStatus.failed;
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: const Text('获取课表')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: failed
                        ? scheme.error.withValues(alpha: 0.10)
                        : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    failed ? Icons.error_outline_rounded : Icons.calendar_month_rounded,
                    color: failed ? scheme.error : scheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed ? '课表获取失败' : '正在获取课表',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  failed ? '课表未能获取，请重试' : '正在同步课表与实验教学',
                  style: TextStyle(
                      fontSize: 12, color: textSecondary(context)),
                ),
                const SizedBox(height: 24),
                _buildStepCard(
                  scheme,
                  icon: Icons.menu_book_rounded,
                  title: '普通课表',
                  status: _regular,
                  detail: _regularDetail,
                  error: _regularError,
                ),
                const SizedBox(height: 12),
                _buildStepCard(
                  scheme,
                  icon: Icons.science_rounded,
                  title: '实验课表',
                  status: _experiments,
                  detail: _expDetail,
                ),
                if (failed) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                    onPressed: _run,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required _StepStatus status,
    String? detail,
    String? error,
  }) {
    Widget trailing;
    String statusText;
    Color statusColor;
    switch (status) {
      case _StepStatus.pending:
        trailing = Icon(Icons.schedule_rounded,
            size: 22, color: textHint(context));
        statusText = '待获取';
        statusColor = textHint(context);
      case _StepStatus.running:
        trailing = const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4));
        statusText = '获取中…';
        statusColor = scheme.primary;
      case _StepStatus.success:
        trailing =
            const Icon(Icons.check_circle_rounded, size: 22, color: Colors.green);
        statusText = '成功';
        statusColor = Colors.green;
      case _StepStatus.skipped:
        trailing = const Icon(Icons.info_rounded, size: 22, color: Colors.orange);
        statusText = '已跳过';
        statusColor = Colors.orange;
      case _StepStatus.failed:
        trailing = const Icon(Icons.cancel_rounded, size: 22, color: Colors.red);
        statusText = '失败';
        statusColor = Colors.red;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(statusText,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor)),
                    ],
                  ),
                  if (error != null || detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      error ?? detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: error != null
                              ? Colors.red
                              : textSecondary(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}
