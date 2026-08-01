// ==================== 大学生创新创业训练计划（SRTP） ====================

/// 我参与的项目（`myProject/listIsMeJoinProjectsPage` 列表项）
class SrtpProjectItem {
  /// 项目 ID
  final String id;

  /// 项目名称
  final String name;

  /// 计划名称（如 2025年"大学生创新创业训练计划"项目）
  final String subject;

  /// 当前阶段（0=申报 / 1=中期 / 4=结题）
  final int stage;

  /// 阶段状态串（如 "4,4"、"0,-1"，逗号分隔各阶段状态）
  final String stageState;

  /// 状态码（-1=终止/驳回 / 0=申报中 / 4=已结题）
  final int state;

  /// 中期检查时间窗口（"开始时间,结束时间"）
  final String midTime;

  /// 进度（通常为 null）
  final String progress;

  /// 行号
  final int rowId;

  SrtpProjectItem({
    required this.id,
    required this.name,
    required this.subject,
    required this.stage,
    required this.stageState,
    required this.state,
    required this.midTime,
    required this.progress,
    required this.rowId,
  });

  factory SrtpProjectItem.fromJson(Map<String, dynamic> json) {
    return SrtpProjectItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      stage: int.tryParse(json['stage']?.toString() ?? '0') ?? 0,
      stageState: json['stage_state']?.toString() ?? '',
      state: int.tryParse(json['state']?.toString() ?? '0') ?? 0,
      midTime: json['mid_time']?.toString() ?? '',
      progress: json['progress']?.toString() ?? '',
      rowId: int.tryParse(json['row_id']?.toString() ?? '0') ?? 0,
    );
  }
}

/// 我参与的项目分页结果
class SrtpProjectPageResult {
  final List<SrtpProjectItem> list;
  final int totalCount;
  final int totalPage;
  final int currPage;
  final int pageSize;

  SrtpProjectPageResult({
    required this.list,
    required this.totalCount,
    required this.totalPage,
    required this.currPage,
    required this.pageSize,
  });

  factory SrtpProjectPageResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final rows = result['list'] as List? ?? [];
    return SrtpProjectPageResult(
      list: rows
          .map((r) => SrtpProjectItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalCount: (result['totalCount'] as num?)?.toInt() ?? 0,
      totalPage: (result['totalPage'] as num?)?.toInt() ?? 0,
      currPage: (result['currPage'] as num?)?.toInt() ?? 1,
      pageSize: (result['pageSize'] as num?)?.toInt() ?? 10,
    );
  }
}

/// 我申请的项目（`myProject/listProjectProgressPage` 列表项）
class SrtpAppliedProjectItem {
  /// 项目 ID
  final String id;

  /// 项目名称
  final String name;

  /// 项目编号
  final String projectNo;

  /// 所属学院
  final String depName;

  /// 申请时间
  final String applyDate;

  /// 项目简介
  final String summary;

  /// 预算总额
  final double cost;

  /// 确认经费
  final double confirmCost;

  /// 状态码（-1=终止/驳回 / 0=申报中 / 4=已结题）
  final int state;

  /// 当前阶段（0=申报 / 1=中期 / 4=结题）
  final int stage;

  /// 负责人姓名
  final String stuName;

  /// 负责人学号
  final String stuNo;

  /// 项目级别
  final String projectLevel;

  /// 行号
  final int rowId;

  SrtpAppliedProjectItem({
    required this.id,
    required this.name,
    required this.projectNo,
    required this.depName,
    required this.applyDate,
    required this.summary,
    required this.cost,
    required this.confirmCost,
    required this.state,
    required this.stage,
    required this.stuName,
    required this.stuNo,
    required this.projectLevel,
    required this.rowId,
  });

  factory SrtpAppliedProjectItem.fromJson(Map<String, dynamic> json) {
    return SrtpAppliedProjectItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      projectNo: json['project_no']?.toString() ?? '',
      depName: json['dep_name']?.toString() ?? '',
      applyDate: json['apply_date']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      cost: _toDouble(json['cost']),
      confirmCost: _toDouble(json['confirm_cost']),
      state: int.tryParse(json['state']?.toString() ?? '0') ?? 0,
      stage: int.tryParse(json['stage']?.toString() ?? '0') ?? 0,
      stuName: json['stu_name']?.toString() ?? '',
      stuNo: json['stu_no']?.toString() ?? '',
      projectLevel: json['project_level']?.toString() ?? '',
      rowId: int.tryParse(json['row_id']?.toString() ?? '0') ?? 0,
    );
  }
}

/// 我申请的项目分页结果
class SrtpAppliedProjectPageResult {
  final List<SrtpAppliedProjectItem> list;
  final int totalCount;
  final int totalPage;
  final int currPage;
  final int pageSize;

  SrtpAppliedProjectPageResult({
    required this.list,
    required this.totalCount,
    required this.totalPage,
    required this.currPage,
    required this.pageSize,
  });

  factory SrtpAppliedProjectPageResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final rows = result['list'] as List? ?? [];
    return SrtpAppliedProjectPageResult(
      list: rows
          .map((r) => SrtpAppliedProjectItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalCount: (result['totalCount'] as num?)?.toInt() ?? 0,
      totalPage: (result['totalPage'] as num?)?.toInt() ?? 0,
      currPage: (result['currPage'] as num?)?.toInt() ?? 1,
      pageSize: (result['pageSize'] as num?)?.toInt() ?? 10,
    );
  }
}

/// SRTP 项目详情（`common/stuProjectShow`）
class SrtpProjectDetail {
  /// 项目 ID
  final String id;

  /// 项目名称
  final String name;

  /// 计划名称
  final String planName;

  /// 项目编号
  final String projectNo;

  /// 所属学院
  final String depName;

  /// 申请时间
  final String applyDate;

  /// 状态码
  final int state;

  /// 当前阶段
  final int stage;

  /// 预算总额
  final double cost;

  /// 确认经费
  final double confirmCost;

  /// 项目简介
  final String summary;

  /// 申报书附件名
  final String applyFile;

  /// 结题报告附件名
  final String finalFile;

  /// 团队成员
  final List<SrtpStu> stus;

  /// 指导教师
  final List<SrtpTea> teas;

  /// 审核记录
  final List<SrtpAudit> audits;

  /// 项目成果（结题后才有）
  final List<SrtpResult> results;

  /// 预算明细
  final List<SrtpBudget> budget;

  /// 支出明细
  final List<SrtpBudget> spend;

  SrtpProjectDetail({
    required this.id,
    required this.name,
    required this.planName,
    required this.projectNo,
    required this.depName,
    required this.applyDate,
    required this.state,
    required this.stage,
    required this.cost,
    required this.confirmCost,
    required this.summary,
    required this.applyFile,
    required this.finalFile,
    required this.stus,
    required this.teas,
    required this.audits,
    required this.results,
    required this.budget,
    required this.spend,
  });

  factory SrtpProjectDetail.fromJson(Map<String, dynamic> json) {
    // API 响应结构: { code, msg, result: { id, name, ... } }
    // 先剥掉外层 result
    final data = (json['result'] as Map<String, dynamic>?) ?? json;

    final stus = (data['stus'] as List? ?? [])
        .map((e) => SrtpStu.fromJson(e as Map<String, dynamic>))
        .toList();
    final teas = (data['teas'] as List? ?? [])
        .map((e) => SrtpTea.fromJson(e as Map<String, dynamic>))
        .toList();
    final audits = (data['audits'] as List? ?? [])
        .map((e) => SrtpAudit.fromJson(e as Map<String, dynamic>))
        .toList();
    final results = (data['results'] as List? ?? [])
        .map((e) => SrtpResult.fromJson(e as Map<String, dynamic>))
        .toList();
    final budget = (data['budget'] as List? ?? [])
        .map((e) => SrtpBudget.fromJson(e as Map<String, dynamic>))
        .toList();
    final spend = (data['spend'] as List? ?? [])
        .map((e) => SrtpBudget.fromJson(e as Map<String, dynamic>))
        .toList();

    return SrtpProjectDetail(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      planName: data['plan_name']?.toString() ?? '',
      projectNo: data['project_no']?.toString() ?? '',
      depName: data['dep_name']?.toString() ?? '',
      applyDate: data['apply_date']?.toString() ?? '',
      state: int.tryParse(data['state']?.toString() ?? '0') ?? 0,
      stage: int.tryParse(data['stage']?.toString() ?? '0') ?? 0,
      cost: _toDouble(data['cost']),
      confirmCost: _toDouble(data['confirm_cost']),
      summary: data['summary']?.toString() ?? '',
      applyFile: data['applyFile']?.toString() ?? '',
      finalFile: data['finalFile']?.toString() ?? '',
      stus: stus,
      teas: teas,
      audits: audits,
      results: results,
      budget: budget,
      spend: spend,
    );
  }
}

/// 团队成员（详情 stus 列表项）
class SrtpStu {
  /// 姓名
  final String stuName;

  /// 学号
  final String stuNo;

  /// 是否负责人（"1"=是）
  final String isPri;

  /// 排名
  final int rank;

  /// 分工
  final String duty;

  /// 班级
  final String className;

  /// 电话
  final String mobile;

  /// 邮箱
  final String email;

  /// 是否已报名（"是"/"否"）
  final String isByName;

  SrtpStu({
    required this.stuName,
    required this.stuNo,
    required this.isPri,
    required this.rank,
    required this.duty,
    required this.className,
    required this.mobile,
    required this.email,
    required this.isByName,
  });

  factory SrtpStu.fromJson(Map<String, dynamic> json) {
    return SrtpStu(
      stuName: json['stu_name']?.toString() ?? '',
      stuNo: json['stu_no']?.toString() ?? '',
      isPri: json['is_pri']?.toString() ?? '0',
      rank: int.tryParse(json['rank']?.toString() ?? '0') ?? 0,
      duty: json['duty']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isByName: json['is_by_name']?.toString() ?? '',
    );
  }
}

/// 指导教师（详情 teas 列表项）
class SrtpTea {
  /// 教师 ID
  final String teaId;

  /// 姓名
  final String teaName;

  /// 是否第一导师（"1"=是）
  final String isPri;

  /// 所属学院
  final String depName;

  /// 电话
  final String mobile;

  /// 邮箱
  final String email;

  SrtpTea({
    required this.teaId,
    required this.teaName,
    required this.isPri,
    required this.depName,
    required this.mobile,
    required this.email,
  });

  factory SrtpTea.fromJson(Map<String, dynamic> json) {
    return SrtpTea(
      teaId: json['tea_id']?.toString() ?? '',
      teaName: json['tea_name']?.toString() ?? '',
      isPri: json['is_pri']?.toString() ?? '0',
      depName: json['dep_name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

/// 审核记录（详情 audits 列表项）
class SrtpAudit {
  /// 审核时间
  final String addDate;

  /// 审核阶段（如 项目申请 / 项目结题）
  final String stage;

  /// 审核意见
  final String advice;

  /// 审核层级（如 校级 / 学院 / 导师）
  final String rule;

  /// 审核结果（如 校级通过 / 导师通过）
  final String state;

  /// 审核人
  final String addUser;

  SrtpAudit({
    required this.addDate,
    required this.stage,
    required this.advice,
    required this.rule,
    required this.state,
    required this.addUser,
  });

  factory SrtpAudit.fromJson(Map<String, dynamic> json) {
    return SrtpAudit(
      addDate: json['add_date']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      advice: json['advice']?.toString() ?? '',
      rule: json['rule']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      addUser: json['add_user']?.toString() ?? '',
    );
  }
}

/// 项目成果（详情 results 列表项）
class SrtpResult {
  /// 成果名称
  final String name;

  /// 成果描述
  final String description;

  /// 获得时间
  final String getDate;

  /// 成果人
  final String owner;

  /// 获奖名称（竞赛类）
  final String awardName;

  /// 获奖单位
  final String awardDep;

  /// 获奖级别
  final String awardLevel;

  /// 附件文件名
  final String fileNames;

  SrtpResult({
    required this.name,
    required this.description,
    required this.getDate,
    required this.owner,
    required this.awardName,
    required this.awardDep,
    required this.awardLevel,
    required this.fileNames,
  });

  factory SrtpResult.fromJson(Map<String, dynamic> json) {
    return SrtpResult(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      getDate: json['get_date']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      awardName: json['award_name']?.toString() ?? '',
      awardDep: json['award_dep']?.toString() ?? '',
      awardLevel: json['award_level']?.toString() ?? '',
      fileNames: json['file_names']?.toString() ?? '',
    );
  }
}

/// 经费明细（详情 budget / spend 列表项）
class SrtpBudget {
  /// 类别码（数字，无文本映射）
  final String category;

  /// 摘要
  final String summary;

  /// 金额
  final double cost;

  /// 添加时间
  final String addDate;

  /// 支出时间
  final String payDate;

  SrtpBudget({
    required this.category,
    required this.summary,
    required this.cost,
    required this.addDate,
    required this.payDate,
  });

  factory SrtpBudget.fromJson(Map<String, dynamic> json) {
    return SrtpBudget(
      category: json['category']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      cost: _toDouble(json['cost']),
      addDate: json['add_date']?.toString() ?? '',
      payDate: json['pay_date']?.toString() ?? '',
    );
  }
}

/// 兼容数字字段：服务端有的返回 num（如顶层 cost: 20000）、
/// 有的返回字符串（如 budget[].cost: "1000"），统一安全转 double。
double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}
