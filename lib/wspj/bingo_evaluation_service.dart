import 'dart:math';

import '../core/bingo/bingo_client.dart';

/// Bingo 评教服务（`/evaluation`、`/evaluation/questions`、`/evaluation/submit`）。
///
/// 替代原 jwwspj 直连：端点名与字段名都是服务端实现细节，跨校/跨版本会变，
/// Bingo 后端已封装为稳定契约（`question_code` / `question_type` /
/// `teacher_code` / `class_id` 等语义化字段），客户端不再自行猜测。
///
/// 输出沿用既有 UI 模型（[WspjQuestionnaire] / [WspjPaper] / [WspjResult] 等），
/// 评教页面无需改动。
class BingoEvaluationService {
  BingoEvaluationService._();

  static final BingoEvaluationService instance = BingoEvaluationService._();

  final BingoClient _client = BingoClient.instance;

  /// 评教任务列表
  Future<BingoEvaluationList> fetchTasks() async {
    final data = await _client.getMap('/evaluation');
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .map((e) => BingoEvalTask.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();
    return BingoEvaluationList(
      items: items,
      syncing: data['syncing'] as bool? ?? false,
    );
  }

  /// 问卷题目。
  ///
  /// [questionnaireCode] 为空时取问卷列表首条，保证「点开即用」。
  ///
  /// [teacherCode] 用于在**同一问卷含多个教师**时定位正确的任务
  /// （`/evaluation` 一条 task 即「某教师某课程」的一份评教），
  /// 为空则取该问卷的第一条任务。
  Future<BingoPaper> fetchPaper(String questionnaireCode,
      {String? teacherCode}) async {
    final list = await fetchTasks();
    if (list.items.isEmpty) {
      throw BingoException('当前没有可评教的任务');
    }
    final code = questionnaireCode.isNotEmpty
        ? questionnaireCode
        : list.items.first.questionnaireCode;
    if (code.isEmpty) {
      throw BingoException('该评教任务缺少问卷编号');
    }

    final raw = await _client.getList('/evaluation/questions',
        query: {'questionnaire_code': code});
    final questions = raw
        .map((e) => BingoEvalQuestion.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();

    // 任务 ID：问卷编号匹配 → 再按教师工号匹配 → 退回首条
    final sameCode = list.items
        .where((t) => t.questionnaireCode == code)
        .toList();
    final pool = sameCode.isEmpty ? list.items : sameCode;
    final matched = (teacherCode != null && teacherCode.isNotEmpty)
        ? pool.firstWhere(
            (t) => t.teacherCode == teacherCode,
            orElse: () => pool.first,
          )
        : pool.first;

    // 题目侧也按教师收敛：同一问卷下不同教师的分值满分可能不同，
    // 答题页一次只评一位教师，留着别的教师会串档。
    final scoped = (teacherCode != null && teacherCode.isNotEmpty)
        ? questions
            .map((q) => q.scopedToTeacher(teacherCode))
            .toList()
        : questions;

    return BingoPaper(
      questionnaireCode: code,
      questions: scoped,
      taskId: matched.id,
      questionnaireName: matched.questionnaireName,
    );
  }

  /// 提交问卷
  ///
  /// ⚠️ 提交不可逆，服务端会直接落库，故仅在用户明确点击提交时调用。
  Future<void> submitPaper({
    required int taskId,
    required String questionnaireCode,
    required List<BingoEvalQuestion> questions,
    required Map<String, int> scores,
    required Map<String, String> subjectiveAnswers,
  }) async {
    final payload = buildSubmitPayload(
      questionnaireCode: questionnaireCode,
      questions: questions,
      scores: scores,
      subjectiveAnswers: subjectiveAnswers,
    );
    await _client.postMap('/evaluation/submit', body: {
      'task_id': taskId,
      'answers': payload.answers,
      'submissions': payload.submissions,
    });
  }
}

/// 评教任务
class BingoEvalTask {
  final int id;
  final String questionnaireCode;
  final String questionnaireName;
  final String courseName;
  final String teacherCode;
  final String teacherName;
  final String evalType;
  final String semester;
  final String semesterName;
  final String totalScore;
  final String description;
  final String deadline;
  final String status;

  const BingoEvalTask({
    this.id = 0,
    this.questionnaireCode = '',
    this.questionnaireName = '',
    this.courseName = '',
    this.teacherCode = '',
    this.teacherName = '',
    this.evalType = '',
    this.semester = '',
    this.semesterName = '',
    this.totalScore = '',
    this.description = '',
    this.deadline = '',
    this.status = 'pending',
  });

  bool get isPending => status != 'submitted';

  factory BingoEvalTask.fromJson(Map<String, dynamic> j) => BingoEvalTask(
        id: (j['id'] as num?)?.toInt() ?? 0,
        questionnaireCode: j['questionnaire_code']?.toString() ?? '',
        questionnaireName: j['questionnaire_name']?.toString() ?? '',
        courseName: j['course_name']?.toString() ?? '',
        teacherCode: j['teacher_code']?.toString() ?? '',
        teacherName: j['teacher_name']?.toString() ?? '',
        evalType: j['eval_type']?.toString() ?? '',
        semester: j['semester']?.toString() ?? '',
        semesterName: j['semester_name']?.toString() ?? '',
        totalScore: j['total_score']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        deadline: j['deadline']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending',
      );
}

class BingoEvaluationList {
  final List<BingoEvalTask> items;
  final bool syncing;
  const BingoEvaluationList({this.items = const [], this.syncing = false});
}

/// 评教题目下的教师选项
class BingoEvalTeacher {
  final String teacherCode;
  final String teacherName;
  final String courseName;
  final String courseShortName;
  final String classId;
  final String courseCode;
  final double score;

  const BingoEvalTeacher({
    this.teacherCode = '',
    this.teacherName = '',
    this.courseName = '',
    this.courseShortName = '',
    this.classId = '',
    this.courseCode = '',
    this.score = 0,
  });

  factory BingoEvalTeacher.fromJson(Map<String, dynamic> j) => BingoEvalTeacher(
        teacherCode: j['teacher_code']?.toString() ?? '',
        teacherName: j['teacher_name']?.toString() ?? '',
        courseName: j['course_name']?.toString() ?? '',
        courseShortName: j['course_short_name']?.toString() ?? '',
        classId: j['class_id']?.toString() ?? '',
        courseCode: j['course_code']?.toString() ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

/// 评教题目
class BingoEvalQuestion {
  final String questionCode;
  final String questionText;
  final String questionType; // 01 单选 / 02 主观 / 03 分值
  final String categoryDisplay;
  final int sortOrder;
  final List<BingoEvalTeacher> teachers;

  const BingoEvalQuestion({
    this.questionCode = '',
    this.questionText = '',
    this.questionType = '',
    this.categoryDisplay = '',
    this.sortOrder = 0,
    this.teachers = const [],
  });

  bool get isScoreType => questionType == '03';

  bool get isSubjectiveType => questionType == '02';

  /// 单选/星级题（`question_type == '01'`）
  bool get isChoiceType => questionType == '01';

  /// 是否需要走「打分」通道（分值题 + 单选/星级题）
  ///
  /// Bingo `/evaluation/questions` 只回题目与教师维度，**不返回选项数组**，
  /// 故单选/星级题的档位由客户端按 [evalChoiceLevels] 合成、答案存[scores]，
  /// 提交时统一写进 `DA`（与服务端 `DA` 承载客观题答案的语义一致）。
  bool get needsScoreInput => isScoreType || isChoiceType;

  factory BingoEvalQuestion.fromJson(Map<String, dynamic> j) {
    final raw = j['teachers'] as List<dynamic>? ?? const [];
    return BingoEvalQuestion(
      questionCode: j['question_code']?.toString() ?? '',
      questionText: j['question_text']?.toString() ?? '',
      questionType: j['question_type']?.toString() ?? '',
      categoryDisplay: j['category_display']?.toString() ?? '',
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      teachers: raw
          .map((e) => BingoEvalTeacher.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
/// 只保留某位教师的维度（[teacherCode] 为空则原样返回）
  ///
  /// 同一问卷下不同教师的分值满分（`score`）可以不同，答题页一次只评一位
  /// 教师，混入他人维度会导致串档。
  BingoEvalQuestion scopedToTeacher(String teacherCode) {
    if (teacherCode.isEmpty) return this;
    return BingoEvalQuestion(
      questionCode: questionCode,
      questionText: questionText,
      questionType: questionType,
      categoryDisplay: categoryDisplay,
      sortOrder: sortOrder,
      teachers: teachers.where((t) => t.teacherCode == teacherCode).toList(),
    );
  }
}

/// 单选/星级题的合成档位（`DADM` 1..N，`DAPX` 同值）
List<int> evalChoiceLevels() => const [1, 2, 3, 4, 5];

/// 问卷（题目集合）
class BingoPaper {
  final String questionnaireCode;
  final String questionnaireName;
  final int taskId;
  final List<BingoEvalQuestion> questions;

  const BingoPaper({
    this.questionnaireCode = '',
    this.questionnaireName = '',
    this.taskId = 0,
    this.questions = const [],
  });
}

/// 答案 key：`题目编号_教师编号_教学班ID`
String evalAnswerKey(String questionCode, String teacherCode, String classId) =>
    '${questionCode}_${teacherCode}_$classId';

/// 分值题可选分值按钮
List<int> evalScoreButtons(double maxScore) {
  final max = maxScore.ceil().clamp(0, 100);
  if (max <= 0) return const [];
  return List.generate(max, (i) => i + 1);
}

/// 是否所有需要打分的题都已作答（分值题 + 单选/星级题）
///
/// 单选/星级题（`question_type == '01'`）在 Bingo 契约里没有独立的选项数组，
/// 档位由客户端按 [evalChoiceLevels] 合成，因此它的作答也走 [scores] 这条通道
/// （值为档位序号1..N，回传 `DA`），故一并纳入完成度判定。
bool evalAllScoreQuestionsDone(
    List<BingoEvalQuestion> questions, Map<String, int> scores) {
  for (final q in questions) {
    if (!q.needsScoreInput) continue;
    for (final t in q.teachers) {
      final key = evalAnswerKey(q.questionCode, t.teacherCode, t.classId);
      if (!scores.containsKey(key)) return false;
    }
  }
  return questions.isNotEmpty;
}

const List<String> _autoFillTexts = [
  '老师教学认真负责，课堂氛围活跃，能够很好地调动学生的学习积极性，讲解清晰易懂。',
  '老师备课充分，知识点讲解透彻，教学方法灵活多样，注重理论与实践相结合。',
  '老师对学生认真负责，耐心解答疑问，教学内容丰富，课堂互动良好。',
  '老师授课思路清晰，重点突出，能够很好地把握教学节奏，教学效果显著。',
  '老师教学态度严谨，专业知识扎实，能够激发学生的学习兴趣，教学质量高。',
];

/// 自动填充实用（仅填未作答项）
void evalAutoFill({
  required List<BingoEvalQuestion> questions,
  required Map<String, int> scores,
  required Map<String, String> subjectiveAnswers,
}) {
  final rnd = Random();
  for (final q in questions) {
    for (final t in q.teachers) {
      final key = evalAnswerKey(q.questionCode, t.teacherCode, t.classId);
      if (q.isScoreType) {
        if (scores.containsKey(key)) continue;
        final max = t.score.ceil();
        if (max <= 0) continue;
        scores[key] = max <= 3 ? max : (rnd.nextBool() ? max : max - 1);
      } else if (q.isSubjectiveType) {
        if (subjectiveAnswers.containsKey(key)) continue;
        subjectiveAnswers[key] = _autoFillTexts[rnd.nextInt(_autoFillTexts.length)];
      }
    }
  }
}

/// 构造提交报文
///
/// [answers] 每（题目 × 教师）一条；[submissions] 每教师一条汇总。
/// 字段名沿用教务 jwwspj 的报文约定（`WJDM`/`ZBDM`/`DA`/`ZGDA` 等），
/// Bingo 后端负责转发，故客户端必须原样使用。
({List<Map<String, dynamic>> answers, List<Map<String, dynamic>> submissions})
    buildSubmitPayload({
  required String questionnaireCode,
  required List<BingoEvalQuestion> questions,
  required Map<String, int> scores,
  required Map<String, String> subjectiveAnswers,
}) {
  final answers = <Map<String, dynamic>>[];
  final teacherScores = <String, int>{};

  for (final q in questions) {
    for (final t in q.teachers) {
      final key = evalAnswerKey(q.questionCode, t.teacherCode, t.classId);
      final teacherKey = '${t.teacherCode}_${t.classId}';
      final answer = <String, dynamic>{
        'WJDM': questionnaireCode,
        'CPR': '',
        'BPR': t.teacherCode,
        'PGNR': t.courseShortName,
        'ZBDM': q.questionCode,
        'ZBLXDM': q.questionType,
        'JXBID': t.classId,
        'DA': q.needsScoreInput ? '${scores[key] ?? ''}' : '',
        'ZGDA': q.isSubjectiveType ? (subjectiveAnswers[key] ?? '') : '',
        'FZ': null,
        'BY2': 1,
      };
      // 主观题须带最少字数，否则服务端判为无效
      if (q.isSubjectiveType) {
        answer['BZ'] = '20';
      }
      answers.add(answer);

      if (q.isScoreType && scores.containsKey(key)) {
        teacherScores[teacherKey] =
            (teacherScores[teacherKey] ?? 0) + scores[key]!;
      }
    }
  }

  final seen = <String>{};
  final submissions = <Map<String, dynamic>>[];
  for (final q in questions) {
    for (final t in q.teachers) {
      final teacherKey = '${t.teacherCode}_${t.classId}';
      if (seen.contains(teacherKey)) continue;
      seen.add(teacherKey);
      submissions.add({
        'WJDM': questionnaireCode,
        'CPR': '',
        'BPR': t.teacherCode,
        'PGNR': t.courseShortName,
        'JXBID': t.classId,
        'SFPG': '1',
        'ZF': teacherScores[teacherKey] ?? 0,
      });
    }
  }

  return (answers: answers, submissions: submissions);
}