import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'wspj.dart';
import 'wspj_bingo_mapper.dart';

/// 答卷状态容器（按指标代码 `ZBDM` 存储作答）
///
/// ## 答案字段语义（2026-10-09 真机实测 `cxpgjg.do` 确认）
/// 服务端结果表只有两个字段承载作答内容：
/// - `DA`：分值题（`ZBLXDM=03`）的数值、选择题（`ZBLXDM=01`）的选项值
/// - `ZGDA`：主观题（`ZBLXDM=02`）的文本
///
/// 提交时按同一套字段名回填，见 [toAnswerRows]。
class WspjAnswerSheet {
  final WspjPaper _paper;

  /// `ZBDM` → 答案值（分值题为数字串、选择题为选项 `DADM`、主观题为文本）
  final Map<String, String> _answers = {};

  /// `ZBDM` → 文本控制器（主观题/分值题复用，避免重建丢光标）
  final Map<String, TextEditingController> _controllers = {};

  WspjAnswerSheet(this._paper);

  // ==================== 答案键 ====================

  /// **三维答案键**：`题目_教师_教学班`
  ///
  /// ⚠️ 不可只用 `ZBDM` 作键：Bingo 一份问卷可含**多位被评教师**
  /// （实测 25 题 × 6 教师 = 150 条），同一 `ZBDM` 下有 6 行不同教师，
  /// 用 `ZBDM` 作键会互相覆盖 —— 表现为「只填得上一位教师，其余教师无法作答」。
  static String keyOf(WspjQuestion q) => composeRowKey(q.zbdm, q.bpr, q.jxbid);

  // ==================== 读写 ====================

  String? answerOf(WspjQuestion q) => _answers[keyOf(q)];

  bool isAnswered(WspjQuestion q) {
    final v = _answers[keyOf(q)];
    if (v == null || v.isEmpty) return false;
    if (q.isScore) {
      final n = int.tryParse(v);
      return n != null && n >= 0;
    }
    return true;
  }

  /// 主观题：字数不足时不算已作答（`BZ` = 最少字数，实测 20）
  bool isSubjectiveSatisfied(WspjQuestion q) {
    final min = q.minWords;
    if (min == null) return isAnswered(q);
    final text = _answers[keyOf(q)] ?? '';
    return text.trim().characters.length >= min;
  }

  /// 选择题：选中某个选项行
  ///
  /// 答案取该选项的 `DADM`（答案代码）；`DADM` 为空时退化用 `DAPX`（档位），
  /// 保证任何情况下都有值可提交。
  void selectOption(WspjQuestion q, WspjQuestion option) {
    _answers[keyOf(q)] = option.dadm.isNotEmpty ? option.dadm : option.dapx;
  }

  void setSubjective(WspjQuestion q, String text) {
    if (text.trim().isEmpty) {
      _answers.remove(keyOf(q));
    } else {
      _answers[keyOf(q)] = text;
    }
  }

  void setScore(WspjQuestion q, int? score) {
    if (score == null) {
      _answers.remove(keyOf(q));
    } else {
      _answers[keyOf(q)] = '$score';
    }
  }

  /// 直接写入原始答案值（用于从 `cxpgjg.do` 回填历史答案）
  void setRaw(WspjQuestion q, String value) {
    if (value.isEmpty) {
      _answers.remove(keyOf(q));
    } else {
      _answers[keyOf(q)] = value;
    }
  }

  /// 取得（并惰性创建）题目的文本控制器
  TextEditingController controllerFor(WspjQuestion q) => _controllers
      .putIfAbsent(keyOf(q),
          () => TextEditingController(text: _answers[keyOf(q)] ?? ''));

  /// 释放全部控制器（页面 dispose 时调用）
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  // ==================== 一键填充 ====================

  /// 分值题按比例取分的取值规则
  ///
  /// ⚠️ **服务端对评教分数有上限/分布校验，全卷满分极易被判异常**，
  /// 因此默认不取 `FZ` 原值，而是按比例（默认 [kDefaultFillRatio] = 0.95）
  /// 四舍五入，再夹到 `1..FZ`。这样在「尽可能高」与「不撞上限」之间取平衡。
  ///
  /// 例（`FZ` = 2,3,3,2,3,4,4,4,6,5,6,3,3,3,6,3,2,2,2,2,2,2,8,14,8）：
  /// `FZ=14 → 13`、`FZ=8 → 8`、`FZ=2 → 2`，总分明显低于满分 102 但处于
  /// 问卷说明中「优秀 = 标准分 × 90~100%」的区间。
  static int scoreFor(WspjQuestion q, double ratio) {
    final max = q.maxScore;
    if (max == null || max <= 0) return 0;
    if (max == 1) return 1;
    final v = (max * ratio).round();
    return v.clamp(1, max);
  }

  /// 一键填充的默认分值比例（问卷说明：优秀 = 标准分 × 90~100%）
  static const double kDefaultFillRatio = 0.95;

  /// 可选比例档位（供 UI 做快捷选择）

  /// 一键填充预览（不修改任何作答状态），供 UI 展示「将得到多少分」
  WspjAutoFillPreview previewAutoFill({double ratio = kDefaultFillRatio}) {
    var scoreQ = 0;
    var choiceQ = 0;
    var subjectiveQ = 0;
    var predicted = 0;
    var max = 0;
    for (final q in _paper.questions) {
      if (q.isScore) {
        scoreQ++;
        predicted += scoreFor(q, ratio);
        max += q.maxScore ?? 0;
      } else if (q.isSubjective) {
        subjectiveQ++;
      } else {
        choiceQ++;
      }
    }
    return WspjAutoFillPreview(
      ratio: ratio,
      scoreQuestions: scoreQ,
      choiceQuestions: choiceQ,
      subjectiveQuestions: subjectiveQ,
      predictedTotal: predicted,
      maxTotal: max,
    );
  }

  /// 一键填充：分值题按比例取高分、选择题选最高档、主观题填默认好评文本
  ///
  /// 返回实际填充的题目数。**只改内存作答状态，不触发提交**——
  /// 提交仍需用户在答题页点「提交」并过二次确认。
  int applyAutoFill({double ratio = kDefaultFillRatio}) {
    var n = 0;
    for (final q in _paper.questions) {
      if (q.isScore) {
        final v = scoreFor(q, ratio);
        if (v <= 0) continue;
        setScore(q, v);
        controllerFor(q).text = '$v';
        n++;
      } else if (q.isSubjective) {
        final text = defaultSubjectiveText(q);
        setSubjective(q, text);
        controllerFor(q).text = text;
        n++;
      } else {
        final options = _paper.optionsOf(q);
        if (options.isEmpty) continue;
        // 取最后一档（DAPX 最大即最优档，optionsOf 已按 DAPX 升序）
        selectOption(q, options.last);
        n++;
      }
    }
    return n;
  }

  /// 主观题默认好评文本，长度自动补足到 [WspjQuestion.minWords]
  static String defaultSubjectiveText(WspjQuestion q) {
    final min = q.minWords ?? 0;
    var text = _kPraiseText;
    if (text.characters.length >= min) return text;
    // 服务端若配了超长字数要求，循环补句直到达标
    while (text.characters.length < min) {
      text = '$text$_kPraiseTail';
    }
    return text;
  }

  /// 默认好评正文（通用措辞，不涉及具体课程/教师，避免答非所问）
  static const String _kPraiseText =
      '老师教学认真负责，课前准备充分，课堂讲解清晰有条理，'
      '重点难点突出，案例结合实际，课堂气氛活跃，'
      '课后作业与答疑及时，对待学生耐心负责，'
      '教学方法和手段都很恰当，收获很大，非常满意。';

  /// 字数补足用的附加句
  static const String _kPraiseTail = '感谢老师的辛勤付出。';

  // ==================== 统计 ====================

  /// 已作答题数
  int answeredCount(WspjPaper paper) => paper.questions.where(isAnswered).length;

  /// 未作答（或主观题字数不足）的题干列表
  List<String> unansweredRequired(WspjPaper paper) => paper.questions
      .where((q) => q.isSubjective ? !isSubjectiveSatisfied(q) : !isAnswered(q))
      .map((q) => q.zbsm.isEmpty ? '第 ${q.zbpx} 题' : q.zbsm)
      .toList();

  /// 第一道未作答的题目下标，全作答则 null
  /// 第一道**未全部作答**的题目的 `ZBDM`；全部完成则 null
  ///
  /// 题卡按 `ZBDM` 分组渲染，故返回 `ZBDM` 而非条目下标 —— 同题内
  /// 只要有一位教师未作答，就定位到该题卡。
  String? firstUnansweredKey(WspjPaper paper) {
    final groups = paper.groupByQuestion();
    for (final entry in groups.entries) {
      final allDone = entry.value.every((q) => q.isSubjective
          ? isSubjectiveSatisfied(q)
          : isAnswered(q));
      if (!allDone) return entry.key;
    }
    return null;
  }

  // ==================== 提交报文 ====================

  /// 构造答案数组：**每项对应一个指标**
  ///
  /// 字段名取自 `cxwjzbxq.do` / `cxpgjg.do` 的真实列（非猜测）：
  /// 标识类 `WJDM/CPR/BPR/PGNR/JXBID/JXBLXDM/ZBLXDM/ZBDM/BZ` 直接回填服务端原值，
  /// 作答类只有两个字段——客观题 `DA`、主观题 `ZGDA`。
  ///
  /// ⚠️ 服务端读取用 `WJYSJG`（嵌套 JSON 字符串）承载该数组，
  /// 见 [toRequestParam]。
  List<Map<String, String>> toAnswerRows() {
    final q = _paper.questionnaire;
    final rows = <Map<String, String>>[];
    for (final item in _paper.questions) {
      final value = _answers[item.zbdm] ?? '';
      final subjective = item.isSubjective;
      rows.add({
        'WJDM': q.wjdm,
        'CPR': q.cpr,
        'BPR': item.bpr.isNotEmpty ? item.bpr : _paper.bpr,
        'PGNR': item.pgnr.isNotEmpty ? item.pgnr : _paper.pgnr,
        'JXBID': q.jxbid,
        'JXBLXDM': item.jxblxdm,
        'ZBLXDM': item.zblxdm,
        'ZBDM': item.zbdm,
        'BZ': item.bz,
        'DA': subjective ? '' : value,
        'ZGDA': subjective ? value : '',
      });
    }
    return rows;
  }

  /// 外层 `requestParamStr` 结构
  ///
  /// ⚠️ **本方法外层包装尚未真机抓包确认**（2026-10-09）。
  /// 已实测可靠的只有答案字段本身（`DA` / `ZGDA`，来自 `cxpgjg.do` 结果表）；
  /// 外层沿用同厂商 ehall 契约：`requestParamStr` = JSON 对象，
  /// 答案数组放 `WJYSJG`（**双重编码的 JSON 字符串**，服务端字段为字符串类型）。
  ///
  /// 若真机提交被拒，只需调整本方法与 [WspjService.submitPaper]，
  /// UI 层不需改动。校验线索：提交前 `WspjService` 会打印完整报文。
  Map<String, String> toRequestParam() {
    final q = _paper.questionnaire;
    return {
      'WJDM': q.wjdm,
      'JXBID': q.jxbid,
      'CPR': q.cpr,
      'BPR': _paper.bpr,
      'PGNR': _paper.pgnr,
      'PGLY': '1',
      'SFTJ': '1',
      'WJYSJG': jsonEncode(toAnswerRows()),
    };
  }
}

/// 一键填充预览结果（供 UI 展示「会填成什么样」）
class WspjAutoFillPreview {
  /// 使用的分值比例
  final double ratio;

  /// 分值题数量
  final int scoreQuestions;

  /// 选择题数量
  final int choiceQuestions;

  /// 主观题数量
  final int subjectiveQuestions;

  /// 填充后分值题预计总分
  final int predictedTotal;

  /// 分值题满分合计
  final int maxTotal;

  const WspjAutoFillPreview({
    required this.ratio,
    required this.scoreQuestions,
    required this.choiceQuestions,
    required this.subjectiveQuestions,
    required this.predictedTotal,
    required this.maxTotal,
  });

  /// 填充题数合计
  int get total => scoreQuestions + choiceQuestions + subjectiveQuestions;

  /// 得分率（%）
  int get percent => maxTotal == 0 ? 0 : (predictedTotal * 100 / maxTotal).round();
}
