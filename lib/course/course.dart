/// 节次时间对照（从 API jc.do 获取）
const Map<int, List<String>> periodTimeRanges = {
  1: ['08:30', '09:15'],
  2: ['09:20', '10:05'],
  3: ['10:25', '11:10'],
  4: ['11:15', '12:00'],
  5: ['14:30', '15:15'],
  6: ['15:20', '16:05'],
  7: ['16:25', '17:10'],
  8: ['17:15', '18:00'],
  9: ['19:00', '19:45'],
  10: ['19:50', '20:35'],
  11: ['20:45', '21:30'],
  12: ['22:05', '22:50'],
};

String formatPeriodTime(int period, {bool short = false}) {
  final times = periodTimeRanges[period];
  if (times == null) return period.toString();
  if (short) {
    return '${times[0]}';
  }
  return '${times[0]}-${times[1]}';
}

/// 课程模型
class Course {
  /// 课程名称
  final String name;

  /// 授课教师
  final String teacher;

  /// 上课地点（教室）
  final String position;

  /// 星期几（1=周一, 7=周日）
  final int day;

  /// 上课周次列表
  final List<int> weeks;

  /// 上课节次列表
  final List<int> sections;

  /// 显示颜色
  final int colorIndex;

  /// 课程类型标签（如 "实验"、"理论"）
  /// 实验课/普通课的 course 卡片会显示这个小标签
  final String tag;

  /// 附加备注（实验课的项目名、调课的备注等）
  final String remark;

  Course({
    required this.name,
    required this.teacher,
    this.position = '',
    required this.day,
    required this.weeks,
    required this.sections,
    this.colorIndex = 0,
    this.tag = '',
    this.remark = '',
  });

  /// 从 Wisedu API xskcb.do 返回的 JSON row 创建 Course
  factory Course.fromJson(Map<String, dynamic> json, {int colorIndex = 0}) {
    // 周次：解析 SKZC 二进制字符串
    final skzc = json['SKZC']?.toString() ?? '';
    final weeks = <int>[];

    if (skzc.isNotEmpty && RegExp(r'^[01]+$').hasMatch(skzc)) {
      for (int i = 0; i < skzc.length; i++) {
        if (skzc[i] == '1') {
          weeks.add(i + 1);
        }
      }
    } else {
      final zcmc = json['ZCMC']?.toString() ?? '';
      for (final part in zcmc.split(',')) {
        final trimmed = part.trim().replaceAll('周', '');
        if (trimmed.contains('-')) {
          final clean = trimmed.replaceAll(RegExp(r'[^\d\-]'), '');
          final range = clean.split('-');
          if (range.length == 2) {
            final start = int.tryParse(range[0]) ?? 1;
            final end = int.tryParse(range[1]) ?? start;
            for (int w = start; w <= end; w++) {
              weeks.add(w);
            }
          }
        } else if (trimmed.isNotEmpty) {
          final w = int.tryParse(trimmed.replaceAll(RegExp(r'\D'), ''));
          if (w != null) weeks.add(w);
        }
      }
    }

    // 节次
    final startSection = int.tryParse(json['KSJC']?.toString() ?? '0') ?? 0;
    final endSection = int.tryParse(json['JSJC']?.toString() ?? '0') ?? 0;
    final sections = <int>[];
    for (int s = startSection; s <= endSection; s++) {
      sections.add(s);
    }

    return Course(
      name: json['KCM']?.toString() ?? '未知课程',
      teacher: json['SKJS']?.toString() ?? '',
      position: json['JASMC']?.toString() ?? '',
      day: int.tryParse(json['SKXQ']?.toString() ?? '0') ?? 0,
      weeks: weeks,
      sections: sections,
      colorIndex: colorIndex,
    );
  }

  /// 从 scjx2 实验教学 API row 创建 Course（单次实验记录）
  ///
  /// scjx2 返回的是「单次实验」记录（单周次 + 单节次范围），
  /// 所以 weeks 列表里只有一项。
  factory Course.fromExperimentJson(Map<String, dynamic> json,
      {int colorIndex = 0}) {
    final week = int.tryParse(json['week']?.toString() ?? '0') ?? 0;
    final startSection = int.tryParse(json['jc_start']?.toString() ?? '0') ?? 0;
    final endSection = int.tryParse(json['jc_end']?.toString() ?? '0') ?? 0;
    final sections = <int>[];
    for (int s = startSection; s <= endSection; s++) {
      sections.add(s);
    }

    // 课程名优先用 course_name（所属课程），附加 exp_name（实验项目）
    final courseName = json['course_name']?.toString() ?? '实验课程';
    final expName = json['exp_name']?.toString() ?? '';

    return Course(
      name: courseName,
      teacher: json['teacher_name']?.toString() ?? '',
      position: json['room_name']?.toString() ?? '',
      day: int.tryParse(json['week_day']?.toString() ?? '0') ?? 0,
      weeks: week > 0 ? [week] : <int>[],
      sections: sections,
      colorIndex: colorIndex,
      tag: '实验',
      remark: expName,
    );
  }

  /// 节次范围文本
  String get sectionRange {
    if (sections.isEmpty) return '';
    final first = sections.first;
    final last = sections.last;
    final timeStr = formatPeriodTime(first);
    if (first == last) return '$first节 ($timeStr)';
    return '$first-$last节 ($timeStr - ${formatPeriodTime(last, short: true)})';
  }

  /// 节次紧凑显示（合并连续区间，支持多段）：
  /// - 单节：`3节`
  /// - 连续区间：`1-2节`
  /// - 多段（含间隔）：`1-2节,5-6节`
  /// - 混合：`1节,3-5节,8节`
  String get sectionRangesCompact {
    if (sections.isEmpty) return '';
    final sorted = [...sections]..sort();
    final ranges = <String>[];
    int? start;
    int? prev;
    for (final s in sorted) {
      if (start == null) {
        start = s;
        prev = s;
      } else if (s == prev! + 1) {
        prev = s;
      } else {
        ranges.add(start == prev ? '$start' : '$start-$prev');
        start = s;
        prev = s;
      }
    }
    if (start != null) {
      ranges.add(start == prev ? '$start' : '$start-$prev');
    }
    return ranges.map((r) => '$r节').join(',');
  }

  /// 周次显示文本
  String get weeksDisplay {
    if (weeks.isEmpty) return '';
    final ranges = <String>[];
    int? start;
    int? prev;
    for (final w in weeks) {
      if (start == null) {
        start = w;
        prev = w;
      } else if (w == prev! + 1) {
        prev = w;
      } else {
        ranges.add(start == prev ? '$start' : '$start-$prev');
        start = w;
        prev = w;
      }
    }
    if (start != null) {
      ranges.add(start == prev ? '$start' : '$start-$prev');
    }
    return '${ranges.join(',')}周';
  }
}

/// 调课/停课信息
class CourseChange {
  /// 课程名称
  final String courseName;

  /// 授课教师
  final String teacher;

  /// true=停课, false=调课
  final bool isSuspended;

  /// 调课类型名称
  final String changeType;

  /// 原上课周次（二进制位图字符串）
  final String originalWeekBitmap;

  /// 新上课周次（二进制位图字符串）
  final String newWeekBitmap;

  /// 原上课星期
  final int originalDay;

  /// 新上课星期
  final int newDay;

  /// 原开始节次
  final int originalStartPeriod;

  /// 原结束节次
  final int originalEndPeriod;

  /// 新开始节次
  final int newStartPeriod;

  /// 新结束节次
  final int newEndPeriod;

  /// 原教室
  final String originalRoom;

  /// 新教室
  final String newRoom;

  /// 原教室地点代码
  final String originalRoomCode;

  /// 新教室地点代码
  final String newRoomCode;

  /// 原周次显示文本
  final String originalWeekText;

  /// 新周次显示文本
  final String newWeekText;

  CourseChange({
    required this.courseName,
    required this.teacher,
    required this.isSuspended,
    required this.changeType,
    required this.originalWeekBitmap,
    required this.newWeekBitmap,
    required this.originalDay,
    required this.newDay,
    required this.originalStartPeriod,
    required this.originalEndPeriod,
    required this.newStartPeriod,
    required this.newEndPeriod,
    required this.originalRoom,
    required this.newRoom,
    required this.originalRoomCode,
    required this.newRoomCode,
    required this.originalWeekText,
    required this.newWeekText,
  });

  factory CourseChange.fromJson(Map<String, dynamic> json) {
    final tkdm = json['TKLXDM']?.toString() ?? '';
    final isSus = tkdm == '03';

    String bitmapLabel(String? bitmap) {
      if (bitmap == null || bitmap.isEmpty) return '';
      final weeks = <int>[];
      for (int i = 0; i < bitmap.length; i++) {
        if (bitmap[i] == '1') weeks.add(i + 1);
      }
      if (weeks.isEmpty) return '';
      final ranges = <String>[];
      int? s, p;
      for (final w in weeks) {
        if (s == null) { s = w; p = w; }
        else if (w == p! + 1) { p = w; }
        else { ranges.add(s == p ? '$s' : '$s-$p'); s = w; p = w; }
      }
      if (s != null) ranges.add(s == p ? '$s' : '$s-$p');
      return '${ranges.join(',')}周';
    }

    return CourseChange(
      courseName: json['KCM']?.toString() ?? '',
      teacher: json['YSKJS']?.toString() ?? json['XSKJS']?.toString() ?? '',
      isSuspended: isSus,
      changeType: isSus ? '停课' : '调课',
      originalWeekBitmap: json['SKZC']?.toString() ?? '',
      newWeekBitmap: json['XSKZC']?.toString() ?? '',
      originalDay: int.tryParse(json['SKXQ']?.toString() ?? '0') ?? 0,
      newDay: int.tryParse(json['XSKXQ']?.toString() ?? '0') ?? 0,
      originalStartPeriod: int.tryParse(json['KSJC']?.toString() ?? '0') ?? 0,
      originalEndPeriod: int.tryParse(json['JSJC']?.toString() ?? '0') ?? 0,
      newStartPeriod: int.tryParse(json['XKSJC']?.toString() ?? '0') ?? 0,
      newEndPeriod: int.tryParse(json['XJSJC']?.toString() ?? '0') ?? 0,
      originalRoom: json['JASMC']?.toString() ?? '',
      newRoom: json['XJASMC']?.toString() ?? '',
      originalRoomCode: json['JASDM']?.toString() ?? '',
      newRoomCode: json['XJASDM']?.toString() ?? '',
      originalWeekText: bitmapLabel(json['SKZC']?.toString()),
      newWeekText: bitmapLabel(json['XSKZC']?.toString()),
    );
  }
}

/// 未安排课程（仅有课程基本信息，无具体时间地点）
class UnarrangedCourse {
  final String name;
  final String teacher;
  final double credits;
  final int hours;
  final String weekRange;

  UnarrangedCourse({
    required this.name,
    required this.teacher,
    this.credits = 0,
    this.hours = 0,
    this.weekRange = '',
  });

  factory UnarrangedCourse.fromJson(Map<String, dynamic> json) {
    return UnarrangedCourse(
      name: json['KCM']?.toString() ?? '',
      teacher: json['SKJS']?.toString() ?? '',
      credits: double.tryParse(json['XF']?.toString() ?? '0') ?? 0,
      hours: int.tryParse(json['XS']?.toString() ?? '0') ?? 0,
      weekRange: json['SKZC']?.toString() ?? '',
    );
  }
}

/// 学期信息
class SemesterInfo {
  final String wid;
  final String dm; // e.g. "2025-2026-2"
  final String mc; // e.g. "2025-2026学年 第2学期"
  final String xndm; // e.g. "2025-2026"
  final String xqdm; // e.g. "2"
  final bool isActive;

  SemesterInfo({
    required this.wid,
    required this.dm,
    required this.mc,
    required this.xndm,
    required this.xqdm,
    this.isActive = false,
  });

  factory SemesterInfo.fromJson(Map<String, dynamic> json) {
    return SemesterInfo(
      wid: json['WID']?.toString() ?? '',
      dm: json['DM']?.toString() ?? '',
      mc: json['MC']?.toString() ?? '',
      xndm: json['XNDM']?.toString() ?? '',
      xqdm: json['XQDM']?.toString() ?? '',
      isActive: json['SFSY']?.toString() == '1',
    );
  }
}

/// 当前周及学期起始日期信息
class CurrentWeekInfo {
  final int week;
  final DateTime firstMonday;

  CurrentWeekInfo({required this.week, required this.firstMonday});
}
