
import 'package:flutter/foundation.dart';

import 'wspj.dart';
import 'wspj_answer_sheet.dart';
import 'wspj_service.dart';

/// 批量评教的进度回调
///
/// [done] 已处理份数（成功+失败），[total] 总份数，[current] 当前问卷标题。
typedef WspjAutoProgress = void Function(int done, int total, String current);

/// 批量评教结果
class WspjAutoResult {
  /// 成功提交份数
  final int succeeded;

  /// 失败明细（问卷标题 + 原因）
  final List<String> failures;

  const WspjAutoResult({required this.succeeded, required this.failures});

  int get total => succeeded + failures.length;

  bool get allSucceeded => failures.isEmpty;

  /// 结果摘要文案
  String get summary {
    if (failures.isEmpty) return '已全部评教完成，共 $succeeded 份';
    final buf = StringBuffer('成功 $succeeded 份，失败 ${failures.length} 份');
    for (final f in failures) {
      buf.write('\n· $f');
    }
    return buf.toString();
  }
}

/// 批量一键评教（遍历全部待评问卷 → 自动填答 → 逐份提交）
///
/// 参考工程 `E:/project/YibinApp/Flutter` 只实现了「单份问卷的一键填答」
/// （答题页底部绿按钮），批量编排层需自行实现，本类即该层。
///
/// ## 关键约束
/// - **串行**：并发提交会撞服务端限流，且评教提交**不可逆**，一旦某份串档
///   无法回滚，故逐份处理并逐份汇报进度。
/// - **比例不取满分**：服务端对分数有上限校验，一键填写沿用答题页的
///   [kFillRatio]（0.95），落在「优秀 = 标准分 × 90~100%」区间内。
/// - **失败不中断**：单份失败（如题目为空、教师串档）记录后继续下一份，
///   最终汇总成功/失败清单交给用户判断。
class WspjAutoEvaluator {
  /// 服务层，缺省时在 [runAll] 内新建（`WspjService()` 无参构造已可用）
  WspjAutoEvaluator({this._service});

  final WspjService? _service;

  /// 分值题一键填写的比例（与答题页一致，不取满分）
  static const double kFillRatio = 0.95;

  /// 对 [targets] 中所有待评问卷执行「自动填答 + 提交」
  ///
  /// [targets] 建议传**待评**问卷（`isDone == false`），已评的会被自动跳过。
  /// [isCancelled] 每份开始前检查一次，便于用户中途取消。
  Future<WspjAutoResult> runAll(
    List<WspjQuestionnaire> targets, {
    WspjAutoProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final pending = targets.where((q) => !q.isDone).toList();
    if (pending.isEmpty) {
      return const WspjAutoResult(succeeded: 0, failures: []);
    }
    final service = _service ?? WspjService();

    var done = 0;
    final failures = <String>[];
    for (final q in pending) {
      if (isCancelled?.call() ?? false) {
        // 用户取消：把未处理的部分如实计入失败，避免用户误以为全部完成
        for (final rest in pending.skip(done)) {
          failures.add('${rest.displayTitle}（已取消）');
        }
        break;
      }
      onProgress?.call(done, pending.length, q.displayTitle);
      final why = await _runOne(service, q);
      if (why != null) {
        failures.add('${q.displayTitle}（$why）');
      }
      done++;
    }
    onProgress?.call(pending.length, pending.length, '');
    return WspjAutoResult(
        succeeded: pending.length - failures.length, failures: failures);
  }

  /// 处理单份问卷。返回 `null` 表示成功，否则返回失败原因。
  Future<String?> _runOne(WspjService service, WspjQuestionnaire q) async {
    try {
      final paper = await service.fetchPaper(questionnaire: q);
      final sheet = WspjAnswerSheet(paper);
      final n = sheet.applyAutoFill(ratio: kFillRatio);
      if (n == 0) {
        return '未返回题目';
      }
      // 一键填写后必答题应全满；仍缺则不提交（避免提交空卷占用评教记录）
      final missing = sheet.unansweredRequired(paper);
      if (missing.isNotEmpty) {
        return '有 ${missing.length} 道必答题未能自动填写';
      }
      await service.submitPaper(paper: paper, sheet: sheet);
      return null;
    } catch (e) {
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceAll('BingoException: ', '')
          .trim();
      debugPrint('[WspjAuto] 提交失败 ${q.displayTitle}: $msg');
      return msg.isEmpty ? '提交失败' : msg;
    }
  }
}
