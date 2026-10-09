/// 校园一卡通（智能卡）数据模型。
///
/// 参考实现：`E:/project/YibinApp/Flutter/lib/features/apps/ecard/data/ecard_model.dart`
/// （该工程的 dio 版Model 与此字段完全一致，故直接沿用服务端字段名）。
library;

/// 一笔交易流水
class EcardTransaction {
  const EcardTransaction({
    required this.id,
    required this.transTime,
    required this.subject,
    required this.amount,
    required this.balance,
    this.userId = 0,
    this.operator = '',
    this.workstation = '',
    this.terminal = '',
    this.walletType = 0,
    this.transType = 0,
    this.createdAt = '',
  });

  final int id;
  final int userId;

  /// 交易时间（ISO 字符串）
  final String transTime;

  /// 科目（如「校园一卡通消费」「购热水支出」）
  final String subject;

  /// 金额（消费为正、充值为正，方向由 [isRecharge] 判断）
  final double amount;

  /// 交易后余额
  final double balance;

  final String operator;
  final String workstation;
  final String terminal;

  /// 钱包类型：0=主钱包 1=补助钱包
  final int walletType;

  /// 交易类型：0=消费 1=充值
  final int transType;
  final String createdAt;

  /// 是否充值（[transType] == 1）
  bool get isRecharge => transType == 1;

  factory EcardTransaction.fromJson(Map<String, dynamic> j) =>
      EcardTransaction(
        id: _pickInt(j['id']),
        userId: _pickInt(j['user_id']),
        transTime: j['trans_time']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        amount: _pickDouble(j['amount']),
        balance: _pickDouble(j['balance']),
        operator: j['operator']?.toString() ?? '',
        workstation: j['workstation']?.toString() ?? '',
        terminal: j['terminal']?.toString() ?? '',
        walletType: _pickInt(j['wallet_type']),
        transType: _pickInt(j['trans_type']),
        createdAt: j['created_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'trans_time': transTime,
        'subject': subject,
        'amount': amount,
        'balance': balance,
        'operator': operator,
        'workstation': workstation,
        'terminal': terminal,
        'wallet_type': walletType,
        'trans_type': transType,
        'created_at': createdAt,
      };
}

/// 首页概览：余额 + 今日/本月消费 + 分类统计 + 近 7 日趋势
class EcardOverview {
  const EcardOverview({
    required this.balance,
    required this.todaySpent,
    required this.monthSpent,
    this.syncing = false,
    this.lastUpdated = '',
    this.categories = const [],
    this.dailyTrend = const [],
  });

  final double balance;
  final double todaySpent;
  final double monthSpent;

  /// 后端正在从一卡通系统同步（true 时前端继续轮询）
  final bool syncing;
  final String lastUpdated;
  final List<EcardCategoryStat> categories;
  final List<EcardDailyTrend> dailyTrend;

  factory EcardOverview.fromJson(Map<String, dynamic> j) => EcardOverview(
        balance: _pickDouble(j['balance']),
        todaySpent: _pickDouble(j['today_spent']),
        monthSpent: _pickDouble(j['month_spent']),
        syncing: j['syncing'] == true,
        lastUpdated: j['last_updated']?.toString() ?? '',
        categories: _pickList(j['categories'], EcardCategoryStat.fromJson),
        dailyTrend: _pickList(j['daily_trend'], EcardDailyTrend.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'today_spent': todaySpent,
        'month_spent': monthSpent,
        'syncing': syncing,
        'last_updated': lastUpdated,
        'categories': categories.map((e) => e.toJson()).toList(),
        'daily_trend': dailyTrend.map((e) => e.toJson()).toList(),
      };
}

/// 某科目（消费类别）的汇总
class EcardCategoryStat {
  const EcardCategoryStat({
    required this.subject,
    required this.totalAmount,
    required this.count,
  });

  final String subject;
  final double totalAmount;
  final int count;

  factory EcardCategoryStat.fromJson(Map<String, dynamic> j) =>
      EcardCategoryStat(
        subject: j['subject']?.toString() ?? '',
        totalAmount: _pickDouble(j['total_amount']),
        count: _pickInt(j['count']),
      );

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'total_amount': totalAmount,
        'count': count,
      };
}

/// 近 7 日消费趋势的一点
class EcardDailyTrend {
  const EcardDailyTrend({required this.date, required this.totalAmount});

  /// 日期（`MM-DD` 或 `YYYY-MM-DD`，后端格式）
  final String date;
  final double totalAmount;

  factory EcardDailyTrend.fromJson(Map<String, dynamic> j) => EcardDailyTrend(
        date: j['date']?.toString() ?? '',
        totalAmount: _pickDouble(j['total_amount']),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'total_amount': totalAmount,
      };
}

/// 分页查询结果
class EcardTransactionPage {
  const EcardTransactionPage({
    required this.items,
    required this.total,
    this.syncing = false,
  });

  final List<EcardTransaction> items;
  final int total;
  final bool syncing;

  factory EcardTransactionPage.fromJson(Map<String, dynamic> j) {
    final items = _pickList(j['items'], EcardTransaction.fromJson);
    return EcardTransactionPage(
      items: items,
      total: j['total'] == null ? items.length : _pickInt(j['total']),
      syncing: j['syncing'] == true,
    );
  }
}

/// 本地快照（进出场免白屏）
class EcardSnapshot {
  const EcardSnapshot({
    this.overview,
    this.transactions = const [],
    this.total = 0,
  });

  final EcardOverview? overview;
  final List<EcardTransaction> transactions;
  final int total;

  bool get isEmpty => overview == null && transactions.isEmpty;

  Map<String, dynamic> toJson() => {
        'overview': overview?.toJson(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'total': total,
      };

  factory EcardSnapshot.fromJson(Map<String, dynamic> j) => EcardSnapshot(
        overview: j['overview'] == null
            ? null
            : EcardOverview.fromJson(
                Map<String, dynamic>.from(j['overview'] as Map)),
        transactions:
            _pickList(j['transactions'], EcardTransaction.fromJson),
        total: _pickInt(j['total']),
      );
}

// ── JSON 取值辅助：后端可能下发 int/double/String 混用，统一兜底 ──

int _pickInt(Object? v) {
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

double _pickDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

/// 解析列表字段，容错单元素 Map（部分后端会把单元素数组下发成对象）
List<T> _pickList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  return raw
      .map((e) => fromJson(e is Map<String, dynamic>
          ? e
          : Map<String, dynamic>.from(e as Map)))
      .toList();
}