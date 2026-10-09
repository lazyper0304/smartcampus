// 第二课堂（erke.yibinu.edu.cn）数据模型。
//
// 该站与「智慧校园 / CAS」完全独立：使用自己的账号密码登录，
// 登录后返回 JWT token，后续接口通过 `Authorization: Bearer <token>` 鉴权。
// 仅能在校园内网环境访问（需连接校园网）。

/// 学生基础信息
class ErkeProfile {
  final String unitName; // 学院
  final String classNo; // 班级
  final String nickName; // 姓名
  final String username; // 学号
  final String? score; // 总评（服务端可能为 null）
  final String? avatar;

  const ErkeProfile({
    required this.unitName,
    required this.classNo,
    required this.nickName,
    required this.username,
    this.score,
    this.avatar,
  });

  const ErkeProfile.empty()
      : unitName = '',
        classNo = '',
        nickName = '',
        username = '',
        score = null,
        avatar = null;

  factory ErkeProfile.fromJson(Map<String, dynamic> j) => ErkeProfile(
        unitName: j['unitName']?.toString() ?? '',
        classNo: j['classNo']?.toString() ?? '',
        nickName: j['nickName']?.toString() ?? '',
        username: j['username']?.toString() ?? '',
        score: j['score']?.toString(),
        avatar: j['avatar']?.toString(),
      );
}

/// 分类学分汇总（如「社会实践与志愿服务：4.5」）
class ErkeReportItem {
  final String name;
  final String value;

  const ErkeReportItem({required this.name, required this.value});

  factory ErkeReportItem.fromJson(Map<String, dynamic> j) => ErkeReportItem(
        name: j['name']?.toString() ?? '',
        value: j['value']?.toString() ?? '0',
      );

  /// 从 Bingo `/erke/summary` 条目创建：`{ category, total_credit, count }`
  factory ErkeReportItem.fromBingoJson(Map<String, dynamic> j) {
    final credit = j['total_credit'];
    return ErkeReportItem(
      name: j['category']?.toString() ?? '',
      value: credit == null
          ? '0'
          : (credit is num
              ? _trimNumber(credit.toDouble())
              : credit.toString()),
    );
  }

  /// 学分去尾零（4.0 → 4，4.5 → 4.5）
  static String _trimNumber(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  double get valueDouble => double.tryParse(value) ?? 0;
}

/// 单条第二课堂活动记录
class ErkeTranscriptItem {
  final int id;
  final String itemType; // 分类：思想政治与道德修养 等
  final String itemName; // 活动名称
  final String itemTime; // 学期：2024-2025上学期
  final String score; // 该活动得分
  final String? grade;
  final String? createTime;

  const ErkeTranscriptItem({
    required this.id,
    required this.itemType,
    required this.itemName,
    required this.itemTime,
    required this.score,
    this.grade,
    this.createTime,
  });

  factory ErkeTranscriptItem.fromJson(Map<String, dynamic> j) => ErkeTranscriptItem(
        id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
        itemType: j['itemType']?.toString() ?? '',
        itemName: j['itemName']?.toString() ?? '',
        itemTime: j['itemTime']?.toString() ?? '',
        score: j['score']?.toString() ?? '0',
        grade: j['grade']?.toString(),
        createTime: j['createTime']?.toString(),
      );

  /// 从 Bingo `/erke/activities` 条目创建：
  /// `{ activity_name, category, status, start_time, end_time, location, credit }`
  ///
  /// 后端字段与第二课堂原字段语义映射：
  /// `category`→itemType（分类）、`activity_name`→itemName（活动名）、
  /// `start_time`/`end_time`→itemTime（学期/时间）、`credit`→score（学分）。
  factory ErkeTranscriptItem.fromBingoJson(Map<String, dynamic> j) {
    final credit = j['credit'];
    final status = j['status']?.toString() ?? '';
    return ErkeTranscriptItem(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      itemType: j['category']?.toString() ?? '',
      itemName: j['activity_name']?.toString() ?? '',
      itemTime: _joinTime(
        j['start_time']?.toString() ?? '',
        j['end_time']?.toString() ?? '',
      ),
      score: credit == null
          ? '0'
          : (credit is num
              ? _fmt(credit.toDouble())
              : credit.toString()),
      grade: status.isEmpty ? null : status,
      createTime: j['location']?.toString(),
    );
  }

  static String _joinTime(String start, String end) {
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    // 仅取日期部分（若含时间则截断到日）
    final s = start.length > 10 ? start.substring(0, 10) : start;
    final e = end.length > 10 ? end.substring(0, 10) : end;
    if (s == e) return s;
    return '$s ~ $e';
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }
}

/// 第二课堂成绩单（一次查询的完整结果）
class ErkeTranscript {
  final ErkeProfile profile;
  final List<ErkeReportItem> report;
  final List<ErkeTranscriptItem> items;

  const ErkeTranscript({
    required this.profile,
    required this.report,
    required this.items,
  });

  factory ErkeTranscript.fromJson(Map<String, dynamic> j) {
    final reportRaw = j['report'];
    final itemsRaw = j['items'];
    return ErkeTranscript(
      profile: ErkeProfile.fromJson(j),
      report: reportRaw is List
          ? reportRaw
              .map((e) => ErkeReportItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      items: itemsRaw is List
          ? itemsRaw
              .map((e) => ErkeTranscriptItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  /// 分类学分合计
  double get totalScore =>
      report.fold(0.0, (s, e) => s + e.valueDouble);

  /// 按分类聚合活动记录
  Map<String, List<ErkeTranscriptItem>> get groupedByType {
    final map = <String, List<ErkeTranscriptItem>>{};
    for (final it in items) {
      map.putIfAbsent(it.itemType, () => []).add(it);
    }
    return map;
  }
}
