/// 网上评教（wspj / jwwspj）模块数据模型
///
/// 对应 ehall jwapp 应用「网上评教」（入口 appShow?appId=5077744448763966）：
/// - config/jwwspj.do：评教模块列表（学生评教 pj / 评教历史 pjls 等）
/// - cxcssz.do：评教管理系统参数（评教时间窗口、学生比例等）
/// - xnxqcx.do：学年学期查询
/// - cxxspjwjlb.do：学生评教问卷列表
library;

/// 评教模块配置（config/jwwspj.do 返回的一条记录）
class WspjModule {
  /// 选择器（"*"）
  final String selector;

  /// 模块 ID
  final String id;

  /// 标题（如 "学生评教"）
  final String title;

  /// 模块代码（如 "pj"）
  final String mod;

  /// 类型（"mod"）
  final String type;

  WspjModule({
    required this.selector,
    required this.id,
    required this.title,
    required this.mod,
    required this.type,
  });

  factory WspjModule.fromJson(Map<String, dynamic> json) => WspjModule(
        selector: _str(json['selector']),
        id: _str(json['id']),
        title: _str(json['title']),
        mod: _str(json['mod']),
        type: _str(json['type']),
      );
}

/// 评教系统参数项（cxcssz.do 返回的一条记录）
///
/// 关键参数（CSDM → CSZA）：
/// - PJXNXQ：评教当前学年学期（如 "2025-2026-2"）
/// - PJKSSJ：评教开始时间（如 "2026-03-10 09:00:00"）
/// - PJJSSJ：评教结束时间（如 "2026-06-18 18:00:00"）
/// - SFSY：是否使用（"1"=使用）
/// - XSFS：学生分数 / XSBL：学生比例
/// - XSSFKXG：学生提交后是否可修改
/// - ZGPJSFBT：主观评价是否必须填写
class WspjConfigItem {
  /// 参数组代码（CSDM，如 "PJGLPJSJ"=评教管理评教设置）
  final String csdm;

  /// 子参数代码（ZCSDM，如 "PJXNXQ"）
  final String zcsdm;

  /// 参数名称（CSZB）
  final String cszb;

  /// 参数值（CSZA）
  final String csza;

  /// 参数说明（CSSM）
  final String cssm;

  /// 唯一标识（WID）
  final String wid;

  WspjConfigItem({
    required this.csdm,
    required this.zcsdm,
    required this.cszb,
    required this.csza,
    required this.cssm,
    required this.wid,
  });

  factory WspjConfigItem.fromJson(Map<String, dynamic> json) =>
      WspjConfigItem(
        csdm: _str(json['CSDM']),
        zcsdm: _str(json['ZCSDM']),
        cszb: _str(json['CSZB']),
        csza: _str(json['CSZA']),
        cssm: _str(json['CSSM']),
        wid: _str(json['WID']),
      );
}

/// 学年学期（xnxqcx.do 返回的一条记录）
class WspjSemester {
  /// 学期代码（DM，如 "2025-2026-2"）
  final String dm;

  /// 学年代码（XNDM，如 "2025-2026"）
  final String xndm;

  /// 学期代码（XQDM，如 "2"）
  final String xqdm;

  /// 学期名称（MC，如 "2025-2026学年 第2学期"）
  final String mc;

  /// 是否使用（SFSY，1=使用）
  final int sfsy;

  /// 唯一标识（WID）
  final String wid;

  WspjSemester({
    required this.dm,
    required this.xndm,
    required this.xqdm,
    required this.mc,
    required this.sfsy,
    required this.wid,
  });

  factory WspjSemester.fromJson(Map<String, dynamic> json) => WspjSemester(
        dm: _str(json['DM']),
        xndm: _str(json['XNDM']),
        xqdm: _str(json['XQDM']),
        mc: _str(json['MC']),
        sfsy: _int(json['SFSY']),
        wid: _str(json['WID']),
      );
}

/// 学生评教问卷（cxxspjwjlb.do 返回的一条记录）
class WspjQuestionnaire {
  /// 问卷名称（WJMC，如 "学生评教"）
  final String wjmc;

  /// 问卷代码（WJDM）
  final String wjdm;

  /// 总分值（ZFZ，如 "100"）
  final String zfz;

  /// 评教学号（CPR，如 "240105118"）
  final String cpr;

  /// 评教类型代码（PGLXDM，如 "01"）
  final String pglxdm;

  /// 评教类型名称（PGLXDM_DISPLAY）
  final String pglxDisplay;

  /// 是否评教（SFPG："1"=已评教）
  final String sfpg;

  /// 评教类别代码（PGLBDM，如 "11"）
  final String pglbdm;

  /// 评教类别名称（PGLBDM_DISPLAY）
  final String pglbDisplay;

  /// 是否发布（SFFB："1"=已发布）
  final String sffb;

  /// 问卷说明（WJSM，多行文本）
  final String wjsm;

  /// 学年学期代码（XNXQDM）
  final String xnxqdm;

  /// 学年学期名称（XNXQDM_DISPLAY）
  final String xnxqDisplay;

  /// 教学班 ID（JXBID）
  final String jxbid;

  /// 完成度（WCD，如 "100"=已完成）
  final String wcd;

  WspjQuestionnaire({
    required this.wjmc,
    required this.wjdm,
    required this.zfz,
    required this.cpr,
    required this.pglxdm,
    required this.pglxDisplay,
    required this.sfpg,
    required this.pglbdm,
    required this.pglbDisplay,
    required this.sffb,
    required this.wjsm,
    required this.xnxqdm,
    required this.xnxqDisplay,
    required this.jxbid,
    required this.wcd,
  });

  factory WspjQuestionnaire.fromJson(Map<String, dynamic> json) =>
      WspjQuestionnaire(
        wjmc: _str(json['WJMC']),
        wjdm: _str(json['WJDM']),
        zfz: _str(json['ZFZ']),
        cpr: _str(json['CPR']),
        pglxdm: _str(json['PGLXDM']),
        pglxDisplay: _str(json['PGLXDM_DISPLAY']),
        sfpg: _str(json['SFPG']),
        pglbdm: _str(json['PGLBDM']),
        pglbDisplay: _str(json['PGLBDM_DISPLAY']),
        sffb: _str(json['SFFB']),
        wjsm: _str(json['WJSM']),
        xnxqdm: _str(json['XNXQDM']),
        xnxqDisplay: _str(json['XNXQDM_DISPLAY']),
        jxbid: _str(json['JXBID']),
        wcd: _str(json['WCD']),
      );

  /// 是否已完成评教（SFPG=1 或完成度 >= 100）
  bool get isDone => sfpg == '1' || _int(wcd) >= 100;
}

String _str(Object? v) => v?.toString() ?? '';

int _int(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}
