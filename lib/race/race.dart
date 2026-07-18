/// 学科竞赛信息
class RaceCompetition {
  /// 竞赛名称
  final String name;

  /// 指导教师
  final String teacherName;

  /// 所属学院
  final String depName;

  /// 学院代码
  final String depCode;

  /// 记录 ID
  final String id;

  /// 行号
  final int rowId;

  RaceCompetition({
    required this.name,
    required this.teacherName,
    required this.depName,
    required this.depCode,
    required this.id,
    required this.rowId,
  });

  factory RaceCompetition.fromJson(Map<String, dynamic> json) {
    return RaceCompetition(
      name: json['name']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? '',
      depName: json['dep_name']?.toString() ?? '',
      depCode: json['dep_code']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      rowId: int.tryParse(json['row_id']?.toString() ?? '0') ?? 0,
    );
  }
}

/// 分页结果
class RacePageResult {
  final List<RaceCompetition> list;
  final int totalCount;
  final int totalPage;
  final int currPage;
  final int pageSize;

  RacePageResult({
    required this.list,
    required this.totalCount,
    required this.totalPage,
    required this.currPage,
    required this.pageSize,
  });

  factory RacePageResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final rows = result['list'] as List? ?? [];
    return RacePageResult(
      list: rows
          .map((r) => RaceCompetition.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalCount: (result['totalCount'] as num?)?.toInt() ?? 0,
      totalPage: (result['totalPage'] as num?)?.toInt() ?? 0,
      currPage: (result['currPage'] as num?)?.toInt() ?? 1,
      pageSize: (result['pageSize'] as num?)?.toInt() ?? 15,
    );
  }
}
