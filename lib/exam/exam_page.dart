import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/data_cache.dart';
import 'exam.dart';
import 'exam_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class ExamPage extends StatefulWidget {
  final SharedHttpClient client;
  const ExamPage({super.key, required this.client});
  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  List<Exam>? _exams;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final service = ExamService(client: widget.client);
      final exams = await service.fetchExams();
      if (!mounted) return;
      setState(() { _exams = exams; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
        title: const Text('考试安排'),
        centerTitle: true,
        actions: [if (_exams != null) IconButton(icon: const Icon(Icons.refresh), onPressed: () { DataCache().invalidateAll(); _load(); })],
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
            _buildDateHeader(date, groups[date]!.length),
            ...groups[date]!.map(_buildExamCard),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem(Icons.event_note, '${_exams!.length}门', '考试科目'),
          _statItem(Icons.calendar_today, '${_exams!.map((e) => e.date.substring(0, 10)).toSet().length}天', '考试天数'),
          _statItem(Icons.pin, _exams!.first.examName.length > 12
              ? '${_exams!.first.examName.substring(0, 12)}...'
              : _exams!.first.examName, '考试名称'),
        ]),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, size: 20, color: _yibinBlue),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: TextStyle(fontSize: 11, color: textSecondary(context))),
    ]);
  }

  Widget _buildDateHeader(String date, int count) {
    final weekday = _weekday(date);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(children: [
        Icon(Icons.calendar_today, size: 16, color: _yibinBlue.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text('$date $weekday',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _yibinBlue)),
        const SizedBox(width: 8),
        Text('共$count场', style: TextStyle(fontSize: 12, color: textSecondary(context))),
      ]),
    );
  }

  Widget _buildExamCard(Exam exam) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // 时间侧边
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
            color: _yibinBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(exam.timeRange.split('-').first, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _yibinBlue)),
            const SizedBox(height: 2),
            Text('~${exam.timeRange.split('-').last}', style: TextStyle(fontSize: 11, color: _yibinBlue.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(exam.weekday, style: TextStyle(fontSize: 11, color: _yibinBlue.withValues(alpha: 0.6))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.courseName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _infoRow(Icons.room, exam.classroom),
            _infoRow(Icons.person, '监考: ${exam.invigilator}'),
            if (exam.seatNo.isNotEmpty) _infoRow(Icons.event_seat, '座位: ${exam.seatNo}'),
          ])),
        ]),
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

  String _weekday(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return days[dt.weekday - 1];
    } catch (_) { return ''; }
  }
}
