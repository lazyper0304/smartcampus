import 'package:flutter/material.dart';

import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/glass_category_bar.dart';
import '../core/glass_filter_chip.dart';
import 'exam.dart';
import 'exam_service.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


class ExamPage extends StatefulWidget {
  final SharedHttpClient client;
  const ExamPage({super.key, required this.client});
  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  List<Exam>? _exams;
  List<UnarrangedExam>? _unarranged;
  List<ExamSemester> _semesters = [];
  String _xnxqdm = '';
  bool _isLoading = true;
  String? _error;

  /// 分类 tab：0=已安排考试，1=未安排考试
  int _tabIndex = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final service = ExamService(client: widget.client);
      // 1. 学期列表（首次进入；已加载则不重复拉）
      if (_semesters.isEmpty) {
        final semesters = await service.fetchSemesters();
        if (!mounted) return;
        _semesters = semesters;
        // 默认选中：当前学期（SFSY=1），否则第一个
        if (semesters.isNotEmpty) {
          final active = semesters.where((s) => s.isActive).toList();
          _xnxqdm = (active.isNotEmpty ? active.first : semesters.first).dm;
        }
      }
      // 2. 已安排 + 未安排并行拉取（按当前学期）
      final results = await Future.wait([
        service.fetchExams(xnxqdm: _xnxqdm),
        service.fetchUnarrangedExams(xnxqdm: _xnxqdm),
      ]);
      if (!mounted) return;
      setState(() {
        _exams = results[0] as List<Exam>;
        _unarranged = results[1] as List<UnarrangedExam>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  /// 切换学年学期：仅重新拉取考试数据，不清空学期列表
  Future<void> _switchSemester(String dm) async {
    if (dm == _xnxqdm) return;
    setState(() { _xnxqdm = dm; _isLoading = true; _exams = null; _unarranged = null; });
    try {
      final service = ExamService(client: widget.client);
      final results = await Future.wait([
        service.fetchExams(xnxqdm: dm),
        service.fetchUnarrangedExams(xnxqdm: dm),
      ]);
      if (!mounted) return;
      setState(() {
        _exams = results[0] as List<Exam>;
        _unarranged = results[1] as List<UnarrangedExam>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
        title: const Text('考试安排'),
        centerTitle: true,
        actions: [if (_exams != null) IconButton(icon: const Icon(Icons.refresh), onPressed: () { DataCache().invalidateAll(); _load(); })],
        // 学年学期 + 已安排/未安排分类：统一玻璃组件
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 学年学期横滑选择（wspj 同款 GlassFilterChip）
              if (_semesters.isNotEmpty)
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        for (final s in _semesters)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GlassFilterChip(
                              label: s.mc,
                              selected: _xnxqdm == s.dm,
                              onTap: () => _switchSemester(s.dm),
                              radius: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // 已安排 / 未安排分类
              Container(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: GlassCategoryBar(
                  items: const [
                    GlassCategoryItem(label: '已安排', icon: Icons.event_available_outlined),
                    GlassCategoryItem(label: '未安排', icon: Icons.event_busy_outlined),
                  ],
                  selectedIndex: _tabIndex,
                  onSelected: (i) => setState(() => _tabIndex = i),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('获取失败', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: () { DataCache().invalidateAll(); _load(); }, icon: const Icon(Icons.refresh), label: const Text('重试')),
        ]),
      ));
    }
    // 未安排 tab：独立列表
    if (_tabIndex == 1) {
      if (_unarranged == null || _unarranged!.isEmpty) {
        return const Center(child: Text('本学期暂无未安排考试'));
      }
      return RefreshIndicator(
        onRefresh: () { DataCache().invalidateAll(); return _load(); },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildUnarrangedHeader(),
            ..._unarranged!.map(_buildUnarrangedCard),
          ],
        ),
      );
    }
    if (_exams == null || _exams!.isEmpty) {
      return const Center(child: Text('暂无考试安排'));
    }

    // 按日期分组
    final groups = <String, List<Exam>>{};
    for (final exam in _exams!) {
      final date = exam.date.substring(0, 10);
      groups.putIfAbsent(date, () => []);
      groups[date]!.add(exam);
    }
    final sortedDates = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: () { DataCache().invalidateAll(); return _load(); },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildStats(),
          const SizedBox(height: 8),
          for (final date in sortedDates) ...[
            _buildDateHeader(date, groups[date]!),
            ...groups[date]!.map(_buildExamCard),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final finished = _exams!.where((e) => e.isFinished).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem(Icons.event_note, '${_exams!.length}门', '考试科目'),
          _statItem(Icons.calendar_today, '${_exams!.map((e) => e.date.substring(0, 10)).toSet().length}天', '考试天数'),
          _statItem(finished > 0 ? Icons.task_alt : Icons.pin,
              finished > 0 ? '$finished门' : (_exams!.first.examName.length > 12
                  ? '${_exams!.first.examName.substring(0, 12)}...'
                  : _exams!.first.examName),
              finished > 0 ? '已完成' : '考试名称'),
        ]),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, size: 20, color: accentColorNotifier.value),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: TextStyle(fontSize: 11, color: textSecondary(context))),
    ]);
  }

  Widget _buildDateHeader(String date, List<Exam> exams) {
    final weekday = _weekday(date);
    final allFinished = exams.isNotEmpty && exams.every((e) => e.isFinished);
    final color = allFinished
        ? textSecondary(context)
        : accentColorNotifier.value;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(children: [
        Icon(Icons.calendar_today, size: 16, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text('$date $weekday',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        const SizedBox(width: 8),
        Text('共${exams.length}场', style: TextStyle(fontSize: 12, color: textSecondary(context))),
        if (allFinished) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: textSecondary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('已结束', style: TextStyle(fontSize: 11, color: textSecondary(context))),
          ),
        ],
      ]),
    );
  }

  Widget _buildExamCard(Exam exam) {
    final finished = exam.isFinished;
    final cardColor = finished
        ? textSecondary(context).withValues(alpha: 0.10)
        : accentColorNotifier.value.withValues(alpha: 0.08);
    final timeColor = finished
        ? textSecondary(context)
        : accentColorNotifier.value;
    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      // 已完成考试整体降透明置灰，突出"已结束"
      child: Opacity(
        opacity: finished ? 0.55 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // 时间侧边
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Text(exam.timeRange.split('-').first, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: timeColor)),
                const SizedBox(height: 2),
                Text('~${exam.timeRange.split('-').last}', style: TextStyle(fontSize: 11, color: timeColor.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(exam.weekday, style: TextStyle(fontSize: 11, color: timeColor.withValues(alpha: 0.6))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(exam.courseName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (finished) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: textSecondary(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('已完成',
                        style: TextStyle(fontSize: 11, color: textSecondary(context), fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              _infoRow(Icons.room, exam.classroom),
              _infoRow(Icons.person, '任课老师: ${exam.teacher}'),
              if (exam.seatNo.isNotEmpty) _infoRow(Icons.event_seat, '座位: ${exam.seatNo}'),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Icon(icon, size: 13, color: textSecondary(context)),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
      ]),
    );
  }

  /// 未安排考试区块头
  Widget _buildUnarrangedHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(children: [
        Icon(Icons.event_busy, size: 16, color: textSecondary(context)),
        const SizedBox(width: 6),
        Text('未安排考试',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textSecondary(context))),
        const SizedBox(width: 8),
        Text('共${_unarranged!.length}门，等待排考',
            style: TextStyle(fontSize: 12, color: textSecondary(context))),
      ]),
    );
  }

  /// 未安排考试卡片：仅课程名 + 教师 + 课程号
  Widget _buildUnarrangedCard(UnarrangedExam exam) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // 时间侧边（无时间，显示占位）
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: textSecondary(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              Icon(Icons.schedule_rounded, size: 20, color: textSecondary(context)),
              const SizedBox(height: 2),
              Text('待排考', style: TextStyle(fontSize: 11, color: textSecondary(context))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.courseName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (exam.teacher.isNotEmpty) _infoRow(Icons.person, exam.teacher),
            if (exam.courseCode.isNotEmpty) _infoRow(Icons.tag, exam.courseCode),
          ])),
        ]),
      ),
    );
  }

  String _weekday(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return days[dt.weekday - 1];
    } catch (_) { return ''; }
  }
}
