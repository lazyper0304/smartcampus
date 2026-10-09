import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/input_adaptation.dart';
import '../core/ios_kit.dart';
import '../core/glass_action_button.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../main.dart';
import 'wspj.dart';
import 'wspj_answer_sheet.dart';
import 'wspj_service.dart';

/// 网上评教答题页（原生）
///
/// 数据链路（ehall jwapp「网上评教」jwwspj，appId=5077744448763966）：
/// - [WspjService.fetchPaper] → `cxwjzbxq.do`（**题目 + 选项一体**）
/// - 作答状态全部保存在 [WspjAnswerSheet]，指标代码 `ZBDM` 为唯一键
/// - 提交走 [WspjService.submitPaper] → `pj.do`
///
/// 题型（[WspjQuestion.zblxdm]，2026-10-09 实测）：
/// - `01` 单选：选项由同一接口按 `ZBDM` 展开多行，`DASM`=选项文字、`DAPX`=档位
/// - `02` 主观：多行文本，最少字数取 `BZ`（实测 20）
/// - `03` 分值：0..`FZ` 打分（本班 24 道，`FZ` 逐题 2~14）
class WspjAnswerPage extends StatefulWidget {
  final SharedHttpClient client;
  final WspjQuestionnaire questionnaire;
  final String userId;

  const WspjAnswerPage({
    super.key,
    required this.client,
    required this.questionnaire,
    required this.userId,
  });

  @override
  State<WspjAnswerPage> createState() => _WspjAnswerPageState();
}

class _WspjAnswerPageState extends State<WspjAnswerPage> {
  late final WspjService _service;

  /// 问卷说明（来自列表接口），折叠在顶部
  bool _showIntro = false;

  WspjPaper? _paper;
  WspjAnswerSheet? _sheet;

  /// 从 `cxpgjg.do` 回填的答案数（0 = 未评过）
  int _prefilled = 0;
  bool _isLoading = true;
  String? _error;
  bool _submitting = false;

  /// 一键填充分值比例（0.90 / 0.95 / 1.00）
  double _fillRatio = WspjAnswerSheet.kDefaultFillRatio;

  @override
  void initState() {
    super.initState();
    _service = WspjService(client: widget.client);
    _load();
  }

  // ==================== 数据加载 ====================

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final paper = await _service.fetchPaper(
        questionnaire: widget.questionnaire,
      );
      if (!mounted) return;
      if (paper.total == 0) {
        setState(() {
          _error = '该问卷暂无题目（可能评教未开始，或当前不在评教时间窗口内）';
          _isLoading = false;
        });
        return;
      }
      final sheet = WspjAnswerSheet(paper);
      // 已评过的问卷回填历史答案（cxpgjg.do），实现「查看 / 修改」
      var prefilled = 0;
      if (widget.questionnaire.isDone) {
        prefilled = await _prefill(sheet, paper);
      }
      if (!mounted) {
        sheet.dispose();
        return;
      }
      final old = _sheet;
      setState(() {
        _paper = paper;
        _sheet = sheet;
        _prefilled = prefilled;
        _isLoading = false;
      });
      old?.dispose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// 从 `cxpgjg.do` 拉历史答案预填；失败不阻断（当作未评处理）
  Future<int> _prefill(WspjAnswerSheet sheet, WspjPaper paper) async {
    try {
      final results = await _service.fetchResults(
        wjdm: paper.questionnaire.wjdm,
        jxbid: paper.questionnaire.jxbid,
      );
      if (results.isEmpty) return 0;
      var n = 0;
      for (final r in results) {
        if (!r.hasAnswer) continue;
        final q = paper.questions.where((x) => x.zbdm == r.zbdm).firstOrNull;
        if (q == null) continue;
        final v = r.answerText;
        if (q.isSubjective) {
          sheet.setSubjective(q, v);
          sheet.controllerFor(q).text = v;
        } else if (q.isScore) {
          final s = int.tryParse(v.trim());
          if (s == null) continue;
          sheet.setScore(q, s);
          sheet.controllerFor(q).text = '$s';
        } else {
          sheet.setRaw(q, v);
        }
        n++;
      }
      return n;
    } catch (e) {
      debugPrint('Wspj._prefill 忽略（$e）');
      return 0;
    }
  }

  // ==================== 一键填写 ====================

  /// 一键填写：分值题按比例取高分、选择题选最高档、主观题填默认好评文本
  ///
  /// ⚠️ **只填不提交**。评教提交不可逆且 `pj.do` 端点尚未确认，
  /// 故这里填完后仍需用户点「提交评教」并过二次确认。
  /// 比例说明：服务端对分数有上限校验，**不建议全取满分**；
  /// 0.95 落在问卷说明「优秀 = 标准分 × 90~100%」区间。
  Future<void> _autoFill() async {
    final paper = _paper;
    final sheet = _sheet;
    if (paper == null || sheet == null) return;

    final preview = sheet.previewAutoFill(ratio: _fillRatio);
    if (preview.total == 0) {
      await _alert(title: '无法一键填写', message: '该问卷未返回题目。');
      return;
    }

    final go = await _confirmAutoFill(preview);
    if (go != true || !mounted) return;

    final n = sheet.applyAutoFill(ratio: _fillRatio);
    setState(() {
      // 标记为「已一键填写过」，隐藏回填提示条（避免两行提示叠加）
      if (n > 0) _prefilled = 0;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已一键填写 $n 道题'
            '${preview.scoreQuestions > 0 ? '，分值合计 ${preview.predictedTotal}/${preview.maxTotal}' : ''}，请核对后提交'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 一键填写前的确认弹窗（展示各题型将如何填充）
  Future<bool?> _confirmAutoFill(WspjAutoFillPreview preview) {
    final lines = <String>[];
    if (preview.scoreQuestions > 0) {
      lines.add('· 分值题 ${preview.scoreQuestions} 道：按 '
          '${(preview.ratio * 100).round()}% 比例取分，'
          '合计 ${preview.predictedTotal} / ${preview.maxTotal} 分'
          '（${preview.percent}%）');
    }
    if (preview.choiceQuestions > 0) {
      lines.add('· 单选/星级题 ${preview.choiceQuestions} 道：选择最高一档');
    }
    if (preview.subjectiveQuestions > 0) {
      lines.add('· 主观题 ${preview.subjectiveQuestions} 道：填入默认好评文本');
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: glassDialog(
          context: ctx,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('一键填写',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  lines.join('\n') +
                  '\n\n填充后仍可逐题修改，确认无误后再点底部「提交评教」。',
                  style: TextStyle(
                      fontSize: 13, height: 1.6, color: textPrimary(ctx)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GlassActionButton(
                        label: '取消',
                        secondary: true,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassActionButton(
                        label: '填充',
                        onPressed: () => Navigator.of(ctx).pop(true),
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 提交 ====================

  Future<void> _submit() async {
    final sheet = _sheet;
    final paper = _paper;
    if (sheet == null || paper == null) return;

    final missing = sheet.unansweredRequired(paper);
    if (missing.isNotEmpty) {
      await _alert(
        title: '还有题目未作答',
        message: '以下 ${missing.length} 道必答题未完成：\n\n'
            '${missing.take(5).map((e) => '· $e').join('\n')}'
            '${missing.length > 5 ? '\n…等共 ${missing.length} 题' : ''}',        confirmText: '去作答',
        onConfirm: () {
          // 滚动到第一道未答题
          final target = sheet.firstUnansweredIndex(paper);
          if (target != null) {
            final key = _cardKeys[target];
            final ctx = key.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 320),
                alignment: 0.12,
              );
            }
          }
        },
      );
      return;
    }

    final ok = await _confirmSubmit(paper, sheet);
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      await _service.submitPaper(paper: paper, sheet: sheet);
      if (!mounted) return;
      await _alert(
        title: '提交成功',
        message: '评教已提交，感谢您的反馈。',
        confirmText: '完成',
      );
      if (!mounted) return;
      // 返回列表并通知刷新状态
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await _alert(
        title: '提交失败',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _alert({
    required String title,
    required String message,
    String confirmText = '好的',
    VoidCallback? onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: glassDialog(
          context: ctx,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: TextStyle(
                          fontSize: 13, height: 1.6, color: textPrimary(ctx)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GlassActionButton(
                  label: confirmText,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirm?.call();
                  },
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmSubmit(WspjPaper paper, WspjAnswerSheet sheet) {
    final readOnly = widget.questionnaire.isDone;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: glassDialog(
          context: ctx,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('确认提交评教',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  '${widget.questionnaire.displayTitle}\n\n'
                  '共 ${paper.total} 题，已作答 ${sheet.answeredCount(paper)} 题'
                  '${sheet.unansweredRequired(paper).isEmpty ? '，必答题已全部完成' : ''}。\n\n'
                  '提交后将同步到教务系统，请确认无误。',
                  style: TextStyle(
                      fontSize: 13, height: 1.6, color: textPrimary(ctx)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GlassActionButton(
                        label: '取消',
                        secondary: true,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassActionButton(
                        label: readOnly ? '重新提交' : '提交',
                        onPressed: () => Navigator.of(ctx).pop(true),
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BUILD ====================

  final List<GlobalKey> _cardKeys = [];

  @override
  void dispose() {
    _sheet?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 卡片 GlobalKey 按题目数量对齐（列表长度变化时补齐）
    final total = _paper?.total ?? 0;
    while (_cardKeys.length < total) {
      _cardKeys.add(GlobalKey());
    }

    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('评教问卷'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _load,
              tooltip: '重新加载',
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final paper = _paper;
    if (_error != null || paper == null || _sheet == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 52, color: textHint(context)),
              const SizedBox(height: 12),
              Text('加载失败',
                  style: TextStyle(fontSize: 16, color: textSecondary(context))),
              const SizedBox(height: 8),
              Text(_error ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textHint(context))),
              const SizedBox(height: 16),
              GlassActionButton(
                label: '重试',
                icon: Icons.refresh,
                secondary: true,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildHeaderCard(paper),
        const SizedBox(height: 14),
        _buildProgressCard(paper),
        if (_prefilled > 0) ...[
          const SizedBox(height: 10),
          _buildPrefillNote(),
        ],
        const SizedBox(height: 18),
        for (int i = 0; i < paper.total; i++) ...[
          _buildQuestionCard(paper, paper.questions[i], i),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _buildFooterNote(paper),
      ],
    );
  }

  // ==================== 顶部信息卡 ====================

  Widget _buildHeaderCard(WspjPaper paper) {
    final q = widget.questionnaire;
    return IosCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  q.displayTitle,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (q.isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: textHint(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('已完成',
                      style: TextStyle(
                          fontSize: 11,
                          color: textHint(context),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          if (q.wjmc.isNotEmpty && q.wjmc != q.displayTitle) ...[
            const SizedBox(height: 4),
            Text(q.wjmc,
                style:
                    TextStyle(fontSize: 12.5, color: textSecondary(context))),
          ],
          if (paper.courseName.isNotEmpty || paper.teacherName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (paper.courseName.isNotEmpty)
                  _metaTag(Icons.book_outlined, paper.courseName),
                if (paper.teacherName.isNotEmpty)
                  _metaTag(Icons.person_outline_rounded, paper.teacherName),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (q.zfz.isNotEmpty) _tag('${q.zfz} 分'),
              if (q.xnxqDisplay.isNotEmpty) _tag(q.xnxqDisplay),
              _tag('${paper.total} 题'),
              if (paper.choiceCount > 0)
                _tag('单选 ${paper.choiceCount}'),
              if (paper.scoreCount > 0) _tag('分值 ${paper.scoreCount}'),
              if (paper.subjectiveCount > 0)
                _tag('主观 ${paper.subjectiveCount}'),
            ],
          ),
          if (q.wjsm.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildIntro(q.wjsm),
          ],
        ],
      ),
    );
  }

  Widget _buildIntro(String wjsm) {
    final content = Text(
      wjsm,
      style: TextStyle(
          fontSize: 12.5, height: 1.6, color: textSecondary(context)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showIntro = !_showIntro),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: accentColorNotifier.value),
                const SizedBox(width: 6),
                Text('问卷说明',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: accentColorNotifier.value,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(_showIntro ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16, color: accentColorNotifier.value),
              ],
            ),
          ),
        ),
        if (_showIntro)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: content,
          ),
      ],
    );
  }

  // ==================== 作答进度卡 ====================

  Widget _buildProgressCard(WspjPaper paper) {
    final sheet = _sheet!;
    final answered = sheet.answeredCount(paper);
    final missing = sheet.unansweredRequired(paper).length;
    final ratio = paper.total == 0 ? 0.0 : answered / paper.total;
    final accent = accentColorNotifier.value;
    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('作答进度',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary(context))),
              const Spacer(),
              Text('$answered / ${paper.total}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: textHint(context).withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                missing == 0 ? accent : const Color(0xFFF5A623),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            missing == 0
                ? '必答题已全部完成，可以提交'
                : '还有 $missing 道必答题未作答',
            style: TextStyle(
                fontSize: 12,
                color: missing == 0 ? accent : const Color(0xFFC2410C)),
          ),
          const SizedBox(height: 12),
          _buildAutoFillRow(sheet),
        ],
      ),
    );
  }

  /// 一键填写区：分值比例切换 + 填充按钮 + 预估总分
  ///
  /// ⚠️ 分值比例**默认 95%** 而非 100%：服务端对评教分数有上限/分布校验，
  /// 全取满分易被判异常；0.95 落在问卷说明「优秀 = 标准分 × 90~100%」内。
  Widget _buildAutoFillRow(WspjAnswerSheet sheet) {
    final preview = sheet.previewAutoFill(ratio: _fillRatio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('一键填写',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary(context))),
            const Spacer(),
            if (preview.scoreQuestions > 0)
              Text('预估 ${preview.predictedTotal}/${preview.maxTotal} 分 · '
                  '${preview.percent}%',
                  style: TextStyle(fontSize: 11.5, color: textHint(context))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final r in WspjAnswerSheet.kFillRatioPresets)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ratioChip(r, _fillRatio == r, () {
                  setState(() => _fillRatio = r);
                }),
              ),
            const Spacer(),
            SizedBox(
              height: 32,
              child: GlassActionButton(
                label: '一键填写',
                icon: Icons.bolt_rounded,
                onPressed: _autoFill,
                secondary: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('分值题按上述比例取高分，单选取最高档，主观题填默认好评文本；'
            '填写后可逐题修改，提交需再确认。',
            style: TextStyle(fontSize: 11, height: 1.5, color: textHint(context))),
        if (preview.scoreQuestions > 0 && _fillRatio == 1.0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('提示：全卷取满分可能被服务端判为异常评分。',
                style: TextStyle(fontSize: 11, color: const Color(0xFFC2410C))),
          ),
      ],
    );
  }

  Widget _ratioChip(double ratio, bool selected, VoidCallback onTap) {
    final accent = accentColorNotifier.value;
    return Clickable(
      onTap: onTap,
      borderRadius: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : textHint(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${(ratio * 100).round()}%',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected ? accent : textSecondary(context))),
      ),
    );
  }

  /// 已评问卷的答案回填提示
  Widget _buildPrefillNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: textHint(context).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, size: 15, color: textHint(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已回填你上次提交的 $_prefilled 题答案，可修改后重新提交。',
              style: TextStyle(fontSize: 12, height: 1.5, color: textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 题目卡 ====================

  Widget _buildQuestionCard(WspjPaper paper, WspjQuestion q, int index) {
    final sheet = _sheet!;
    final answered =
        q.isSubjective ? sheet.isSubjectiveSatisfied(q) : sheet.isAnswered(q);
    final acc = accentColorNotifier.value;
    return IosCard(
      key: _cardKeys[index],
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (answered ? acc : textHint(context))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: answered ? acc : textHint(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.zbsm.isEmpty ? '第 ${index + 1} 题' : q.zbsm,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            height: 1.45)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _miniTag(q.zbflDisplay.isEmpty ? q.txLabel : q.zbflDisplay),
                        _miniTag(q.txLabel),
                        if (q.isScore && q.maxScore != null)
                          _miniTag('满分 ${q.fz}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAnswerArea(paper, q),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(WspjPaper paper, WspjQuestion q) {
    if (q.isSubjective) return _buildSubjectiveInput(q);
    if (q.isScore) return _buildScoreInput(q);
    return _buildOptionList(paper, q);
  }

  /// 单选/星级：选项卡片列表（同一 `ZBDM` 的多行）
  Widget _buildOptionList(WspjPaper paper, WspjQuestion q) {
    final sheet = _sheet!;
    final options = paper.optionsOf(q);
    final selected = sheet.answerOf(q);
    if (options.isEmpty) {
      return _noOptionsHint();
    }
    return Column(
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildOptionTile(
                q, o, selected != null && selected == _optionValue(o), () {
              setState(() => sheet.selectOption(q, o));
            }),
          ),
      ],
    );
  }

  /// 选项回传值：`DADM` 优先，为空退化用 `DAPX`
  static String _optionValue(WspjQuestion o) =>
      o.dadm.isNotEmpty ? o.dadm : o.dapx;

  Widget _buildOptionTile(
      WspjQuestion q, WspjQuestion o, bool selected, VoidCallback onTap) {
    final accent = accentColorNotifier.value;
    return Clickable(
      onTap: onTap,
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : textHint(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? accent : textHint(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(o.dasm,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? accent : textPrimary(context))),
            ),
            if (o.dapx.isNotEmpty)
              Text('第 ${o.dapx} 档',
                  style: TextStyle(fontSize: 11, color: textHint(context))),
          ],
        ),
      ),
    );
  }

  /// 主观题：多行输入 + 字数（`BZ` = 最少字数，实测 20）
  Widget _buildSubjectiveInput(WspjQuestion q) {
    final sheet = _sheet!;
    final controller = sheet.controllerFor(q);
    final min = q.minWords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: 6,
          minLines: 3,
          onChanged: (_) => setState(() => sheet.setSubjective(q, controller.text)),
          decoration: InputDecoration(
            hintText: min == null
                ? '请输入您的意见或建议…'
                : '请输入您的意见或建议（至少 $min 字）…',
            hintStyle: TextStyle(fontSize: 13, color: textHint(context)),
            filled: true,
            fillColor: textHint(context).withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
          style: TextStyle(fontSize: 13.5, height: 1.5, color: textPrimary(context)),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final n = value.text.characters.length;
            final lack = min != null && n < min;
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                min == null ? '$n 字' : '$n / $min 字',
                style: TextStyle(
                    fontSize: 11,
                    color: lack ? const Color(0xFFC2410C) : textHint(context)),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 分值题：0..FZ 打分 + 快捷按钮
  ///
  /// 实测本班 24 道分值题 `FZ` 为 2~14 不等，因此快捷档按 `FZ` 动态生成
  /// （`FZ<=5` 全量、`FZ<=10` 四档、更大则三档）。
  Widget _buildScoreInput(WspjQuestion q) {
    final sheet = _sheet!;
    final max = q.maxScore ?? 10;
    final current = sheet.answerOf(q);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: sheet.controllerFor(q),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() => sheet.setScore(q, n?.clamp(0, max)));
                },
                decoration: InputDecoration(
                  hintText: '0 - $max',
                  hintStyle: TextStyle(fontSize: 13, color: textHint(context)),
                  filled: true,
                  fillColor: textHint(context).withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                ),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary(context)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('本题满分 $max 分',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in _scorePresets(max))
              _scoreChip(v, current == '$v', () {
                sheet.setScore(q, v);
                sheet.controllerFor(q).text = '$v';
                setState(() {});
              }),
          ],
        ),
      ],
    );
  }

  List<int> _scorePresets(int max) {
    if (max <= 5) return [for (var i = 0; i <= max; i++) i];
    if (max <= 10) return [0, (max * 0.6).round(), (max * 0.8).round(), max];
    return [0, max ~/ 2, max];
  }

  Widget _scoreChip(int value, bool selected, VoidCallback onTap) {
    final accent = accentColorNotifier.value;
    return Clickable(
      onTap: onTap,
      borderRadius: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : textHint(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$value',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? accent : textSecondary(context))),
      ),
    );
  }

  Widget _noOptionsHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC2410C).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 15, color: Color(0xFFC2410C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('该题未返回可选项，可能是问卷配置异常',
                style: TextStyle(fontSize: 12, color: textPrimary(context))),
          ),
        ],
      ),
    );
  }

  Widget _metaTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textHint(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textSecondary(context)),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: textSecondary(context),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: accentColorNotifier.value,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _miniTag(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: textHint(context), fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildFooterNote(WspjPaper paper) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '评教结果匿名，仅用于教学质量改进。提交前请确认已完成所有必答题。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, height: 1.6, color: textHint(context)),
      ),
    );
  }

  // ==================== 底部提交栏 ====================

  Widget? _buildBottomBar() {
    final paper = _paper;
    final sheet = _sheet;
    if (paper == null || sheet == null) return null;
    final missing = sheet.unansweredRequired(paper).length;
    final total = paper.total;
    final answered = sheet.answeredCount(paper);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom * 0.5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: dividerColor(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$answered / $total',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary(context))),
              Text(missing == 0 ? '已完成' : '缺 $missing 题',
                  style: TextStyle(
                      fontSize: 11,
                      color: missing == 0
                          ? accentColorNotifier.value
                          : const Color(0xFFC2410C))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GlassActionButton(
              label: _submitting ? '提交中…' : '提交评教',
              icon: Icons.check_rounded,
              fullWidth: true,
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// 便于抓包比对：打印提交报文（配合真机 debug 使用）
///
/// 服务端提交契约尚未抓包确认时，先在真机 logcat 打出这段 JSON，
/// 与网页端 F12 抓到的 `pj.do` 请求体逐字段比对即可校准。
String debugPaperJson(WspjPaper paper, WspjAnswerSheet sheet) =>
    jsonEncode(sheet.toRequestParam());
