/// 课程查询（kccx）模块数据模型
///
/// 对应 ehall jwapp 应用「课程查询」：
/// - kcxxcx.do：课程信息列表（Kc 模型，支持分页 + 条件查询）
/// - 主要字段：KCM 课程名 / KCH 课程号 / XF 学分 / XS 学时 /
///   KKDWDM 开课单位 / KSLXDM 考试类型 / KCFZR 负责人 /
///   KCCCDM 课程层次 / KCZTDM 课程状态
library;

/// 课程信息（kcxxcx.do 返回的一条记录）
class KccxCourse {
  /// 课程名（KCM）
  final String kcm;

  /// 课程号（KCH，如 "N19ZY01143"）
  final String kch;

  /// 学分（XF）
  final double xf;

  /// 总学时（XS）
  final double xs;

  /// 开课单位代码（KKDWDM，如 "XB011"）
  final String kkdwdm;

  /// 开课单位名称（KKDWDM_DISPLAY，如 "文艺学部"）
  final String kkdwDisplay;

  /// 考试类型代码（KSLXDM："1"=考试、"2"=考查）
  final String kslxdm;

  /// 考试类型名称（KSLXDM_DISPLAY）
  final String kslxDisplay;

  /// 课程负责人（KCFZR）
  final String kcfzr;

  /// 课程分类代码（KCFL1）
  final String kcfl1;

  /// 课程分类名称（KCFL1_DISPLAY）
  final String kcfl1Display;

  /// 课程层次代码（KCCCDM，如 "01"=本科）
  final String kcccdm;

  /// 课程层次名称（KCCCDM_DISPLAY，如 "本科"）
  final String kcccdmDisplay;

  /// 课程状态代码（KCZTDM："1"=启用）
  final String kcztdm;

  /// 课程状态名称（KCZTDM_DISPLAY）
  final String kcztdmDisplay;

  /// 课程类别代码（KCFLDM）
  final String kcfldm;

  /// 课程类别名称（KCFLDM_DISPLAY）
  final String kcfldmDisplay;

  /// 教学方式代码（JXFSDM）
  final String jxfsdm;

  /// 教学方式名称（JXFSDM_DISPLAY）
  final String jxfsDisplay;

  /// 课程水平代码（KCSPDM）
  final String kcspdm;

  /// 课程水平名称（KCSPDM_DISPLAY）
  final String kcspDisplay;

  /// 课程版本代码（KCBBDM）
  final String kcbbdm;

  /// 课程版本名称（KCBBDM_DISPLAY）
  final String kcbbDisplay;

  /// 授课语种代码（SKYZDM）
  final String skyzdm;

  /// 授课语种名称（SKYZDM_DISPLAY）
  final String skyzDisplay;

  /// 适用范围代码（SYFWDM）
  final String syfwdm;

  /// 适用范围名称（SYFWDM_DISPLAY）
  final String syfwDisplay;

  /// 适用院系或专业代码（SYYX）
  final String syyx;

  /// 适用院系或专业名称（SYYX_DISPLAY）
  final String syyxDisplay;

  /// 系室代码（JYSDM）
  final String jysdm;

  /// 系室名称（JYSDM_DISPLAY）
  final String jysDisplay;

  /// 课程级别代码（KCJBDM）
  final String kcjbdm;

  /// 课程级别名称（KCJBDM_DISPLAY）
  final String kcjbDisplay;

  /// 实验学时（SYXS）
  final double syxs;

  /// 课内周学时（KNZXS）
  final double knzxs;

  /// 课堂讲授学时（KTJSXS）
  final double ktjsxs;

  /// 上机学时（SJXS）
  final double sjxs;

  /// 课程实践学时（KCSJXS）
  final double kcsjxs;

  /// 英文课程名（YWKCM）
  final String ywkcm;

  /// 备注（BZ）
  final String bz;

  /// 唯一标识（WID）
  final String wid;

  KccxCourse({
    required this.kcm,
    required this.kch,
    required this.xf,
    required this.xs,
    required this.kkdwdm,
    required this.kkdwDisplay,
    required this.kslxdm,
    required this.kslxDisplay,
    required this.kcfzr,
    required this.kcfl1,
    required this.kcfl1Display,
    required this.kcccdm,
    required this.kcccdmDisplay,
    required this.kcztdm,
    required this.kcztdmDisplay,
    required this.kcfldm,
    required this.kcfldmDisplay,
    required this.jxfsdm,
    required this.jxfsDisplay,
    required this.kcspdm,
    required this.kcspDisplay,
    required this.kcbbdm,
    required this.kcbbDisplay,
    required this.skyzdm,
    required this.skyzDisplay,
    required this.syfwdm,
    required this.syfwDisplay,
    required this.syyx,
    required this.syyxDisplay,
    required this.jysdm,
    required this.jysDisplay,
    required this.kcjbdm,
    required this.kcjbDisplay,
    required this.syxs,
    required this.knzxs,
    required this.ktjsxs,
    required this.sjxs,
    required this.kcsjxs,
    required this.ywkcm,
    required this.bz,
    required this.wid,
  });

  factory KccxCourse.fromJson(Map<String, dynamic> json) {
    return KccxCourse(
      kcm: _str(json['KCM']),
      kch: _str(json['KCH']),
      xf: _double(json['XF']),
      xs: _double(json['XS']),
      kkdwdm: _str(json['KKDWDM']),
      kkdwDisplay: _str(json['KKDWDM_DISPLAY']),
      kslxdm: _str(json['KSLXDM']),
      kslxDisplay: _str(json['KSLXDM_DISPLAY']),
      kcfzr: _str(json['KCFZR']),
      kcfl1: _str(json['KCFL1']),
      kcfl1Display: _str(json['KCFL1_DISPLAY']),
      kcccdm: _str(json['KCCCDM']),
      kcccdmDisplay: _str(json['KCCCDM_DISPLAY']),
      kcztdm: _str(json['KCZTDM']),
      kcztdmDisplay: _str(json['KCZTDM_DISPLAY']),
      kcfldm: _str(json['KCFLDM']),
      kcfldmDisplay: _str(json['KCFLDM_DISPLAY']),
      jxfsdm: _str(json['JXFSDM']),
      jxfsDisplay: _str(json['JXFSDM_DISPLAY']),
      kcspdm: _str(json['KCSPDM']),
      kcspDisplay: _str(json['KCSPDM_DISPLAY']),
      kcbbdm: _str(json['KCBBDM']),
      kcbbDisplay: _str(json['KCBBDM_DISPLAY']),
      skyzdm: _str(json['SKYZDM']),
      skyzDisplay: _str(json['SKYZDM_DISPLAY']),
      syfwdm: _str(json['SYFWDM']),
      syfwDisplay: _str(json['SYFWDM_DISPLAY']),
      syyx: _str(json['SYYX']),
      syyxDisplay: _str(json['SYYX_DISPLAY']),
      jysdm: _str(json['JYSDM']),
      jysDisplay: _str(json['JYSDM_DISPLAY']),
      kcjbdm: _str(json['KCJBDM']),
      kcjbDisplay: _str(json['KCJBDM_DISPLAY']),
      syxs: _double(json['SYXS']),
      knzxs: _double(json['KNZXS']),
      ktjsxs: _double(json['KTJSXS']),
      sjxs: _double(json['SJXS']),
      kcsjxs: _double(json['KCSJXS']),
      ywkcm: _str(json['YWKCM']),
      bz: _str(json['BZ']),
      wid: _str(json['WID']),
    );
  }

  /// 学分展示：如 "2.0 学分"
  String get xfText =>
      xf == xf.truncateToDouble() ? '${xf.toInt()} 学分' : '$xf 学分';

  /// 学时展示：如 "32 学时"
  String get xsText =>
      xs == xs.truncateToDouble() ? '${xs.toInt()} 学时' : '$xs 学时';
}

/// 分页查询结果
class KccxPageResult {
  final List<KccxCourse> rows;
  final int totalSize;
  final int pageNumber;
  final int pageSize;

  KccxPageResult({
    required this.rows,
    required this.totalSize,
    required this.pageNumber,
    required this.pageSize,
  });

  bool get hasMore => rows.length < totalSize;
}

String _str(Object? v) => v?.toString() ?? '';

double _double(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
