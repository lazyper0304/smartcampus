/// 空闲教室查询（kxjas）模块数据模型
///
/// 对应 ehall jwapp 应用「空闲教室」：
/// - jxlcx.do：教学楼列表
/// - cxjsqk.do：按 学期+周次+星期(+教学楼) 查询空闲教室
library;

/// 教学楼（jxlcx.do 返回）
class KxjasBuilding {
  /// 教学楼代码（JXLDM，如 "0000000"=A区一平台、"11"=A区一教楼）
  final String jxldm;

  /// 教学楼名称（JXLMC，如 "A区一教楼"）
  final String jxlmc;

  /// 教学楼简称（JXLJC）
  final String jxljc;

  /// 校区代码（XXXQDM，如 "1"=A区、"2"=B区）
  final String xxxqdm;

  /// 校区名称（XXXQDM_DISPLAY，如 "A区"）
  final String xxxqDisplay;

  KxjasBuilding({
    required this.jxldm,
    required this.jxlmc,
    required this.jxljc,
    required this.xxxqdm,
    required this.xxxqDisplay,
  });

  factory KxjasBuilding.fromJson(Map<String, dynamic> json) {
    return KxjasBuilding(
      jxldm: _str(json['JXLDM']),
      jxlmc: _str(json['JXLMC']),
      jxljc: _str(json['JXLJC']),
      xxxqdm: _str(json['XXXQDM']),
      xxxqDisplay: _str(json['XXXQDM_DISPLAY']),
    );
  }

  /// 下拉展示名：如 "A区 · A区一教楼"
  String get displayName {
    if (xxxqDisplay.isNotEmpty && !jxlmc.startsWith(xxxqDisplay)) {
      return '$xxxqDisplay · $jxlmc';
    }
    return jxlmc;
  }
}

/// 空闲教室（cxjsqk.do 返回）
class KxjasClassroom {
  /// 教室代码（JASDM）
  final String jasdm;

  /// 教室名称（JASMC，如 "茶叶评审与检验实验室"）
  final String jasmc;

  /// 教学楼代码（JXLDM）
  final String jxldm;

  /// 教室类型代码（JASLXDM，如 "07"）
  final String jaslxdm;

  /// 教室类型名称（JASLXDM_DISPLAY，如 "实验室"）
  final String jaslxDisplay;

  /// 楼层（LC）
  final String lc;

  /// 上课座位数（SKZWS）
  final int skzws;

  /// 考试座位数（KSZWS）
  final int kszws;

  /// 状态（ZT）
  final String zt;

  /// 被占用节次（JC1~JC20 非空即该节次有排课）
  final List<int> occupiedSections;

  KxjasClassroom({
    required this.jasdm,
    required this.jasmc,
    required this.jxldm,
    required this.jaslxdm,
    required this.jaslxDisplay,
    required this.lc,
    required this.skzws,
    required this.kszws,
    required this.zt,
    required this.occupiedSections,
  });

  factory KxjasClassroom.fromJson(Map<String, dynamic> json) {
    // 解析 JC1~JC20 占用位：字段非 null/非空视为该节次被占用
    final occupied = <int>[];
    for (int i = 1; i <= 20; i++) {
      final v = json['JC$i'];
      if (v != null && v.toString().isNotEmpty) occupied.add(i);
    }
    return KxjasClassroom(
      jasdm: _str(json['JASDM']),
      jasmc: _str(json['JASMC']),
      jxldm: _str(json['JXLDM']),
      jaslxdm: _str(json['JASLXDM']),
      jaslxDisplay: _str(json['JASLXDM_DISPLAY']),
      lc: _str(json['LC']),
      skzws: _int(json['SKZWS']),
      kszws: _int(json['KSZWS']),
      zt: _str(json['ZT']),
      occupiedSections: occupied,
    );
  }

  /// 座位展示：如 "上课 36 座 · 考试 0 座"
  String get seatText {
    final parts = <String>['上课 $skzws 座'];
    if (kszws > 0) parts.add('考试 $kszws 座');
    return parts.join(' · ');
  }
}

/// 分页查询结果
class KxjasPageResult {
  final List<KxjasClassroom> rows;
  final int totalSize;
  final int pageNumber;
  final int pageSize;

  KxjasPageResult({
    required this.rows,
    required this.totalSize,
    required this.pageNumber,
    required this.pageSize,
  });

  bool get hasMore => rows.length < totalSize;
}

/// 大节（节次时段，cxjcqk.do 返回）
///
/// 如 "1-2节 08:30-10:05"、"3-4节 10:25-12:00"……
/// [dj] 即查询空闲教室时 querySetting 的 DJ 过滤值。
class KxjasPeriod {
  /// 大节序号（DJ，1~5）
  final int dj;

  /// 大节名称（DJMC，如 "1-2节"）
  final String djmc;

  /// 起始节次（KSJC）
  final int ksJc;

  /// 结束节次（JSJC）
  final int jsJc;

  /// 开始时间（KSSJ，如 "08:30"）
  final String ksSj;

  /// 结束时间（JSSJ，如 "10:05"）
  final String jsSj;

  KxjasPeriod({
    required this.dj,
    required this.djmc,
    required this.ksJc,
    required this.jsJc,
    required this.ksSj,
    required this.jsSj,
  });

  factory KxjasPeriod.fromJson(Map<String, dynamic> json) {
    return KxjasPeriod(
      dj: _int(json['DJ']),
      djmc: _str(json['DJMC']),
      ksJc: _int(json['KSJC']),
      jsJc: _int(json['JSJC']),
      ksSj: _str(json['KSSJ']),
      jsSj: _str(json['JSSJ']),
    );
  }

  /// 展示名：如 "1-2节 08:30-10:05"
  String get displayName {
    if (ksSj.isNotEmpty && jsSj.isNotEmpty) {
      return '$djmc $ksSj-$jsSj';
    }
    return djmc;
  }
}

String _str(Object? v) => v?.toString() ?? '';

int _int(Object? v) => int.tryParse(v?.toString() ?? '') ?? 0;
