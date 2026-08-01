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

// ==================== 我的竞赛（listMyRacePage / raceTeam/queryById） ====================

/// 我的竞赛记录（`stuRace/listMyRacePage` 列表项）
class MyRaceItem {
  /// 报名子项 ID
  final String subId;

  /// 竞赛（主项）ID
  final String raceId;

  /// 团队 ID（与 [id] 相同）
  final String teamId;

  /// 分类 ID
  final String sortId;

  /// 学年（如 2025-2026）
  final String yearterm;

  /// 最新审核意见
  final String opinion;

  /// 是否团队（1=团队）
  final int isteam;

  /// 审核状态名（如 审核通过 / 驳回）
  final String stateName;

  /// 审核状态码
  final int state;

  /// 作品名称
  final String name;

  /// 竞赛名称（报名所属子项）
  final String raceSubName;

  /// 承办学院
  final String raceDepName;

  /// 记录 ID（团队 ID）
  final String id;

  /// 行号
  final int rowId;

  MyRaceItem({
    required this.subId,
    required this.raceId,
    required this.teamId,
    required this.sortId,
    required this.yearterm,
    required this.opinion,
    required this.isteam,
    required this.stateName,
    required this.state,
    required this.name,
    required this.raceSubName,
    required this.raceDepName,
    required this.id,
    required this.rowId,
  });

  factory MyRaceItem.fromJson(Map<String, dynamic> json) {
    return MyRaceItem(
      subId: json['sub_id']?.toString() ?? '',
      raceId: json['race_id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      sortId: json['sort_id']?.toString() ?? '',
      yearterm: json['yearterm']?.toString() ?? '',
      opinion: json['opinion']?.toString() ?? '',
      isteam: int.tryParse(json['isteam']?.toString() ?? '0') ?? 0,
      stateName: json['state_name']?.toString() ?? '',
      state: int.tryParse(json['state']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      raceSubName: json['race_sub_name']?.toString() ?? '',
      raceDepName: json['race_dep_name']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      rowId: int.tryParse(json['row_id']?.toString() ?? '0') ?? 0,
    );
  }
}

/// 我的竞赛分页结果
class MyRacePageResult {
  final List<MyRaceItem> list;
  final int totalCount;
  final int totalPage;
  final int currPage;
  final int pageSize;

  MyRacePageResult({
    required this.list,
    required this.totalCount,
    required this.totalPage,
    required this.currPage,
    required this.pageSize,
  });

  factory MyRacePageResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final rows = result['list'] as List? ?? [];
    return MyRacePageResult(
      list: rows
          .map((r) => MyRaceItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalCount: (result['totalCount'] as num?)?.toInt() ?? 0,
      totalPage: (result['totalPage'] as num?)?.toInt() ?? 0,
      currPage: (result['currPage'] as num?)?.toInt() ?? 1,
      pageSize: (result['pageSize'] as num?)?.toInt() ?? 15,
    );
  }
}

/// 我的竞赛团队详情（`raceTeam/queryById`）
class MyRaceDetail {
  /// 团队 ID
  final String id;

  /// 作品名称
  final String name;

  /// 竞赛名称（报名所属子项）
  final String raceSubName;

  /// 审核状态名
  final String stateName;

  /// 审核状态码
  final int state;

  /// 比赛年份
  final String year;

  /// 联系电话
  final String mobile;

  /// 是否团队（1=团队）
  final int isteam;

  /// 报名附件名
  final String attachName;

  /// 团队成员摘要文本（"学号-姓名,学号-姓名"）
  final String teamStuText;

  /// 指导教师摘要文本（"工号-姓名,工号-姓名"）
  final String teamTchText;

  /// 报名时间
  final String time;

  /// 审核意见时间线
  final List<MyRaceOpinion> opinions;

  /// 团队成员（完整信息，含专业班级）
  final List<MyRaceTeamStu> teamStus;

  /// 指导教师（完整信息）
  final List<MyRaceTeamTch> teamTchs;

  MyRaceDetail({
    required this.id,
    required this.name,
    required this.raceSubName,
    required this.stateName,
    required this.state,
    required this.year,
    required this.mobile,
    required this.isteam,
    required this.attachName,
    required this.teamStuText,
    required this.teamTchText,
    required this.time,
    required this.opinions,
    required this.teamStus,
    required this.teamTchs,
  });

  factory MyRaceDetail.fromJson(Map<String, dynamic> json) {
    // API 响应结构: { code, msg, result: { id, name, ... } }
    // 先剥掉外层 result
    final data = (json['result'] as Map<String, dynamic>?) ?? json;

    final opinions = (data['opinions'] as List? ?? [])
        .map((e) => MyRaceOpinion.fromJson(e as Map<String, dynamic>))
        .toList();
    final teamStus = (data['teamStus'] as List? ?? [])
        .map((e) => MyRaceTeamStu.fromJson(e as Map<String, dynamic>))
        .toList();
    final teamTchs = (data['teamTchs'] as List? ?? [])
        .map((e) => MyRaceTeamTch.fromJson(e as Map<String, dynamic>))
        .toList();

    return MyRaceDetail(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      raceSubName: data['race_sub_name']?.toString() ?? '',
      stateName: data['state_name']?.toString() ?? '',
      state: int.tryParse(data['state']?.toString() ?? '0') ?? 0,
      year: data['year']?.toString() ?? '',
      mobile: data['mobile']?.toString() ?? '',
      isteam: int.tryParse(data['isteam']?.toString() ?? '0') ?? 0,
      attachName: data['attach_name']?.toString() ?? '',
      teamStuText: data['team_stu']?.toString() ?? '',
      teamTchText: data['team_tch']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      opinions: opinions,
      teamStus: teamStus,
      teamTchs: teamTchs,
    );
  }
}

/// 审核意见（团队详情 opinions 列表项）
class MyRaceOpinion {
  /// 审核教师姓名
  final String teacherName;

  /// 审核时间
  final String time;

  /// 审核状态名（如 审核通过 / 驳回 / 教师审核通过）
  final String state;

  /// 审核状态码（字符串，如 "2" / "-1" / "1"）
  final String state1;

  /// 意见内容
  final String opinion;

  MyRaceOpinion({
    required this.teacherName,
    required this.time,
    required this.state,
    required this.state1,
    required this.opinion,
  });

  factory MyRaceOpinion.fromJson(Map<String, dynamic> json) {
    return MyRaceOpinion(
      teacherName: json['teacher_name']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      state1: json['state1']?.toString() ?? '',
      opinion: json['opinion']?.toString() ?? '',
    );
  }
}

/// 团队成员（详情 teamStus 列表项）
class MyRaceTeamStu {
  /// 姓名
  final String name;

  /// 学号
  final String stuNo;

  /// 是否队长（"1"=是）
  final String isleader;

  /// 排名
  final String rank;

  /// 排名名（如 第1名）
  final String rankname;

  /// 性别
  final String genderName;

  /// 专业
  final String specName;

  /// 班级
  final String className;

  /// 个人简介
  final String intro;

  MyRaceTeamStu({
    required this.name,
    required this.stuNo,
    required this.isleader,
    required this.rank,
    required this.rankname,
    required this.genderName,
    required this.specName,
    required this.className,
    required this.intro,
  });

  factory MyRaceTeamStu.fromJson(Map<String, dynamic> json) {
    return MyRaceTeamStu(
      name: json['name']?.toString() ?? '',
      stuNo: json['stu_no']?.toString() ?? '',
      isleader: json['isleader']?.toString() ?? '0',
      rank: json['rank']?.toString() ?? '',
      rankname: json['rankname']?.toString() ?? '',
      genderName: json['gender_name']?.toString() ?? '',
      specName: json['spec_name']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      intro: json['intro']?.toString() ?? '',
    );
  }
}

/// 指导教师（详情 teamTchs 列表项）
class MyRaceTeamTch {
  /// 工号
  final String tchNo;

  /// 姓名
  final String tchName;

  /// 是否组长（"1"=是）
  final String isleader;

  /// 排名
  final String rank;

  /// 排名名（如 第一名）
  final String rankname;

  MyRaceTeamTch({
    required this.tchNo,
    required this.tchName,
    required this.isleader,
    required this.rank,
    required this.rankname,
  });

  factory MyRaceTeamTch.fromJson(Map<String, dynamic> json) {
    return MyRaceTeamTch(
      tchNo: json['tch_no']?.toString() ?? '',
      tchName: json['tch_name']?.toString() ?? '',
      isleader: json['isleader']?.toString() ?? '0',
      rank: json['rank']?.toString() ?? '',
      rankname: json['rankname']?.toString() ?? '',
    );
  }
}
