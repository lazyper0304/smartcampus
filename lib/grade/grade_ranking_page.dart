import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassStatusBarStyle;

import '../core/input_adaptation.dart';
import '../core/ios_kit.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../main.dart' show accentColorNotifier;
import 'bingo_score_service.dart';
import 'grade_rank_style.dart';
import 'score.dart';
import 'score_service.dart';

/// 成绩排名页（数据源：Bingo `GET /grade/ranking`）
///
/// 从成绩页 AppBar 的「排名」按钮进入。排名按学期查询，故本页自带
/// 学期选择器；默认展示最新学期。
///
/// 内容分三块：
/// 1. 班级排名主卡（大数字名次 + 前百分比 + 学期绩点）
/// 2. 专业 / 学院排名（两枚次级指标）
/// 3. 课程类别均分对比（本人均分 vs 同类均分）
/// 4. 课程级排名列表（`/grade` items 的 `rank` / `rank_total`）
class GradeRankingPage extends StatefulWidget {
  /// 已加载的成绩列表（成绩页传入，避免重复请求）
  final List<Score> scores;

  /// 成绩页已按学期拉好的排名缓存（学期代码 → 排名）。
  ///
  /// 成绩页为了在每个学期卡片上显示平均绩点排名，已并发查过全部学期，
  /// 此处直接复用，避免进入本页再打一遍同样的请求。
  final Map<String, BingoGradeRanking> prefetched;

  const GradeRankingPage({
    super.key,
    required this.scores,
    this.prefetched = const {},
  });

  @override
  State<GradeRankingPage> createState() => _GradeRankingPageState();
}

class _GradeRankingPageState extends State<GradeRankingPage> {
  late List<String> _semesters;
  late String _semester;

  BingoGradeRanking? _ranking;
  bool _isLoading = true;
  String? _error;

  /// 本页会话内的排名缓存（初始来自成绩页预取）
  late Map<String, BingoGradeRanking> _cache;

  /// 排名请求代号：切学期时自增，过期响应直接丢弃（防竞态串档）
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _semesters = semestersOf(widget.scores);
    _semester = _semesters.isNotEmpty ? _semesters.first : '';
    _cache = Map<String, BingoGradeRanking>.from(widget.prefetched);
    final cached = _cache[_semester];
    if (cached != null) {
      // 预取已命中：直接渲染，不再请求
      _ranking = cached;
      _isLoading = false;
    } else {
      _loadRanking();
    }
  }

  /// 是否已有可用缓存（用于跳过请求）
  bool _hasCache(String semester) =>
      semester.isEmpty ? _cache.containsKey('') : _cache.containsKey(semester);

  Future<void> _loadRanking({bool force = false}) async {
    final sem = _semester;
    if (!force && _hasCache(sem) && _cache[sem] != null) {
      final hit = _cache[sem]!;
      setState(() {
        _ranking = hit;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    final gen = ++_reqGen;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ScoreService().fetchRanking(
        semester: sem.isEmpty ? null : sem,
      );
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _ranking = data;
        _isLoading = false;
        _cache[sem] = data;
      });
    } catch (e) {
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _pickSemester() {
    if (_semesters.length <= 1) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _buildSemesterSheet(sheetContext),
    );
  }

  Widget _buildSemesterSheet(BuildContext sheetContext) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(sheetContext).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(sheetContext).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
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
          Text('选择学期',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary(context))),
          const SizedBox(height: 8),
          for (final s in _semesters)
            IosListTile(
              title: semesterLabel(s),
              trailing: s == _semester
                  ? Icon(Icons.check_rounded,
                      size: 20, color: accentColorNotifier.value)
                  : null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (s == _semester) return;
                setState(() => _semester = s);
                _loadRanking();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('成绩排名'),
          centerTitle: true,
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadRanking(force: true),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _ranking == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _ranking == null) {
      return _buildError();
    }

    final ranking = _ranking ?? const BingoGradeRanking();
    final courseRanks = rankedScoresOf(widget.scores, _semester);
    final dark = isDark(context);
    final accent = accentColorNotifier.value;

    return RefreshIndicator(
      onRefresh: () => _loadRanking(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 学期选择器（仅一个学期时隐藏）
          if (_semesters.length > 1) ...[
            _buildSemesterCard(accent),
            const SizedBox(height: 12),
          ],
          // 班级排名主卡
          _buildClassRankCard(ranking, dark),
          // 专业 / 学院
          if (isRankValid(ranking.majorRank) || isRankValid(ranking.collegeRank)) ...[
            const SizedBox(height: 12),
            _buildScopeRow(ranking, dark),
          ],
          // 提示（如「该学期数据不完整」）
          if (ranking.warning.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildWarning(ranking.warning),
          ],
          // 课程类别均分对比
          if (ranking.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCategoryCard(ranking.categories),
          ],
          // 课程级排名
          if (courseRanks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCourseRankCard(courseRanks, dark),
          ],
          // 三档与分类全空
          if (!isRankValid(ranking.classRank) &&
              !isRankValid(ranking.majorRank) &&
              !isRankValid(ranking.collegeRank) &&
              ranking.categories.isEmpty &&
              courseRanks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text('该学期暂无排名数据',
                    style: TextStyle(fontSize: 14, color: textHint(context))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(Color accent) {
    return Clickable(
      onTap: _pickSemester,
      borderRadius: 14,
      child: IosCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('排名学期',
                      style: TextStyle(
                          fontSize: 11, color: textSecondary(context))),
                  const SizedBox(height: 2),
                  Text(
                    _semester.isEmpty
                        ? '全部学期'
                        : semesterLabel(_semester),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary(context)),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.expand_more_rounded,
                  size: 20, color: textHint(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassRankCard(BingoGradeRanking ranking, bool dark) {
    final info = ranking.classRank;
    if (!isRankValid(info)) {
      return IosCard(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(_isLoading ? '排名加载中…' : '暂无班级排名数据',
              style: TextStyle(fontSize: 14, color: textHint(context))),
        ),
      );
    }

    // isRankValid 只是布尔函数，不会做类型提升 → 手动取一次非空
    final rank = info!;
    final accent = rankHighlightColor(rank, isDark: dark);

    return IosCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text('班级排名',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary(context))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${rank.rank}',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${rank.total}',
                    style: TextStyle(
                        fontSize: 20, color: textSecondary(context))),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rankTopPercentText(rank),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                  const SizedBox(height: 4),
                  Text(
                    rank.gpa > 0 ? '学期绩点 ${_fmtGpa(rank.gpa)}' : '',
                    style: TextStyle(
                        fontSize: 13, color: textSecondary(context)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeRow(BingoGradeRanking ranking, bool dark) {
    return Row(
      children: [
        if (isRankValid(ranking.majorRank))
          Expanded(
            child: _buildScopeTile(
              label: '专业排名',
              info: ranking.majorRank!,
              icon: Icons.school_rounded,
              dark: dark,
            ),
          ),
        if (isRankValid(ranking.majorRank) &&
            isRankValid(ranking.collegeRank))
          const SizedBox(width: 12),
        if (isRankValid(ranking.collegeRank))
          Expanded(
            child: _buildScopeTile(
              label: '学院排名',
              info: ranking.collegeRank!,
              icon: Icons.account_balance_rounded,
              dark: dark,
            ),
          ),
      ],
    );
  }

  Widget _buildScopeTile({
    required String label,
    required BingoRankInfo info,
    required IconData icon,
    required bool dark,
  }) {
    final accent = rankHighlightColor(info, isDark: dark);
    return IosCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: textSecondary(context)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, color: textSecondary(context)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${info.rank}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(width: 3),
              Text('/${info.total}',
                  style: TextStyle(
                      fontSize: 13, color: textSecondary(context))),
              const Spacer(),
              Text(rankTopPercentText(info),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ],
          ),
          if (info.gpa > 0) ...[
            const SizedBox(height: 6),
            Text('绩点 ${_fmtGpa(info.gpa)}',
                style: TextStyle(fontSize: 11, color: textHint(context))),
          ],
        ],
      ),
    );
  }

  Widget _buildWarning(String warning) {
    return IosCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: textSecondary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(warning,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: textSecondary(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(List<BingoCategoryScore> categories) {
    final accent = accentColorNotifier.value;
    return IosCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('课程类别均分对比',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary(context))),
          const SizedBox(height: 4),
          Text('与同类课程平均绩点的差值',
              style: TextStyle(fontSize: 12, color: textHint(context))),
          const SizedBox(height: 14),
          for (int i = 0; i < categories.length; i++) ...[
            _buildCategoryRow(categories[i], accent),
            if (i != categories.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(BingoCategoryScore c, Color accent) {
    final diff = c.avgGpa - c.peerAvg;
    final above = diff > 0;
    final near = diff.abs() < 0.005;
    final diffColor = near
        ? textSecondary(context)
        : (above
            ? (isDark(context) ? const Color(0xFF5AD87F) : const Color(0xFF34C759))
            : const Color(0xFFC2410C));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(c.category.isEmpty ? '未分类' : c.category,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: textPrimary(context)),
                  overflow: TextOverflow.ellipsis),
            ),
            if (c.count > 0)
              Text('${c.count} 门',
                  style: TextStyle(fontSize: 11, color: textHint(context))),
          ],
        ),
        const SizedBox(height: 8),
        // 双条对比：本人（实色）vs 同类均分（淡底）
        _bar(c.avgGpa, accent, 1),
        const SizedBox(height: 5),
        _bar(c.peerAvg, textHint(context).withValues(alpha: 0.5), 1),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('本人 ${_fmtGpa(c.avgGpa)}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textSecondary(context))),
            const SizedBox(width: 10),
            Text('同类均分 ${_fmtGpa(c.peerAvg)}',
                style: TextStyle(fontSize: 11, color: textHint(context))),
            const Spacer(),
            if (!near)
              Text(
                '${above ? '+' : ''}${diff.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: diffColor),
              ),
          ],
        ),
      ],
    );
  }

  /// 绩点条：按 0~5.0 映射宽度
  Widget _bar(double gpa, Color color, double max) {
    final ratio = (gpa / (5.0 * max)).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 6, color: color.withValues(alpha: 0.12)),
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(height: 6, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseRankCard(List<Score> scores, bool dark) {
    return IosCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('课程排名',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary(context))),
          const SizedBox(height: 4),
          Text('同一课程内同学的成绩位次',
              style: TextStyle(fontSize: 12, color: textHint(context))),
          const SizedBox(height: 12),
          for (int i = 0; i < scores.length; i++) ...[
            _buildCourseRankRow(scores[i], dark),
            if (i != scores.length - 1)
              Divider(
                  height: 18,
                  thickness: 0.5,
                  color: textSecondary(context).withValues(alpha: 0.25)),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseRankRow(Score score, bool dark) {
    final accent =
        rankHighlightColor(BingoRankInfo(rank: score.rank, total: score.rankTotal),
            isDark: dark);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('${score.rank} / ${score.rankTotal}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(score.courseName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary(context)),
                    overflow: TextOverflow.ellipsis),
                if (score.teacher.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(score.teacher,
                      style: TextStyle(fontSize: 11, color: textHint(context)),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          badge,
        ],
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
            Text('获取排名失败',
                style: TextStyle(fontSize: 16, color: textPrimary(context))),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: textSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadRanking(force: true),
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

  static String _fmtGpa(double gpa) =>
      gpa == gpa.roundToDouble() ? gpa.toStringAsFixed(1) : gpa.toStringAsFixed(2);
}