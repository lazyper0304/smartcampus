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

  /// 监考教师
  final String invigilator;

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
    required this.invigilator,
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
      invigilator: json['ZJJSXM']?.toString() ?? '',
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
}
