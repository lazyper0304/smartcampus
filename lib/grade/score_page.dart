import 'package:flutter/material.dart';

import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/navigation.dart';
import '../core/smooth_styles.dart';
import '../core/theme_utils.dart';
import 'bingo_score_service.dart';
import 'grade_rank_style.dart';
import 'grade_ranking_page.dart';
import 'score.dart';
import 'score_service.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


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

  /// 学期代码 → 该学期成绩排名（`/grade/ranking`）。
  ///
  /// 成绩页需要**每个学期各自的平均绩点排名**，故按学期逐个查询后存此表，
  /// 学期卡片头部直接取用；同时作为排名页的预取缓存传入，避免二次请求。
  final Map<String, BingoGradeRanking> _rankings = {};

  /// 排名是否在加载（学期卡片显示占位而非「无排名」）
  bool _rankingsLoading = false;

  /// 排名请求代号：刷新竞态保护，丢弃过期响应
  int _rankReqGen = 0;

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
      // 成绩拿到后再拉各学期排名（不阻塞成绩展示）
      _loadRankings(semestersOf(result.scores));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// 按学期并发拉取排名。单个学期失败只留空，不影响其余学期与成绩页。
  Future<void> _loadRankings(List<String> semesters) async {
    final gen = ++_rankReqGen;
    if (semesters.isEmpty) return;
    setState(() => _rankingsLoading = true);
    final entries = await Future.wait(semesters.map((sem) async {
      try {
        final r = await ScoreService().fetchRanking(semester: sem);
        return MapEntry(sem, r);
      } catch (_) {
        return MapEntry(sem, const BingoGradeRanking());
      }
    }));
    if (!mounted || gen != _rankReqGen) return;
    setState(() {
      for (final e in entries) {
        _rankings[e.key] = e.value;
      }
      _rankingsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('成绩查询'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.leaderboard_rounded),
              tooltip: '成绩排名',
              onPressed: () {
                final scores = _result?.scores;
                if (scores == null || scores.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('暂无成绩数据，无法查询排名')),
                  );
                  return;
                }
                pushPage(
                  context,
                  GradeRankingPage(scores: scores, prefetched: _rankings),
                );
              },
            ),
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  DataCache().invalidateAll();
                  _rankings.clear();
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
            style: TextStyle(fontSize: 14, color: textHint(context))),
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
          // 各学期（首个学期默认展开）
          for (final entry in grouped.entries.toList().asMap().entries) ...[
            _buildSemesterCard(
                entry.value.key, entry.value.value, initiallyExpanded: false),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard(double totalCredits, int courseCount, String avgGpa) {
    return TweenAnimationBuilder<double>(
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
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
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
            color: accentColorNotifier.value.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColorNotifier.value, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: accentColorNotifier.value)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: textHint(context))),
      ],
    );
  }

  Widget _buildSemesterCard(String semester, List<Score> scores,
      {bool initiallyExpanded = false}) {
    double termCredits = 0;
    double weightedGpa = 0;
    for (final s in scores) {
      termCredits += s.credit;
      weightedGpa += s.credit * s.gpa;
    }
    final termAvgGpa =
        termCredits > 0 ? (weightedGpa / termCredits).toStringAsFixed(2) : '0.00';

    final semesterName =
        scores.isNotEmpty ? scores.first.semesterDisplay : semester;

    // 该学期平均绩点的班级排名（`/grade/ranking` 随学期查询）
    final rankInfo = _rankings[semester]?.classRank;
    final hasRank = isRankValid(rankInfo);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accentColorNotifier.value,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  semesterName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${scores.length}门课程 · ${termCredits.toStringAsFixed(1)}学分  · 平均绩点 $termAvgGpa',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          // 学期平均绩点排名徽章
          if (hasRank)
            _termRankBadge(rankInfo!)
          else if (_rankingsLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: textHint(context),
              ),
            ),
        ],
      ),
    );

    return SmoothExpansionTile(
      initiallyExpanded: initiallyExpanded,
      // 玻璃化（保留 SmoothExpansionTile）：公共 smoothGlassStyle——
      // 背景渐变同色填充，卡片与背景融为一体（painter 写死 alpha 0.90，
      // 半透明不可行），accent 描边/高光由 painter 绘制
      style: smoothGlassStyle(context),
      headerBuilder: (context, expand, controller) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.toggle(),
        child: header,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildScoreRow(Score score, int index) {
    final hasRank = score.rank > 0 && score.rankTotal > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? null : accentColorNotifier.value.withValues(alpha: 0.03),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 35,
            child: hasRank
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(score.courseName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      const SizedBox(height: 3),
                      _courseRankBadge(score),
                    ],
                  )
                : Text(score.courseName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
          ),
          _cellText(score.category, 1.2),
          _cellText(score.credit.toStringAsFixed(1), 0.8),
          _scoreText(score.score, score.grade, 0.8),
          _cellText(score.gpa.toStringAsFixed(2), 0.8),
        ],
      ),
    );
  }

  /// 学期平均绩点排名徽章（「班级 3/58」+ 前百分比）
  ///
  /// 与课程级徽章同一套配色（[rankHighlightColor] 四档），
  /// 但此处语义是「学期总评绩点在班级的位次」，故前缀「班级」以示区分。
  Widget _termRankBadge(BingoRankInfo info) {
    final dark = isDark(context);
    final accent = rankHighlightColor(info, isDark: dark);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: dark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('班级',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: accent.withValues(alpha: 0.85))),
              const SizedBox(width: 4),
              Text('${info.rank}/${info.total}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(rankTopPercentText(info),
            style: TextStyle(fontSize: 10, color: textHint(context))),
      ],
    );
  }

  /// 课程级排名徽章（「12/58」+ 前百分比），配色按名次占比四档
  Widget _courseRankBadge(Score score) {
    final info = BingoRankInfo(rank: score.rank, total: score.rankTotal);
    final accent =
        rankHighlightColor(info, isDark: isDark(context));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark(context) ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${score.rank}/${score.rankTotal}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(rankTopPercentText(info),
              style: TextStyle(fontSize: 10, color: textHint(context)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _headerText(String text, double flex) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColorNotifier.value.withValues(alpha: 0.7))),
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
            color: isPass ? Colors.green[700] : const Color(0xFFC2410C),
          ),
          children: [
            TextSpan(
              text: '\n$grade',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isPass ? Colors.green[400] : const Color(0xFFC2410C).withValues(alpha: 0.85),
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
            Icon(Icons.error_outline_rounded, size: 48, color: textHint(context)),
            const SizedBox(height: 16),
            Text('获取成绩失败',
                style: TextStyle(fontSize: 16, color: textPrimary(context))),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: textSecondary(context)),
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
                backgroundColor: accentColorNotifier.value,
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
