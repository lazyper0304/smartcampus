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

/// 学科竞赛详情
class RaceDetail {
  final String id;
  final String name;

  /// 教师姓名
  final String teacherName;

  /// 教师工号
  final String teacherNo;

  /// 联系电话
  final String mobile;

  /// 学院名称
  final String depName;

  /// 学院代码
  final String depCode;

  /// 主办单位
  final String hostDep;

  /// 竞赛类型（A/B/C 类等）
  final String typeName;

  /// 级别（全国性/省级等）
  final String levelHName;

  /// 学年（如 2024-2025）
  final String yearterm;

  /// 比赛年份
  final String year;

  /// 报名开始时间
  final String? beginTime;

  /// 报名结束时间
  final String? endTime;

  /// 创建时间
  final String creTime;

  /// 更新时间
  final String updateTime;

  /// 详细描述/参赛须知
  final String content;

  /// 所需经费
  final double outlay;

  /// 是否可报名
  final String havesub;

  /// 发布状态
  final String ispublishName;

  /// 子项（多组别时）
  final List<RaceSubItem> subs;

  RaceDetail({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.teacherNo,
    required this.mobile,
    required this.depName,
    required this.depCode,
    required this.hostDep,
    required this.typeName,
    required this.levelHName,
    required this.yearterm,
    required this.year,
    required this.beginTime,
    required this.endTime,
    required this.creTime,
    required this.updateTime,
    required this.content,
    required this.outlay,
    required this.havesub,
    required this.ispublishName,
    required this.subs,
  });

  factory RaceDetail.fromJson(Map<String, dynamic> json) {
    // API 响应结构: { code, msg, result: { id, name, ... } }
    // 先剥掉外层 result
    final data = (json['result'] as Map<String, dynamic>?) ?? json;

    final subs = (data['subs'] as List? ?? [])
        .map((e) => RaceSubItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return RaceDetail(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      teacherName: data['teacher_name']?.toString() ?? '',
      teacherNo: data['teacher_no']?.toString() ?? '',
      mobile: data['mobile']?.toString() ?? '',
      depName: data['dep_name']?.toString() ?? '',
      depCode: data['dep_code']?.toString() ?? '',
      hostDep: data['host_dep']?.toString() ?? '',
      typeName: data['type_name']?.toString() ?? '',
      levelHName: data['level_h_name']?.toString() ?? '',
      yearterm: data['yearterm']?.toString() ?? '',
      year: data['year']?.toString() ?? '',
      beginTime: data['begin_time']?.toString(),
      endTime: data['end_time']?.toString(),
      creTime: data['cre_time']?.toString() ?? '',
      updateTime: data['update_time']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      outlay: (data['outlay'] as num?)?.toDouble() ?? 0.0,
      havesub: data['havesub']?.toString() ?? '否',
      ispublishName: data['ispublish_name']?.toString() ?? '',
      subs: subs,
    );
  }
}

/// 竞赛子项（如分组别）
class RaceSubItem {
  final String id;
  final String name;
  final String raceId;
  final String isteam;
  final String isteamName;
  final double entryfee;
  final String? isPay;

  RaceSubItem({
    required this.id,
    required this.name,
    required this.raceId,
    required this.isteam,
    required this.isteamName,
    required this.entryfee,
    required this.isPay,
  });

  factory RaceSubItem.fromJson(Map<String, dynamic> json) {
    return RaceSubItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      raceId: json['race_id']?.toString() ?? '',
      isteam: json['isteam']?.toString() ?? '0',
      isteamName: json['isteam_name']?.toString() ?? '',
      entryfee: (json['entryfee'] as num?)?.toDouble() ?? 0.0,
      isPay: json['is_pay']?.toString(),
    );
  }
}
