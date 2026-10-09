import 'ecard_model.dart';

/// 交易聚合规则（参考实现：
/// `E:/project/YibinApp/Flutter/lib/features/apps/ecard/domain/ecard_transaction_aggregate.dart`，
/// 纯逻辑，可原样移植）。
///
/// 业务背景：校园卡在热水机上按次扣款，同一终端短时间内会连续产生多笔
/// 「购热水支出」，列表里逐条展示既冗长又无意义，故按
/// **同终端 + 5 分钟窗口**合并为一组，金额累加。

/// 命中合并的科目名
const String kEcardHotWaterSubject = '购热水支出';

/// 合并时间窗口
const Duration kEcardHotWaterMergeWindow = Duration(minutes: 5);

/// 一组交易（单条或合并）
class EcardTransactionGroup {
  const EcardTransactionGroup({required this.items, required this.totalAmount});

  /// 组内交易（单条时长度为 1；合并时按时间升序）
  final List<EcardTransaction> items;

  /// 合计金额
  final double totalAmount;

  /// 组内首条（时间最新）
  EcardTransaction get head => items.last;

  /// 是否为多笔合并
  bool get isMerged => items.length > 1;

  /// 卡片行 key：单条 `t-{id}`，合并 `m-{id-id-id}`
  String get key => isMerged
      ? 'm-${items.map((e) => e.id).join('-')}'
      : 't-${head.id}';

  /// 列表行显示的金额文案：充值不显示数字，只显示「充值」
  String displayAmount() => head.isRecharge ? '充值' : totalAmount.toStringAsFixed(2);
}

/// 按「购热水 5 分钟窗口」规则聚合交易。
///
/// [raw] 应为**时间降序**的列表（后端返回顺序）。输出同样保持时间降序，
/// 且合并组插入到其首条（最新一条）的位置。
List<EcardTransactionGroup> groupEcardTransactions(List<EcardTransaction> raw) {
  if (raw.isEmpty) return const [];

  // ① 筛出购热水交易，按终端分桶，桶内按时间**升序**（聚合用）
  final hotWaterBuckets = <String, List<EcardTransaction>>{};
  for (final t in raw) {
    if (t.subject.trim() != kEcardHotWaterSubject) continue;
    final key = t.terminal.isEmpty ? t.operator : t.terminal;
    hotWaterBuckets.putIfAbsent(key, () => []).add(t);
  }

  // ② 滑动窗口聚簇：与前一簇首条相差 ≤ 5 分钟则并入，否则开新簇
  final mergedGroupByHeadId = <int, EcardTransactionGroup>{};
  final mergedMemberIds = <int>{};
  for (final bucket in hotWaterBuckets.values) {
    if (bucket.isEmpty) continue;
    bucket.sort((a, b) => a.transTime.compareTo(b.transTime));

    var cluster = <EcardTransaction>[bucket.first];
    void closeCluster() {
      if (cluster.isEmpty) return;
      if (cluster.length == 1) {
        // 单条不成组，交给末尾「原始顺序遍历」按单条输出
        cluster = <EcardTransaction>[];
        return;
      }
      final sortedDesc = [...cluster]..sort((a, b) => b.transTime.compareTo(a.transTime));
      final sum = sortedDesc.fold<double>(0, (acc, e) => acc + e.amount);
      final head = sortedDesc.first;
      mergedGroupByHeadId[head.id] =
          EcardTransactionGroup(items: sortedDesc, totalAmount: sum);
      for (final e in sortedDesc) {
        mergedMemberIds.add(e.id);
      }
      cluster = <EcardTransaction>[];
    }

    for (var i = 1; i < bucket.length; i++) {
      final cur = bucket[i];
      final prev = cluster.first;
      final a = DateTime.tryParse(prev.transTime);
      final b = DateTime.tryParse(cur.transTime);
      final within = (a == null || b == null)
          ? false
          : b.difference(a).abs() <= kEcardHotWaterMergeWindow;
      if (within) {
        cluster.add(cur);
      } else {
        closeCluster();
        cluster = <EcardTransaction>[cur];
      }
    }
    closeCluster();
  }

  // ③ 遍历原始顺序（保持时间降序）：命中合并组则整组输出，
  // 命中已合并成员则跳过，否则单条成组
  final out = <EcardTransactionGroup>[];
  for (final t in raw) {
    if (mergedMemberIds.contains(t.id)) continue;
    final g = mergedGroupByHeadId[t.id];
    if (g != null) {
      out.add(g);
      continue;
    }
    out.add(EcardTransactionGroup(items: [t], totalAmount: t.amount));
  }
  return out;
}