/// 个人培养方案 - 数据模型

/// 培养方案总览
class PlanSummary {
  final String planName;
  final String studentName;
  final String className;
  final String major;
  final String college;
  final String grade;
  final String duration;
  final String degree;
  final double totalCredits;
  final double earnedCredits;

  const PlanSummary({
    required this.planName,
    required this.studentName,
    required this.className,
    required this.major,
    required this.college,
    required this.grade,
    required this.duration,
    required this.degree,
    required this.totalCredits,
    required this.earnedCredits,
  });

  double get progress => totalCredits > 0
      ? (earnedCredits / totalCredits).clamp(0.0, 1.0)
      : 0.0;

  String get progressText =>
      '$earnedCredits / $totalCredits';

  factory PlanSummary.fromJson(Map<String, dynamic> json) {
    return PlanSummary(
      planName: json['PYFAMC']?.toString() ?? '',
      studentName: json['XM']?.toString() ?? '',
      className: json['BJDM_DISPLAY']?.toString() ?? json['BJDM']?.toString() ?? '',
      major: json['ZYDM_DISPLAY']?.toString() ?? '',
      college: json['YXDM_DISPLAY']?.toString() ?? '',
      grade: json['XZNJ_DISPLAY']?.toString() ?? json['XZNJ']?.toString() ?? '',
      duration: '${json['XZNX']?.toString() ?? ''}年',
      degree: json['XWDM_DISPLAY']?.toString() ?? '',
      totalCredits: double.tryParse(json['ZSYQXF']?.toString() ?? '0') ?? 0,
      earnedCredits: double.tryParse(json['YWCXF']?.toString() ?? '0') ?? 0,
    );
  }
}

/// 培养方案详细（qxpyfacx 响应）
class PlanDetail {
  final String planName;
  final String grade;
  final String major;
  final String college;
  final int duration;
  final String degree;
  final double totalCredits;
  final String startSemester;
  final String semesterType;

  const PlanDetail({
    required this.planName,
    required this.grade,
    required this.major,
    required this.college,
    required this.duration,
    required this.degree,
    required this.totalCredits,
    required this.startSemester,
    required this.semesterType,
  });

  factory PlanDetail.fromJson(Map<String, dynamic> json) {
    return PlanDetail(
      planName: json['PYFAMC']?.toString() ?? '',
      grade: json['NJDM_DISPLAY']?.toString() ?? '',
      major: json['ZYDM_DISPLAY']?.toString() ?? '',
      college: json['DWDM_DISPLAY']?.toString() ?? '',
      duration: int.tryParse(json['XZNX']?.toString() ?? '0') ?? 0,
      degree: json['XWDM_DISPLAY']?.toString() ?? '',
      totalCredits: double.tryParse(json['ZSYQXF']?.toString() ?? '0') ?? 0,
      startSemester: '${json['KSXNDM_DISPLAY']?.toString() ?? ''} ${json['KSXQDM_DISPLAY']?.toString() ?? ''}',
      semesterType: json['XQLXDM_DISPLAY']?.toString() ?? '',
    );
  }
}

/// 课程组（kzcx 中的一条）
class PlanGroup {
  final String name;
  final String categoryDisplay; // 如 "通识教育课程"
  final String groupType; // 平台/课组
  final String requiredType; // 必修/选修
  final double requiredCredits;
  final double totalHours;
  final double totalCredits;
  final int courseCount;
  final bool isSelectable; // SFXGXKZ
  final String parentId; // FKZH
  final String groupId; // KZH

  // 子节点
  final List<PlanGroup> children;
  // 课程列表（kzkccx 中对应此组的课程）
  final List<PlanCourse> courses;

  const PlanGroup({
    required this.name,
    required this.categoryDisplay,
    required this.groupType,
    required this.requiredType,
    required this.requiredCredits,
    required this.totalHours,
    required this.totalCredits,
    required this.courseCount,
    required this.isSelectable,
    required this.parentId,
    required this.groupId,
    this.children = const [],
    this.courses = const [],
  });

  bool get hasChildren => children.isNotEmpty || courses.isNotEmpty;

  bool get isRoot => parentId == '-1';

  factory PlanGroup.fromJson(Map<String, dynamic> json) {
    return PlanGroup(
      name: json['KZM']?.toString() ?? '',
      categoryDisplay: json['KCLBDM_DISPLAY']?.toString() ?? '',
      groupType: json['KZLXDM_DISPLAY']?.toString() ?? '',
      requiredType: json['KCXZDM_DISPLAY']?.toString() ?? '',
      requiredCredits: double.tryParse(json['ZSXDXF']?.toString() ?? '0') ?? 0,
      totalHours: double.tryParse(json['KCZXS']?.toString() ?? '0') ?? 0,
      totalCredits: double.tryParse(json['KCZXF']?.toString() ?? '0') ?? 0,
      courseCount: (double.tryParse(json['KCZMS']?.toString() ?? '0') ?? 0).toInt(),
      isSelectable: json['SFXGXKZ']?.toString() == '1',
      parentId: json['FKZH']?.toString() ?? '',
      groupId: json['KZH']?.toString() ?? '',
    );
  }

  PlanGroup copyWith({
    List<PlanGroup>? children,
    List<PlanCourse>? courses,
  }) {
    return PlanGroup(
      name: name,
      categoryDisplay: categoryDisplay,
      groupType: groupType,
      requiredType: requiredType,
      requiredCredits: requiredCredits,
      totalHours: totalHours,
      totalCredits: totalCredits,
      courseCount: courseCount,
      isSelectable: isSelectable,
      parentId: parentId,
      groupId: groupId,
      children: children ?? this.children,
      courses: courses ?? this.courses,
    );
  }

  double get progress {
    if (requiredCredits <= 0) return courses.isNotEmpty ? 1.0 : 0.0;
    // 用课程总学分估算进度
    final earned = courses.fold<double>(0, (sum, c) => sum + c.credits);
    return (earned / requiredCredits).clamp(0.0, 1.0);
  }
}

/// 课程（kzkccx 中的一条）
class PlanCourse {
  final String name;
  final String code;
  final double credits;
  final double hours;
  final String examType; // 考试/考查
  final String requiredType; // 必修/选修
  final String semester; // 学期显示
  final String department;
  final String groupId; // 所属 KZH

  const PlanCourse({
    required this.name,
    required this.code,
    required this.credits,
    required this.hours,
    required this.examType,
    required this.requiredType,
    required this.semester,
    required this.department,
    required this.groupId,
  });

  factory PlanCourse.fromJson(Map<String, dynamic> json) {
    return PlanCourse(
      name: json['KCM']?.toString() ?? '',
      code: json['KCH']?.toString() ?? '',
      credits: double.tryParse(json['XF']?.toString() ?? '0') ?? 0,
      hours: double.tryParse(json['XS']?.toString() ?? '0') ?? 0,
      examType: json['KSLXDM_DISPLAY']?.toString() ?? '',
      requiredType: json['KCXZDM_DISPLAY']?.toString() ?? '',
      semester: json['XNXQ_DISPLAY']?.toString() ?? '',
      department: json['KKDWDM_DISPLAY']?.toString() ?? '',
      groupId: json['KZH']?.toString() ?? '',
    );
  }
}
