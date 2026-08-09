/// 考试安排
class Exam {
  /// 课程名称
  final String courseName;

  /// 考试时间描述（如 "2026-07-10 14:00-16:00(星期五)"）
  final String timeDesc;

  /// 考试日期
  final String date;

  /// 教室
  final String classroom;

  /// 座位号
  final String seatNo;

  /// 任课老师（ZJJSXM，2026-08-09 确认：接口该字段是任课老师，非监考老师）
  final String teacher;

  /// 考试名称
  final String examName;

  /// 学分
  final double credit;

  const Exam({
    required this.courseName,
    required this.timeDesc,
    required this.date,
    required this.classroom,
    required this.seatNo,
    required this.teacher,
    required this.examName,
    required this.credit,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      courseName: json['KCM']?.toString() ?? '',
      timeDesc: json['KSSJMS']?.toString() ?? '',
      date: json['KSRQ']?.toString() ?? '',
      classroom: json['JASMC']?.toString() ?? '',
      seatNo: json['ZWH']?.toString() ?? '',
      teacher: json['ZJJSXM']?.toString() ?? '',
      examName: json['KSMC']?.toString() ?? '',
      credit: (json['XF'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 星期几
  String get weekday {
    final m = RegExp(r'\((.+?)\)').firstMatch(timeDesc);
    return m?.group(1) ?? '';
  }

  /// 时间段（如 "14:00-16:00"）
  String get timeRange {
    final m = RegExp(r'(\d{2}:\d{2}-\d{2}:\d{2})').firstMatch(timeDesc);
    return m?.group(1) ?? '';
  }

  /// 考试结束时间（date 的日期 + timeRange 的结束时刻）。
  /// timeDesc 无完整时间（无法解析）时返回 null。
  DateTime? get endTime {
    final dateStr = date.length >= 10 ? date.substring(0, 10) : date;
    final m = RegExp(r'(\d{2}:\d{2})-(\d{2}:\d{2})').firstMatch(timeDesc);
    if (m == null) return null;
    return DateTime.tryParse('$dateStr ${m.group(2)}');
  }

  /// 是否已完成（结束时间已过；无法解析结束时间时保守返回 false，不误标）
  bool get isFinished {
    final t = endTime;
    if (t == null) return false;
    return DateTime.now().isAfter(t);
  }
}

/// 未安排考试（本学期已选但尚未排考场的课程）
class UnarrangedExam {
  /// 课程名称（KCM）
  final String courseName;

  /// 课程号（KCH）
  final String courseCode;

  /// 教师（ZJJSXM）
  final String teacher;

  const UnarrangedExam({
    required this.courseName,
    required this.courseCode,
    required this.teacher,
  });

  factory UnarrangedExam.fromJson(Map<String, dynamic> json) {
    return UnarrangedExam(
      courseName: json['KCM']?.toString() ?? '',
      courseCode: json['KCH']?.toString() ?? '',
      teacher: json['ZJJSXM']?.toString() ?? '',
    );
  }
}

/// 学年学期（考试模块 xnxqcx.do 返回）
class ExamSemester {
  /// 学期代码（DM，如 "2025-2026-2"）
  final String dm;

  /// 学期名称（MC，如 "2025-2026学年 第2学期"）
  final String mc;

  /// 是否当前使用学期（SFSY=1）
  final bool isActive;

  const ExamSemester({
    required this.dm,
    required this.mc,
    this.isActive = false,
  });

  factory ExamSemester.fromJson(Map<String, dynamic> json) {
    return ExamSemester(
      dm: json['DM']?.toString() ?? '',
      mc: json['MC']?.toString() ?? '',
      isActive: json['SFSY']?.toString() == '1',
    );
  }
}
