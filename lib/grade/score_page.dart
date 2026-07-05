import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'score.dart';
import 'score_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

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
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('成绩查询'),
          centerTitle: true,
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  DataCache().invalidateAll();
                  _loadScores();
                },
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _buildError();
    }
    final scores = _result!.scores;
    if (scores.isEmpty) {
      return Center(
        child: Text('暂无成绩数据',
            style: TextStyle(fontSize: 14, color: Colors.grey[400])),
      );
    }

    // 按学期分组
    final grouped = <String, List<Score>>{};
    for (final s in scores) {
      grouped.putIfAbsent(s.semester, () => []).add(s);
    }

    // 总览统计
    double totalCredits = 0;
    double weightedGpa = 0;
    for (final s in scores) {
      totalCredits += s.credit;
      weightedGpa += s.credit * s.gpa;
    }
    final avgGpa =
        totalCredits > 0 ? (weightedGpa / totalCredits).toStringAsFixed(2) : '0.00';

    return RefreshIndicator(
      onRefresh: () {
        DataCache().invalidateAll();
        return _loadScores();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 总览卡片
          _buildOverviewCard(totalCredits, scores.length, avgGpa),
          const SizedBox(height: 18),
          // 各学期
          for (final entry in grouped.entries) ...[
            _buildSemesterCard(entry.key, entry.value),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard(double totalCredits, int courseCount, String avgGpa) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('总学分', totalCredits.toStringAsFixed(1), Icons.auto_stories_rounded),
              _statItem('课程数', courseCount.toString(), Icons.menu_book_rounded),
              _statItem('平均绩点', avgGpa, Icons.star_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _yibinBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _yibinBlue, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _yibinBlue)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildSemesterCard(String semester, List<Score> scores) {
    double termCredits = 0;
    for (final s in scores) {
      termCredits += s.credit;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 学期标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _yibinBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scores.isNotEmpty
                              ? scores.first.semesterDisplay
                              : semester,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${scores.length}门课程 · ${termCredits.toStringAsFixed(1)}学分',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            // 表头
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _headerText('课程', 3.5),
                  _headerText('类别', 1.2),
                  _headerText('学分', 0.8),
                  _headerText('成绩', 0.8),
                  _headerText('绩点', 0.8),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            // 成绩行
            for (int i = 0; i < scores.length; i++)
              _buildScoreRow(scores[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(Score score, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? null : _yibinBlue.withValues(alpha: 0.03),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cellText(score.courseName, 3.5),
          _cellText(score.category, 1.2),
          _cellText(score.credit.toStringAsFixed(1), 0.8),
          _scoreText(score.score, score.grade, 0.8),
          _cellText(score.gpa.toStringAsFixed(2), 0.8),
        ],
      ),
    );
  }

  Widget _headerText(String text, double flex) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _yibinBlue.withValues(alpha: 0.7))),
    );
  }

  Widget _cellText(String text, double flex) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(text,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _scoreText(int score, String grade, double flex) {
    final isPass = score >= 60;
    return Expanded(
      flex: (flex * 10).toInt(),
      child: RichText(
        text: TextSpan(
          text: '$score',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isPass ? Colors.green[700] : Colors.red[600],
          ),
          children: [
            TextSpan(
              text: '\n$grade',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isPass ? Colors.green[400] : Colors.red[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('获取成绩失败',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                DataCache().invalidateAll();
                _loadScores();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _yibinBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
