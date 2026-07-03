import 'package:flutter/material.dart';

import '../core/http_client.dart';
import 'score.dart';
import 'score_service.dart';

class ScorePage extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const ScorePage({super.key, required this.client, required this.userId});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  ScoreResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ScoreService(client: widget.client);
      final result = await service.fetchScores(null);

      if (!mounted) return;
      setState(() {
        _result = result;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩查询'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScores,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

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
              Text('获取成绩失败',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadScores,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final info = _result!.info;
    final scores = _result!.scores;

    if (scores.isEmpty) {
      return const Center(child: Text('暂无成绩数据'));
    }

    // 按学期分组
    final grouped = <String, List<Score>>{};
    for (final s in scores) {
      grouped.putIfAbsent(s.semester, () => []).add(s);
    }

    // 计算总学分和平均绩点
    double totalCredits = 0;
    double weightedGpa = 0;
    for (final s in scores) {
      totalCredits += s.credit;
      weightedGpa += s.credit * s.gpa;
    }
    final avgGpa = totalCredits > 0
        ? (weightedGpa / totalCredits).toStringAsFixed(2)
        : '0.00';

    return RefreshIndicator(
      onRefresh: _loadScores,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 学生信息卡片
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('姓名', info.name),
                  _infoRow('学号', info.studentId),
                  _infoRow('学院', info.department),
                  _infoRow('专业', info.major),
                  _infoRow('班级', info.className),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 总览
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('总学分', totalCredits.toStringAsFixed(1)),
                  _statItem('课程数', scores.length.toString()),
                  _statItem('平均绩点', avgGpa),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 各学期成绩
          for (final entry in grouped.entries) ...[
            _buildSemesterSection(entry.key, entry.value),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSemesterSection(String semester, List<Score> scores) {
    // 计算该学期学分
    double termCredits = 0;
    for (final s in scores) {
      termCredits += s.credit;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  scores.isNotEmpty ? scores.first.semesterDisplay : semester,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${scores.length}门 / ${termCredits.toStringAsFixed(1)}学分',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _headerCell('课程', 4),
                _headerCell('类别', 1),
                _headerCell('学分', 0.7),
                _headerCell('成绩', 0.7),
                _headerCell('绩点', 0.7),
              ],
            ),
          ),
          const Divider(height: 1),
          // 成绩行
          for (int i = 0; i < scores.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: i.isEven ? null : Colors.grey.shade50,
              child: Row(
                children: [
                  _cell(scores[i].courseName, 4),
                  _cell(scores[i].category, 1),
                  _cell(scores[i].credit.toStringAsFixed(1), 0.7),
                  _scoreCell(scores[i].score, scores[i].grade, 0.7),
                  _cell(scores[i].gpa.toStringAsFixed(2), 0.7),
                ],
              ),
            ),
            if (i < scores.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _headerCell(String text, double flex) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
    );
  }

  Widget _cell(String text, double flex) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(text,
          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _scoreCell(int score, String grade, double flex) {
    final color = score >= 60 ? Colors.green : Colors.red;
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(
        '$score\n$grade',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
