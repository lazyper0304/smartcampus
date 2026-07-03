class Score {
  /// 学年学期（如 2025-2026-2）
  final String semester;

  /// 课程名称
  final String courseName;

  /// 课程类别（必修/选修）
  final String category;

  /// 修读状况（初修/重修）
  final String status;

  /// 学分
  final double credit;

  /// 总成绩
  final int score;

  /// 学分绩点
  final double gpa;

  const Score({
    required this.semester,
    required this.courseName,
    required this.category,
    required this.status,
    required this.credit,
    required this.score,
    required this.gpa,
  });

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      semester: json['XNXQDM']?.toString() ?? '',
      courseName: json['KCM']?.toString() ?? '未知',
      category: json['KCLBDM_DISPLAY']?.toString() ?? '',
      status: json['CXCKDM_DISPLAY']?.toString() ?? '',
      credit: (json['XF'] as num?)?.toDouble() ?? 0.0,
      score: (json['ZCJ'] as num?)?.toInt() ?? 0,
      gpa: (json['XFJD'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get semesterDisplay {
    // 2025-2026-2 → 2025-2026学年 第2学期
    final parts = semester.split('-');
    if (parts.length == 3) {
      return '${parts[0]}-${parts[1]}学年 第${parts[2]}学期';
    }
    return semester;
  }

  /// 成绩等级
  String get grade {
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 70) return '中等';
    if (score >= 60) return '及格';
    return '不及格';
  }
}

/// 学生基本信息
class StudentInfo {
  final String studentId;
  final String name;
  final String className;
  final String grade;
  final String department;
  final String major;
  final String duration;

  const StudentInfo({
    required this.studentId,
    required this.name,
    required this.className,
    required this.grade,
    required this.department,
    required this.major,
    required this.duration,
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      studentId: json['XSBH']?.toString() ?? '',
      name: json['XM']?.toString() ?? '',
      className: json['BJMC']?.toString() ?? '',
      grade: json['XZNJ']?.toString() ?? '',
      department: json['YXDM_DISPLAY']?.toString() ?? '',
      major: json['NDZYMC']?.toString() ?? '',
      duration: json['XZ']?.toString() ?? '',
    );
  }

  const StudentInfo.empty()
      : studentId = '',
        name = '',
        className = '',
        grade = '',
        department = '',
        major = '',
        duration = '';
}
