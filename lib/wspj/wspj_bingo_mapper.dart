/// Bingo 评教模型 ⇄ UI 评教模型的转换层。
///
/// ## 为什么需要这一层
/// 两边数据形状不同：
/// - **Bingo `/evaluation/questions`**：二维。每道题（`question_code`）下挂
///   `teachers[]`，分值题的满分 `score` 是**按教师**下发的 → 同一题在不同
///   教师下的满分可以不同。
/// - **UI [WspjPaper]**：一维。[WspjPaper.rows] 是扁平行列表，同一 `ZBDM` 的
///   多行归并为一道题（`optionsOf` 取选项行），题目的 `FZ` / `BPR` / `JXBID`
///   是该题单一教师维度的值。
///
/// 因此转换规则是：**把 (题目 × 教师) 展开成独立题目行**，行内 `FZ` 取该教师
/// 的满分；单选题额外按 [evalChoiceLevels] 合成档位行（同一 `ZBDM`，靠 `DASM`
/// 区分）。`ZBDM` 因教师维度参与而必须唯一，故拼成 `题目_教师_教学班`，
/// 原始 `question_code` 另存到 [WspjQuestion.wid] 供提交时回填。
library;

import 'bingo_evaluation_service.dart';
import 'wspj.dart';
import 'wspj_answer_sheet.dart';

/// 一份问卷对应的**唯一题目行**（UI 侧标识）
String composeRowKey(String questionCode, String teacherCode, String classId) =>
    '${questionCode}_${teacherCode}_$classId';

/// 解析 [composeRowKey] 生成的 `ZBDM`
List<String> parseRowKey(String rowKey) {
  final parts = rowKey.split('_');
  if (parts.length < 3) return [rowKey, '', ''];
  final classId = parts.removeLast();
  final teacherCode = parts.removeLast();
  return [parts.join('_'), teacherCode, classId];
}

/// Bingo 评教任务 → UI 问卷条目
WspjQuestionnaire questionnaireFromBingoTask(BingoEvalTask t) =>
    WspjQuestionnaire(
      wjmc: t.questionnaireName.isEmpty ? '学生评教' : t.questionnaireName,
      wjdm: t.questionnaireCode,
      zfz: t.totalScore,
      cpr: '',
      pglxdm: t.evalType,
      pglxDisplay: t.evalType,
      // Bingo `status`：submitted=已提交，其余（pending 等）视为未评
      sfpg: t.status == 'submitted' ? '1' : '0',
      pglbdm: '',
      pglbDisplay: '',
      sffb: '1',
      wjsm: t.description,
      xnxqdm: t.semester,
      xnxqDisplay: t.semesterName,
      // ⚠️ Bingo 一条 task 即「某教师某课程」的一份评教，任务维度天然按教师切分。
      // 这里把教师工号放进 `jxbid`，使 [WspjQuestionnaire.cacheKey]
      // （`WJDM|JXBID`）在多教师同问卷时仍然唯一。
      jxbid: t.teacherCode,
      wcd: t.status == 'submitted' ? '100' : '0',
      bpr: t.teacherCode,
      bprxm: t.teacherName,
      kcm: t.courseName,
    );

/// Bingo 问卷（题目 × 教师） → UI 问卷题目行
WspjPaper paperFromBingoPaper(BingoPaper paper) {
  final rows = <WspjQuestion>[];
  for (final q in paper.questions) {
    if (q.questionCode.isEmpty) continue;
    final teachers = q.teachers.isEmpty
        ? const <BingoEvalTeacher>[]
        : q.teachers;
    if (teachers.isEmpty) {
      // 无教师维度（理论不会发生）：仍产出一行，避免题目凭空消失
      rows.add(_rowOf(
        question: q,
        teacher: null,
        rowKey: q.questionCode,
      ));
      continue;
    }
    for (final t in teachers) {
      final rowKey = composeRowKey(q.questionCode, t.teacherCode, t.classId);
      rows.add(_rowOf(question: q, teacher: t, rowKey: rowKey));
      if (!q.isChoiceType) continue;
      // 单选/星级题：Bingo 不返回选项数组，客户端合成档位行（同一 ZBDM）
      final base = rows.last;
      for (final lv in evalChoiceLevels()) {
        rows.add(WspjQuestion(
          zbdm: rowKey,
          zbsm: base.zbsm,
          zblxdm: q.questionType,
          zblxDisplay: base.zblxDisplay,
          zbflDm: base.zbflDm,
          zbflDisplay: base.zbflDisplay,
          fz: base.fz,
          bz: base.bz,
          zbpx: base.zbpx,
          jxbid: base.jxbid,
          bpr: base.bpr,
          bprxm: base.bprxm,
          kcm: base.kcm,
          pgnr: base.pgnr,
          jxblxdm: base.jxblxdm,
          wjdm: base.wjdm,
          wid: base.wid,
          dasm: _stars(lv),
          dapx: '$lv',
          dadm: '$lv',
        ));
      }
    }
  }

  final questionnaire = questionnaireFromBingoTask(
    BingoEvalTask(
      questionnaireCode: paper.questionnaireCode,
      questionnaireName: paper.questionnaireName,
    ),
  );
  return WspjPaper(
    questionnaire: questionnaire,
    rows: rows,
    taskId: paper.taskId,
    source: paper,
  );
}

/// 单行构造（题目 × 教师 → 一行）
WspjQuestion _rowOf({
  required BingoEvalQuestion question,
  required BingoEvalTeacher? teacher,
  required String rowKey,
}) {
  final t = teacher;
  return WspjQuestion(
    zbdm: rowKey,
    zbsm: question.questionText,
    zblxdm: question.questionType,
    zblxDisplay: _typeLabel(question.questionType),
    zbflDisplay: question.categoryDisplay,
    // 分值题满分按教师下发（JSON number 10.0 → "10"）
    fz: t == null ? '' : _fmtScore(t.score),
    // 主观题最少字数（Bingo 未下发，沿用 jwwspj 实测值 20）
    bz: question.isSubjectiveType ? '20' : '',
    zbpx: '${question.sortOrder}',
    jxbid: t?.classId ?? '',
    bpr: t?.teacherCode ?? '',
    bprxm: t?.teacherName ?? '',
    kcm: t?.courseName ?? '',
    pgnr: t?.courseShortName ?? '',
    wjdm: '',
    // 原始 `question_code`：提交时按此回填 `ZBDM`
    wid: question.questionCode,
  );
}

/// 档位文案：★ 星级
String _stars(int level) {
  const max = 5;
  final n = level.clamp(0, max);
  return '${'★' * n}${'☆' * (max - n)}';
}

String _typeLabel(String type) {
  switch (type) {
    case '01':
      return '单选题';
    case '02':
      return '主观题';
    case '03':
      return '分值题';
    default:
      return '题目';
  }
}

String _fmtScore(double v) {
  if (v <= 0) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// UI 答卷 → Bingo 提交入参
///
/// [sheet] 按 `ZBDM` 存答案，故这里把 `ZBDM` 拆回 (题目, 教师, 教学班)，
/// 组装成 [evalAnswerKey] 索引的两张表交给 [buildSubmitPayload]。
///
/// [paper.source] 是原始 Bingo 问卷（含 `task_id` 与完整教师维度），
/// 提交报文严格按它生成，避免客户端二次拼装导致字段缺失。
({Map<String, int> scores, Map<String, String> subjectiveAnswers})
    collectBingoAnswers(WspjPaper paper, WspjAnswerSheet sheet) {
  final scores = <String, int>{};
  final subjective = <String, String>{};
  for (final q in paper.questions) {
    final parsed = parseRowKey(q.zbdm);
    final questionCode = parsed[0];
    final teacherCode = parsed[1];
    final classId = parsed[2];
    final key = evalAnswerKey(questionCode, teacherCode, classId);
    final raw = sheet.answerOf(q)?.trim() ?? '';
    if (raw.isEmpty) continue;
    if (q.isSubjective) {
      subjective[key] = raw;
    } else {
      final n = int.tryParse(raw);
      if (n != null) scores[key] = n;
    }
  }
  return (scores: scores, subjectiveAnswers: subjective);
}