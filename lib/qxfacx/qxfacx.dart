import 'package:html/parser.dart' as html_parser;

/// 全校方案查询（qxfacx / 培养方案查询）模型
///
/// 对应 ehall jwapp「全校方案查询」应用（appShow?appId=4766860087431764），
/// 模块 pyfacxepg。培养方案列表接口 `qxpyfacx.do` 返回的每一行已包含
/// 方案的全部字段（含培养目标/修读要求等富文本），详情无需二次请求。

/// HTML 富文本 → 纯文本（列表/详情展示用）
///
/// 服务端字段（PYMB 培养目标 / XDYQ 修读要求 / FATS / ZGXK / ZYZYSY / ZGKC）
/// 有的是富文本 HTML（\<p\>\<span\>...），有的是普通文本（如含 \n 的实验列表），
/// 统一处理：含 '<' 走 HTML DOM 解析取 text，否则原样 trim。
String qxfacxHtmlToText(String? s) {
  if (s == null || s.isEmpty) return '';
  if (!s.contains('<')) {
    return s.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  try {
    final doc = html_parser.parse(s);
    final text = doc.body?.text ?? '';
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  } catch (_) {
    return s.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }
}

/// 培养方案（qxpyfacx.do 列表行）
class QxFacxPlan {
  /// 唯一 ID（详情/后续课组查询用）
  final String wid;

  /// 方案代码
  final String pyfadm;

  /// 方案名称（如"2026级体育教育主修培养方案"）
  final String name;

  /// 年级代码 + 展示（如 2026 / 2026级）
  final String njd;
  final String njdDisplay;

  /// 院系代码 + 展示（如 XB015 / 体育与大健康学院）
  final String dwdm;
  final String dwdmDisplay;

  /// 专业代码 + 展示（如 040201 / 体育教育）
  final String zydm;
  final String zydmDisplay;

  /// 专业方向代码 + 展示
  final String zyfxd;
  final String zyfxdDisplay;

  /// 修读类型代码 + 展示（如 01 / 主修）
  final String xdlxdm;
  final String xdlxdmDisplay;

  /// 学期类型代码 + 展示（如 2 / 两学期）
  final String xqlxdm;
  final String xqlxdmDisplay;

  /// 学制（年）
  final int xznx;

  /// 学位代码 + 展示（如 404 / 教育学学士学位）
  final String xwdm;
  final String xwdmDisplay;

  /// 开始学年代码 + 展示（如 2026-2027 / 2026-2027学年）
  final String ksxndm;
  final String ksxndmDisplay;

  /// 开始学期代码 + 展示（如 1 / 第1学期）
  final String ksxqdm;
  final String ksxqdmDisplay;

  /// 最少要求学分
  final double zsyqxf;

  /// 培养目标（HTML → 纯文本）
  final String pymbText;

  /// 修读要求（HTML → 纯文本）
  final String xdyqText;

  /// 方案特色（HTML → 纯文本）
  final String fatsText;

  /// 主干学科（HTML → 纯文本）
  final String zgxkText;

  /// 主要专业实验（HTML → 纯文本）
  final String zyzysyText;

  /// 主干课程（HTML → 纯文本）
  final String zgkcText;

  /// 方案状态代码（99=已发布）
  final String faztdm;

  /// 审核意见（如"同意"）
  final String shyj;

  /// 操作人姓名
  final String czrxm;

  /// 操作时间
  final String czsj;

  const QxFacxPlan({
    required this.wid,
    required this.pyfadm,
    required this.name,
    required this.njd,
    required this.njdDisplay,
    required this.dwdm,
    required this.dwdmDisplay,
    required this.zydm,
    required this.zydmDisplay,
    required this.zyfxd,
    required this.zyfxdDisplay,
    required this.xdlxdm,
    required this.xdlxdmDisplay,
    required this.xqlxdm,
    required this.xqlxdmDisplay,
    required this.xznx,
    required this.xwdm,
    required this.xwdmDisplay,
    required this.ksxndm,
    required this.ksxndmDisplay,
    required this.ksxqdm,
    required this.ksxqdmDisplay,
    required this.zsyqxf,
    required this.pymbText,
    required this.xdyqText,
    required this.fatsText,
    required this.zgxkText,
    required this.zyzysyText,
    required this.zgkcText,
    required this.faztdm,
    required this.shyj,
    required this.czrxm,
    required this.czsj,
  });

  factory QxFacxPlan.fromJson(Map<String, dynamic> json) {
    String s(String key) => json[key]?.toString() ?? '';
    int i(String key) => int.tryParse(s(key)) ?? 0;
    double d(String key) => double.tryParse(s(key)) ?? 0;

    return QxFacxPlan(
      wid: s('WID'),
      pyfadm: s('PYFADM'),
      name: s('PYFAMC'),
      njd: s('NJDM'),
      njdDisplay: s('NJDM_DISPLAY'),
      dwdm: s('DWDM'),
      dwdmDisplay: s('DWDM_DISPLAY'),
      zydm: s('ZYDM'),
      zydmDisplay: s('ZYDM_DISPLAY'),
      zyfxd: s('ZYFXDM'),
      zyfxdDisplay: s('ZYFXDM_DISPLAY'),
      xdlxdm: s('XDLXDM'),
      xdlxdmDisplay: s('XDLXDM_DISPLAY'),
      xqlxdm: s('XQLXDM'),
      xqlxdmDisplay: s('XQLXDM_DISPLAY'),
      xznx: i('XZNX'),
      xwdm: s('XWDM'),
      xwdmDisplay: s('XWDM_DISPLAY'),
      ksxndm: s('KSXNDM'),
      ksxndmDisplay: s('KSXNDM_DISPLAY'),
      ksxqdm: s('KSXQDM'),
      ksxqdmDisplay: s('KSXQDM_DISPLAY'),
      zsyqxf: d('ZSYQXF'),
      pymbText: qxfacxHtmlToText(s('PYMB')),
      xdyqText: qxfacxHtmlToText(s('XDYQ')),
      fatsText: qxfacxHtmlToText(s('FATS')),
      zgxkText: qxfacxHtmlToText(s('ZGXK')),
      zyzysyText: qxfacxHtmlToText(s('ZYZYSY')),
      zgkcText: qxfacxHtmlToText(s('ZGKC')),
      faztdm: s('FAZTDM'),
      shyj: s('SHYJ'),
      czrxm: s('CZRXM'),
      czsj: s('CZSJ'),
    );
  }
}

/// 培养方案分页结果（qxpyfacx.do）
class QxFacxPageResult {
  final List<QxFacxPlan> rows;
  final int totalSize;
  final int pageNumber;
  final int pageSize;

  const QxFacxPageResult({
    required this.rows,
    required this.totalSize,
    required this.pageNumber,
    required this.pageSize,
  });
}

/// 课程组（kzcx.do，培养方案下的课程组/平台）
///
/// 层级：`KZLXDM=02` 平台（顶级，FKZH=-1）→ `KZLXDM=01` 课组（FKZH=父平台 KZH）
/// → 可能再有孙级（FKZH=父课组 KZH）。用 FKZH 匹配 KZH 可构建树。
class QxFacxKz {
  final String wid;

  /// 所属方案代码
  final String pyfadm;

  /// 课组号（32 位 hex，子组/课程用它关联）
  final String kzh;

  /// 课组名（如"通识教育必修课程"）
  final String kzm;

  /// 课组类型代码 + 展示（01=课组 / 02=平台）
  final String kzlxdm;
  final String kzlxdmDisplay;

  /// 是否校公选课组（0/1）+ 展示
  final String sfxgxkz;
  final String sfxgxkzDisplay;

  /// 校公选课类别（展示）
  final String xgxklbdmDisplay;

  /// 课程类别（展示，如"通识教育课程"/"创新创业课程"）
  final String kclbdmDisplay;

  /// 课程性质（展示，必修/选修）
  final String kcxzdmDisplay;

  /// 课组学分（该组全部课程学分合计）
  final double kcxF;

  /// 课组学时（该组全部课程学时合计）
  final double kcxS;

  /// 最少修读学分
  final double zsxdxf;

  /// 最少修读门数
  final double zsxdms;

  /// 最少完成课组数
  final double zswckzs;

  /// 课组门数
  final double kczms;

  /// 修读要求（纯文本，可能含 \n）
  final String xdyq;

  /// 父课组号（"-1" = 顶级平台）
  final String fkzh;

  /// 公共课组号
  final String ggkzh;

  final String bz;

  const QxFacxKz({
    required this.wid,
    required this.pyfadm,
    required this.kzh,
    required this.kzm,
    required this.kzlxdm,
    required this.kzlxdmDisplay,
    required this.sfxgxkz,
    required this.sfxgxkzDisplay,
    required this.xgxklbdmDisplay,
    required this.kclbdmDisplay,
    required this.kcxzdmDisplay,
    required this.kcxF,
    required this.kcxS,
    required this.zsxdxf,
    required this.zsxdms,
    required this.zswckzs,
    required this.kczms,
    required this.xdyq,
    required this.fkzh,
    required this.ggkzh,
    required this.bz,
  });

  /// 顶级平台（FKZH=-1）
  bool get isTop => fkzh == '-1';

  /// 课组类型中文：平台 / 课组
  String get typeLabel =>
      kzlxdmDisplay.isNotEmpty ? kzlxdmDisplay : (isTop ? '平台' : '课组');

  factory QxFacxKz.fromJson(Map<String, dynamic> json) {
    String s(String key) => json[key]?.toString() ?? '';
    double d(String key) => double.tryParse(s(key)) ?? 0;

    return QxFacxKz(
      wid: s('WID'),
      pyfadm: s('PYFADM'),
      kzh: s('KZH'),
      kzm: s('KZM'),
      kzlxdm: s('KZLXDM'),
      kzlxdmDisplay: s('KZLXDM_DISPLAY'),
      sfxgxkz: s('SFXGXKZ'),
      sfxgxkzDisplay: s('SFXGXKZ_DISPLAY'),
      xgxklbdmDisplay: s('XGXKLBDM_DISPLAY'),
      kclbdmDisplay: s('KCLBDM_DISPLAY'),
      kcxzdmDisplay: s('KCXZDM_DISPLAY'),
      kcxF: d('KCZXF'),
      kcxS: d('KCZXS'),
      zsxdxf: d('ZSXDXF'),
      zsxdms: d('ZSXDMS'),
      zswckzs: d('ZSWCKZS'),
      kczms: d('KCZMS'),
      xdyq: s('XDYQ'),
      fkzh: s('FKZH'),
      ggkzh: s('GGKZH'),
      bz: s('BZ'),
    );
  }
}

/// 课组课程（kzkccx.do，培养方案下的全部课程）
class QxFacxKzCourse {
  final String wid;
  final String pyfadm;

  /// 课程号
  final String kch;

  /// 课程名
  final String kcm;

  /// 学分（String，如 "2.0"）
  final String xf;

  /// 学时（String，如 "32.0"）
  final String xs;

  /// 课程性质代码 + 展示（1=必修 / 2=选修）
  final String kcxzdm;
  final String kcxzdmDisplay;

  /// 考试类型代码 + 展示（1=考试 / 2=考查）
  final String kslxdm;
  final String kslxdmDisplay;

  /// 是否主干课程（0/1）+ 展示
  final String sfzgkc;
  final String sfzgkcDisplay;

  /// 所属课组号（关联 kzcx.do 的 KZH）
  final String kzh;

  /// 开课学年学期（如 "2026-2027-1"）+ 展示
  final String xnxq;
  final String xnxqDisplay;

  /// 学期序号（1~7）
  final String xdxq;

  final String bz;

  const QxFacxKzCourse({
    required this.wid,
    required this.pyfadm,
    required this.kch,
    required this.kcm,
    required this.xf,
    required this.xs,
    required this.kcxzdm,
    required this.kcxzdmDisplay,
    required this.kslxdm,
    required this.kslxdmDisplay,
    required this.sfzgkc,
    required this.sfzgkcDisplay,
    required this.kzh,
    required this.xnxq,
    required this.xnxqDisplay,
    required this.xdxq,
    required this.bz,
  });

  factory QxFacxKzCourse.fromJson(Map<String, dynamic> json) {
    String s(String key) => json[key]?.toString() ?? '';
    return QxFacxKzCourse(
      wid: s('WID'),
      pyfadm: s('PYFADM'),
      kch: s('KCH'),
      kcm: s('KCM'),
      xf: s('XF'),
      xs: s('XS'),
      kcxzdm: s('KCXZDM'),
      kcxzdmDisplay: s('KCXZDM_DISPLAY'),
      kslxdm: s('KSLXDM'),
      kslxdmDisplay: s('KSLXDM_DISPLAY'),
      sfzgkc: s('SFZGKC'),
      sfzgkcDisplay: s('SFZGKC_DISPLAY'),
      kzh: s('KZH'),
      xnxq: s('XNXQ'),
      xnxqDisplay: s('XNXQ_DISPLAY'),
      xdxq: s('XDXQ'),
      bz: s('BZ'),
    );
  }
}
