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

  /// 任课教师（Bingo 侧提供，ehall 旧接口无此字段）
  final String teacher;

  /// 课程代码
  final String courseCode;

  /// 该课程内的名次（Bingo `/grade` 下发，`rank_total` 为 0 表示未排名）
  final int rank;
  final int rankTotal;

  const Score({
    required this.semester,
    required this.courseName,
    required this.category,
    required this.status,
    required this.credit,
    required this.score,
    required this.gpa,
    this.teacher = '',
    this.courseCode = '',
    this.scoreText = '',
    this.rank = 0,
    this.rankTotal = 0,
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

  /// 从 Bingo `/grade` 返回的条目创建
  ///
  /// 后端已做双字段兼容（教务原字段 `XNXQDM`/`KCM`/`KCDM`/`XF`/`ZCJ`/`JD`
  /// 与标准字段 `semester`/`course_name`/`course_code`/`credit`/`score`/`grade_point`），
  /// 此处优先取标准字段，回退教务原字段。
  ///
  /// ⚠️ `score` 是**字符串**（可能是「优秀」「85」等非数字），
  /// 故 [score] 只取可解析的整数部分，[scoreText] 保留原始展示文本。
  factory Score.fromBingoJson(Map<String, dynamic> json) {
    final rawScore = _pick(json, 'kscj', 'score') ?? '';
    final numScore = (json['score_num'] as num?)?.toDouble() ??
        (json['kscj'] as num?)?.toDouble() ??
        double.tryParse(rawScore.trim()) ??
        0;

    return Score(
      semester: _pick(json, 'xnxq', 'semester') ?? '',
      courseName: _pick(json, 'kcmc', 'course_name') ?? '未知',
      courseCode: _pick(json, 'kcdm', 'course_code') ?? '',
      category: _pick(json, 'course_type', 'kcsxdm') ?? '',
      status: json['exam_type']?.toString() ?? '',
      credit: _pickNum(json, 'xf', 'credit'),
      score: numScore.round(),
      gpa: _pickNum(json, 'jd', 'grade_point'),
      teacher: json['teacher']?.toString() ?? '',
      scoreText: rawScore.trim(),
      rank: _pickInt(json, 'rank'),
      rankTotal: _pickInt(json, 'rank_total'),
    );
  }

  static String? _pick(Map<String, dynamic> j, String primary, String fallback) {
    final a = j[primary];
    if (a != null && '$a'.trim().isNotEmpty) return '$a'.trim();
    final b = j[fallback];
    if (b != null && '$b'.trim().isNotEmpty) return '$b'.trim();
    return null;
  }

  static double _pickNum(Map<String, dynamic> j, String primary, String fallback) {
    if (j[primary] is num) return (j[primary] as num).toDouble();
    final v = double.tryParse('${j[primary]}');
    if (v != null) return v;
    if (j[fallback] is num) return (j[fallback] as num).toDouble();
    return double.tryParse('${j[fallback]}') ?? 0;
  }

  static int _pickInt(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  /// 成绩原始展示文本（可能是「优秀」「85」或空）
  final String scoreText;

  /// 课程名 + 教师（列表副标题）
  String get subtitle {
    if (teacher.isEmpty && courseCode.isEmpty) return semesterDisplay;
    final parts = <String>[];
    if (teacher.isNotEmpty) parts.add(teacher);
    if (courseCode.isNotEmpty) parts.add(courseCode);
    return parts.join(' · ');
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
