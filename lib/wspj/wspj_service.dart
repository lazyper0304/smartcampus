import 'package:flutter/foundation.dart';

import '../core/bingo/bingo_client.dart';
import '../core/bingo/bingo_config.dart';
import 'bingo_evaluation_service.dart';
import 'wspj.dart';
import 'wspj_answer_sheet.dart';
import 'wspj_bingo_mapper.dart';

/// 网上评教服务（数据源：Bingo 后端 `/evaluation/*`）。
///
/// ## 为什么不再直连 ehall jwwspj
/// - `.do` 端点名与字段名都是服务端实现细节，跨校/跨版本都会变，直连不可维护；
/// - 提交端点 `pj.do` 此前始终无法确认（网关对不存在的 `.do` 返回 **403 而非
///   404**，672 组合扫描 0 命中），评教提交长期处于不可用状态；
/// - Bingo 后端已封装为稳定语义化契约（`questionnaire_code` / `question_type` /
///   `teacher_code` / `class_id`），端点与字段由服务端维护。
///
/// ## 与 UI 模型的关系
/// Bingo 返回「题目 × 教师」二维结构，UI 用 [WspjPaper] 的一维行列表，
/// 转换规则见 `wspj_bingo_mapper.dart`。**页面代码零改动**。
///
/// ## 方法签名兼容性
/// 保留了 jwwspj 时期的全部签名与参数（含已无意义的 `cpr` / `xnxqdm` /
/// `retryCount`），页面无需为切后端而改动；Bingo 侧按当前学期处理，
/// 学期筛选参数被忽略。
class WspjService {
  final Object? client;

  ///保留字段仅为签名兼容，页面不再传值。
  final String baseUrl;

  WspjService({
    this.client,
    this.baseUrl = BingoConfig.baseUrl,
  });

  static BingoEvaluationService get _bingo =>
      BingoEvaluationService.instance;

  // ==================== 评教任务列表 ====================

  /// 评教问卷列表
  ///
  /// [cpr]（学号）与 [xnxqdm]（学年学期）在 Bingo 侧由后端按当前学期处理，
  /// 传入值被忽略；[sffb] 同理。
  Future<List<WspjQuestionnaire>> fetchQuestionnaires({
    String? cpr,
    String? xnxqdm,
    String sffb = '1',
    int retryCount = 0,
  }) async {
    final list = await _bingo.fetchTasks();
    return list.items.map(questionnaireFromBingoTask).toList();
  }

  /// 评教系统参数
  ///
  /// Bingo 未下发评教时间窗口，这里按任务数据合成页面需要的三个参数：
  /// - `PJXNXQ`：当前学期（取任务里的学期代码）
  /// - `SFSY`：恒为 `1`（Bingo 有任务即代表评教已开放）
  /// - `PJKSSJ` / `PJJSSJ`：取任务 `deadline` 的最早/最晚值
  Future<List<WspjConfigItem>> fetchConfig({int retryCount = 0}) async {
    final list = await _bingo.fetchTasks();
    final deadlines = <DateTime>[];
    var semester = '';
    for (final t in list.items) {
      if (semester.isEmpty && t.semester.isNotEmpty) semester = t.semester;
      final d = DateTime.tryParse(t.deadline);
      if (d != null) deadlines.add(d);
    }
    deadlines.sort();
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:00';

    return [
      _cfg('PJXNXQ', '评教学期', semester),
      _cfg('SFSY', '是否使用', '1'),
      if (deadlines.isNotEmpty)
        _cfg('PJJSSJ', '评教结束时间', fmt(deadlines.first)),
    ];
  }

  static WspjConfigItem _cfg(String dm, String name, String value) =>
      WspjConfigItem(
        csdm: 'PJGLPJSJ',
        zcsdm: dm,
        cszb: name,
        csza: value,
        cssm: name,
        wid: '',
      );

  /// 学年学期列表
  ///
  /// Bingo 由后端按当前学期处理，页面不需要手动选择；这里从任务数据里
  /// 聚合出出现过的学期，供页面维持既有UI 形态（单学期时选择器自动隐藏）。
  Future<List<WspjSemester>> fetchSemesters({
    String? dm,
    int retryCount = 0,
  }) async {
    final list = await _bingo.fetchTasks();
    final out = <WspjSemester>[];
    final seen = <String>{};
    for (final t in list.items) {
      if (t.semester.isEmpty || !seen.add(t.semester)) continue;
      final parts = t.semester.split('-');
      out.add(WspjSemester(
        dm: t.semester,
        xndm: parts.length >= 2 ? '${parts[0]}-${parts[1]}' : t.semester,
        xqdm: parts.length >= 3 ? parts[2] : '',
        mc: t.semesterName.isEmpty ? t.semester : t.semesterName,
        sfsy: 1,
        wid: '',
      ));
    }
    return out;
  }

  /// 评教模块列表
  ///
  /// Bingo 已把学生评教合并为 `/evaluation` 单一入口，无模块选择概念，
  /// 返回空列表（页面据此不显示模块选择 UI）。
  Future<List<WspjModule>> fetchModules({int retryCount = 0}) async =>
      const [];

  // ==================== 问卷题目 ====================

  /// 拉取问卷题目（Bingo `/evaluation/questions`）
  ///
  /// [questionnaire.jxbid] 携带被评教师工号（见 [questionnaireFromBingoTask]），
  /// 用于在多教师同问卷场景下定位正确的 `task_id`。
  Future<WspjPaper> fetchPaper({
    required WspjQuestionnaire questionnaire,
    int retryCount = 0,
  }) async {
    final paper = await _bingo.fetchPaper(
      questionnaire.wjdm,
      teacherCode: questionnaire.jxbid,
    );
    // 回填真实问卷条目（列表接口已带课程/教师名，比这里重建的更完整）
    final rows = paperFromBingoPaper(paper);
    return WspjPaper(
      questionnaire: questionnaire,
      rows: rows.rows,
      taskId: rows.taskId,
      source: rows.source,
    );
  }

  /// 补齐每份问卷的教师/课程摘要
  ///
  /// Bingo 的 `/evaluation` **已直接返回** `teacher_name` / `course_name`，
  /// 无需二次请求（这正是直连 jwwspj 时最麻烦的一步——`cxxspjwjlb.do` 不含
  /// 教师名，必须串行预取 `cxwjzbxq.do`）。这里直接把列表条目已有的
  /// 信息组装成摘要返回。
  Future<Map<String, WspjTeacherBrief>> fetchTeacherBriefs(
    List<WspjQuestionnaire> questionnaires,
  ) async {
    final out = <String, WspjTeacherBrief>{};
    for (final q in questionnaires) {
      if (out.containsKey(q.cacheKey)) continue;
      out[q.cacheKey] = WspjTeacherBrief(
        bpr: q.bpr.isNotEmpty ? q.bpr : q.jxbid,
        bprxm: q.bprxm,
        kcm: q.kcm,
      );
    }
    return out;
  }

  // ==================== 提交 ====================

  /// 提交问卷（Bingo `/evaluation/submit`）
  ///
  /// ⚠️ 提交不可逆，服务端直接落库，仅在用户点「提交」并过二次确认后调用。
  ///
  /// 报文由 [WspjPaper.source]（原始 Bingo 二维问卷）生成：UI 侧 [WspjPaper.rows]
  /// 已按 `ZBDM` 归并，教师维度折叠进了行键，反解不出完整的 (题目 × 教师)
  /// 集合，必须回到原始结构逐项展开。
  Future<void> submitPaper({
    required WspjPaper paper,
    required WspjAnswerSheet sheet,
    int retryCount = 0,
  }) async {
    final source = paper.source;
    if (source is! BingoPaper) {
      throw BingoException('评教问卷缺少原始数据，无法提交（请下拉刷新后重试）');
    }
    final collected = collectBingoAnswers(paper, sheet);
    await _bingo.submitPaper(
      taskId: paper.taskId > 0 ? paper.taskId : source.taskId,
      questionnaireCode: source.questionnaireCode,
      questions: source.questions,
      scores: collected.scores,
      subjectiveAnswers: collected.subjectiveAnswers,
    );
    debugPrint('Wspj.submitPaper ok: task=${paper.taskId} '
        'wj=${source.questionnaireCode} '
        'score=${collected.scores.length} '
        'text=${collected.subjectiveAnswers.length}');
  }

  // ==================== 历史结果 ====================

  /// 已评答案回看
  ///
  /// Bingo 后端未提供历史答案接口，一律返回空 → 页面视为未评，不做回填
  /// （已评问卷仍可重新进入作答，提交走同一链路）。
  Future<List<WspjResult>> fetchResults({
    required String wjdm,
    required String jxbid,
    int retryCount = 0,
  }) async =>
      const [];
}