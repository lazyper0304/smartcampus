/// 网上评教（wspj / jwwspj）模块数据模型
///
/// 对应 ehall jwapp 应用「网上评教」（入口 appShow?appId=5077744448763966）：
/// - config/jwwspj.do：评教模块列表（学生评教 pj / 评教历史 pjls 等）
/// - cxcssz.do：评教管理系统参数（评教时间窗口、学生比例等）
/// - xnxqcx.do：学年学期查询
/// - cxxspjwjlb.do：学生评教问卷列表
/// - cxwjzbxq.do：**问卷题目 + 选项一体**（本模块唯一取题数据源）
/// - cxpgjg.do：评教结果（用于回看已评答案 `DA`/`ZGDA`）
///
/// ⚠️ 全部字段名均为服务端数据库列名（2026-10-09 真机抓包核实）：
/// 题干是 `ZBSM`（**不是** ZBMC）、题型是 `ZBLXDM`（**不是** TXDM）、
/// 选项文字是 `DASM`（**不是** DAFXMC）、档位是 `DAPX`。
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

  /// 被评教师工号（`BPR`）
  ///
  /// ⚠️ `cxxspjwjlb.do` **不返回**该字段，由列表页预取 `cxwjzbxq.do`
  /// （见 [WspjService.fetchTeacherBriefs]）补齐；分组键即取此字段。
  final String bpr;

  /// 被评教师姓名（`BPRXM`，来自 `cxwjzbxq.do`）
  final String bprxm;

  /// 课程名（`KCM`，来自 `cxwjzbxq.do`）
  final String kcm;

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
    this.bpr = '',
    this.bprxm = '',
    this.kcm = '',
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

  /// 缓存键（`WJDM|JXBID`）：一份问卷的教师信息靠这两个参数唯一确定
  String get cacheKey => '$wjdm|$jxbid';

  /// 分组用教师标识：优先工号 `BPR`，缺失时退回教学班 `JXBID`
  /// （仍可保证「同一老师一份问卷」的常见结构下正确分组）
  String get groupKey => bpr.isNotEmpty ? bpr : 'jxbid:$jxbid';

  /// 分组显示名：教师姓名 → 未知教师占位
  String get teacherLabel => bprxm.isNotEmpty ? bprxm : '待确认教师';

  /// 补齐教师/课程信息（来自 `cxwjzbxq.do`）
  WspjQuestionnaire withTeacher({
    String bpr = '',
    String bprxm = '',
    String kcm = '',
  }) =>
      WspjQuestionnaire(
        wjmc: wjmc,
        wjdm: wjdm,
        zfz: zfz,
        cpr: cpr,
        pglxdm: pglxdm,
        pglxDisplay: pglxDisplay,
        sfpg: sfpg,
        pglbdm: pglbdm,
        pglbDisplay: pglbDisplay,
        sffb: sffb,
        wjsm: wjsm,
        xnxqdm: xnxqdm,
        xnxqDisplay: xnxqDisplay,
        jxbid: jxbid,
        wcd: wcd,
        bpr: bpr.isNotEmpty ? bpr : this.bpr,
        bprxm: bprxm.isNotEmpty ? bprxm : this.bprxm,
        kcm: kcm.isNotEmpty ? kcm : this.kcm,
      );

  /// 卡片标题。⚠️ `cxxspjwjlb.do` **只返回** WJMC/WJDM/ZFZ/WJSM/XNXQDM(±_DISPLAY)/
  /// PGLXDM(±_DISPLAY)/PGLBDM(±_DISPLAY)/JXBID/CPR/SFPG/SFFB/WCD，
  /// **不含**课程名与教师名（实测确认）。课程/教师由列表页预取
  /// `cxwjzbxq.do`（KCM/BPRXM）补齐后写入 [kcm]；未补齐时退回问卷名。
  String get displayTitle =>
      kcm.isNotEmpty ? kcm : (wjmc.isEmpty ? '学生评教' : wjmc);
}

/// 一份问卷的教师/课程摘要（列表页分组用）
///
/// 由 `WspjService.fetchTeacherBriefs` 预取 `cxwjzbxq.do` 提取；
/// 该接口同时返回题目行，故摘要里顺带带上题量与满分合计，
/// 列表页无需为每份问卷二次进详情页。
class WspjTeacherBrief {
  /// 教师工号（`BPR`）
  final String bpr;

  /// 教师姓名（`BPRXM`）
  final String bprxm;

  /// 课程名（`KCM`）
  final String kcm;

  /// 题量（去重后 `ZBDM` 数）
  final int questionCount;

  /// 分值题满分合计（`FZ` 之和）
  final int fullScore;

  const WspjTeacherBrief({
    this.bpr = '',
    this.bprxm = '',
    this.kcm = '',
    this.questionCount = 0,
    this.fullScore = 0,
  });

  /// 是否成功取到教师信息（取不到时列表页显示占位而非空白）
  bool get isValid => bprxm.isNotEmpty || kcm.isNotEmpty;
}

/// 评教题目（指标）—— 数据源 `cxwjzbxq.do` 的一行
///
/// ⚠️ 字段名为 2026-10-09 真机抓包实测结果，**勿按其他学校实现臆测**：
/// - `ZBSM` = 题干正文（其他学校版本叫 ZBMC，宜宾**不是**）
/// - `ZBLXDM` = 题型代码（其他学校叫 TXDM，宜宾**不是**）
/// - `ZBLXDM_DISPLAY` = 题型中文名（"分值题"/"单选题"/"主观题"）
/// - `ZBFLDM_DISPLAY` = 指标分类名（"教学态度"/"教学目标"/"教学内容"…）
/// - `FZ` = 本题满分（分值题即最大可填分值）
/// - `BZ` = 备注；**主观题时为最少字数要求**（实测 BZ=20 → 至少 20 字）
/// - `ZBPX` = 排序号
/// - `DASM` = 选项文字（**仅单选/星级题有值**，分值题与主观题为 null）
/// - `DAPX` = 档位序号（**仅选择题有值**）
/// - `WID` = 唯一标识（服务端主键，回传时用）
class WspjQuestion {
  /// 指标代码 = 题目唯一标识，**答案回传时用它关联**
  final String zbdm;

  /// 题干正文（`ZBSM`）
  final String zbsm;

  /// 题型代码（`ZBLXDM`）：01 单选 / 02 主观 / 03 分值
  final String zblxdm;

  /// 题型中文名（`ZBLXDM_DISPLAY`）
  final String zblxDisplay;

  /// 指标分类代码（`ZBFLDM`）
  final String zbflDm;

  /// 指标分类名（`ZBFLDM_DISPLAY`），如"教学态度"
  final String zbflDisplay;

  /// 本题满分（`FZ`）；分值题即最大可填分
  final String fz;

  /// 备注（`BZ`）；主观题为最少字数要求
  final String bz;

  /// 排序号（`ZBPX`）
  final String zbpx;

  /// 教学班 ID（`JXBID`）
  final String jxbid;

  /// 被评人代码（`BPR`，教师工号）
  final String bpr;

  /// 被评人姓名（`BPRXM`，教师姓名）
  final String bprxm;

  /// 课程名（`KCM`）
  final String kcm;

  /// 评估内容代码（`PGNR`）
  final String pgnr;

  /// 教学班类型代码（`JXBLXDM`）
  final String jxblxdm;

  /// 问卷代码（`WJDM`）
  final String wjdm;

  /// 唯一标识（`WID`）
  final String wid;

  /// 选项文字（`DASM`）——**仅选择题有值**，其余题型为 null
  final String dasm;

  /// 档位序号（`DAPX`）——**仅选择题有值**
  final String dapx;

  /// 答案代码（`DADM`）
  final String dadm;

  const WspjQuestion({
    required this.zbdm,
    required this.zbsm,
    required this.zblxdm,
    this.zblxDisplay = '',
    this.zbflDm = '',
    this.zbflDisplay = '',
    this.fz = '',
    this.bz = '',
    this.zbpx = '',
    this.jxbid = '',
    this.bpr = '',
    this.bprxm = '',
    this.kcm = '',
    this.pgnr = '',
    this.jxblxdm = '',
    this.wjdm = '',
    this.wid = '',
    this.dasm = '',
    this.dapx = '',
    this.dadm = '',
  });

  factory WspjQuestion.fromJson(Map<String, dynamic> json) => WspjQuestion(
        zbdm: _str(json['ZBDM']),
        zbsm: _str(json['ZBSM']),
        zblxdm: _str(json['ZBLXDM']),
        zblxDisplay: _str(json['ZBLXDM_DISPLAY']),
        zbflDm: _str(json['ZBFLDM']),
        zbflDisplay: _str(json['ZBFLDM_DISPLAY']),
        fz: _fmtNum(json['FZ']),
        bz: _str(json['BZ']),
        zbpx: _str(json['ZBPX']),
        jxbid: _str(json['JXBID']),
        bpr: _str(json['BPR']),
        bprxm: _str(json['BPRXM']),
        kcm: _str(json['KCM']),
        pgnr: _str(json['PGNR']),
        jxblxdm: _str(json['JXBLXDM']),
        wjdm: _str(json['WJDM']),
        wid: _str(json['WID']),
        dasm: _str(json['DASM']),
        dapx: _str(json['DAPX']),
        dadm: _str(json['DADM']),
      );

  /// 题型：单选 / 星级（可选选项的客观题）
  static const String txChoice = '01';

  /// 题型：主观题
  static const String txSubjective = '02';

  /// 题型：分值题
  static const String txScore = '03';

  bool get isSubjective => zblxdm == txSubjective;

  bool get isScore => zblxdm == txScore;

  /// 是否为「从一组选项中选一个」的题型
  bool get isChoice => zblxdm == txChoice;

  /// 分值题满分（整数；非分值题或数据异常返回 null）
  int? get maxScore {
    final n = int.tryParse(fz);
    if (n == null || n <= 0) return null;
    return n;
  }

  /// 主观题最少字数（`BZ`），非主观题或未配置返回 null
  int? get minWords {
    if (!isSubjective) return null;
    final n = int.tryParse(bz);
    if (n == null || n <= 0) return null;
    return n;
  }

  /// 题型标签：优先服务端中文名
  String get txLabel {
    if (zblxDisplay.isNotEmpty) return zblxDisplay;
    switch (zblxdm) {
      case txSubjective:
        return '主观题';
      case txScore:
        return '分值题';
      case txChoice:
        return '单选题';
      default:
        return '题目';
    }
  }
}

/// 问卷（`cxwjzbxq.do` 返回的一整份，按题目组织）
///
/// 实测该接口用 `WJDM + JXBID` 两个参数即可返回本教学班的**全部题目行**
/// （本班 25 行 = 24 分值题 + 1 主观题），单选/星级题每个选项各占一行，
/// 用 `ZBDM` 归并为一道题的多个选项。
class WspjPaper {
  /// 来源问卷（列表接口条目）
  final WspjQuestionnaire questionnaire;

  /// 全部原始行（题目 + 选项展开）
  final List<WspjQuestion> rows;

  /// Bingo 评教任务 ID（`/evaluation` 返回的 `id`），提交时随 `task_id` 回传。
  /// 直连 jwwspj 时恒为 0（该链路无此概念）。
  final int taskId;

  /// 原始 Bingo 问卷（题目 × 教师二维结构）。
  ///
  /// 提交报文**必须**由它生成：UI 侧 [rows] 是按 `ZBDM` 归并后的一维结构，
  /// 教师维度已折叠进 `ZBDM`，无法反解出完整的 (题目 × 教师) 集合。
  /// 直连 jwwspj 时为 null。
  final Object? source;

  const WspjPaper({
    required this.questionnaire,
    required this.rows,
    this.taskId = 0,
    this.source,
  });

  /// 按 `ZBDM` 归并后的题目（保持 `ZBPX` 排序）
  List<WspjQuestion> get questions {
    final seen = <String>{};
    final out = <WspjQuestion>[];
    for (final r in rows) {
      if (r.zbdm.isEmpty) continue;
      if (seen.add(r.zbdm)) out.add(r);
    }
    out.sort((a, b) => (int.tryParse(a.zbpx) ?? 0)
        .compareTo(int.tryParse(b.zbpx) ?? 0));
    return out;
  }

  /// 取某题的选项行（同一 `ZBDM` 的其他行）
  ///
  /// 分值题/主观题无选项，返回空列表；选择题返回各档位。
  List<WspjQuestion> optionsOf(WspjQuestion q) {
    final out = rows
        .where((r) => r.zbdm == q.zbdm && r.dasm.isNotEmpty)
        .toList();
    out.sort((a, b) => (int.tryParse(a.dapx) ?? 0)
        .compareTo(int.tryParse(b.dapx) ?? 0));
    return out;
  }

  /// 题目总数
  int get total => questions.length;

  /// 主观题数量
  int get subjectiveCount =>
      questions.where((q) => q.isSubjective).length;

  /// 单选/星级题数量
  int get choiceCount => questions.where((q) => q.isChoice).length;

  /// 分值题数量
  int get scoreCount => questions.where((q) => q.isScore).length;

  /// 满分合计（分值题 FZ 之和）
  int get totalScore => questions.fold(
      0, (sum, q) => sum + (q.maxScore ?? 0));

  /// 教师姓名（取任一行的 `BPRXM`）
  String get teacherName {
    for (final r in rows) {
      if (r.bprxm.isNotEmpty) return r.bprxm;
    }
    return '';
  }

  /// 课程名（取任一行的 `KCM`）
  String get courseName {
    for (final r in rows) {
      if (r.kcm.isNotEmpty) return r.kcm;
    }
    return '';
  }

  /// 评估内容代码（`PGNR`，提交必需）
  String get pgnr {
    for (final r in rows) {
      if (r.pgnr.isNotEmpty) return r.pgnr;
    }
    return '';
  }

  /// 被评人代码（`BPR`，提交必需）
  String get bpr {
    for (final r in rows) {
      if (r.bpr.isNotEmpty) return r.bpr;
    }
    return '';
  }
}

/// 评教结果 / 已评答案（`cxpgjg.do` 返回的一行）
///
/// ⚠️ 实测字段（2026-10-09）：该接口按 **每个指标一行** 返回，字段是
/// `cxwjzbxq.do` 行的**子集** —— 只有 `DA`（分值/选择题答案）与 `ZGDA`
/// （主观题答案）两个字段承载作答内容，**没有 `DADM` / `DAPX` / `FZ`**。
/// 未评教时全部为 null；已评时 `DA` = 数值字符串，`ZGDA` = 文本。
class WspjResult {
  /// 指标代码（`ZBDM`）—— 与 [WspjQuestion.zbdm] 对应
  final String zbdm;

  /// 客观题答案（`DA`）：分值题为数值字符串，单选题为选项值
  final String da;

  /// 主观题答案（`ZGDA`）
  final String zgda;

  /// 选项文字（`DASM`）—— 结果接口可能带回选项原文，便于回看时直接展示
  final String dasm;

  /// 问卷代码（`WJDM`）
  final String wjdm;

  /// 评教学号（`CPR`）
  final String cpr;

  /// 被评人代码（`BPR`）
  final String bpr;

  /// 教学班 ID（`JXBID`）
  final String jxbid;

  /// 评估内容代码（`PGNR`）
  final String pgnr;

  /// 题型代码（`ZBLXDM`）
  final String zblxdm;

  /// 教学班类型（`JXBLXDM`）
  final String jxblxdm;

  /// 备注（`BZ`，主观题为最少字数）
  final String bz;

  const WspjResult({
    required this.zbdm,
    this.da = '',
    this.zgda = '',
    this.dasm = '',
    this.wjdm = '',
    this.cpr = '',
    this.bpr = '',
    this.jxbid = '',
    this.pgnr = '',
    this.zblxdm = '',
    this.jxblxdm = '',
    this.bz = '',
  });

  factory WspjResult.fromJson(Map<String, dynamic> json) => WspjResult(
        zbdm: _str(json['ZBDM']),
        da: _str(json['DA']),
        zgda: _str(json['ZGDA']),
        dasm: _str(json['DASM']),
        wjdm: _str(json['WJDM']),
        cpr: _str(json['CPR']),
        bpr: _str(json['BPR']),
        jxbid: _str(json['JXBID']),
        pgnr: _str(json['PGNR']),
        zblxdm: _str(json['ZBLXDM']),
        jxblxdm: _str(json['JXBLXDM']),
        bz: _str(json['BZ']),
      );

  /// 该行是否有作答内容
  bool get hasAnswer => da.isNotEmpty || zgda.isNotEmpty;

  /// 取该题的答案值（主观题优先 `ZGDA`）
  String get answerText => zgda.isNotEmpty ? zgda : da;
}

String _str(Object? v) => v?.toString() ?? '';

/// 数值字段格式化：服务端 FZ 可能返回 `10.0`（JSON number），
/// 统一转成 `"10"`，避免 `int.tryParse("10.0")` 失败
String _fmtNum(Object? v) {
  if (v == null) return '';
  if (v is num) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
  final s = v.toString();
  final d = double.tryParse(s);
  if (d != null && d == d.roundToDouble()) return d.toInt().toString();
  return s;
}

int _int(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}
