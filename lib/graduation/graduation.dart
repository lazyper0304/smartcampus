/// 学业完成情况 - 课程组完成进度（支持层级：FKZH → KZH）
class GraduationCategory {
  /// 课程组名称
  final String name;

  /// 课程性质显示（必修/选修/空）
  final String categoryType;

  /// 最低修读学分
  final double requiredCredits;

  /// 已完成学分
  final double completedCredits;

  /// 要求学分
  final double expectCredits;

  /// 已完成门数
  final int completedCount;

  /// 是否通过
  final bool isPassed;

  /// 备注
  final String remark;

  /// 可选课程数
  final int? optionalCourseCount;

  /// ── 层级字段 ──
  /// 自身 KZH（控制组号），子项的 FKZH 指向此值
  final String controlId;

  /// 父级 FKZH（父控制组号），"-1" 表示根节点
  final String parentId;

  /// 01=具体课程组(叶子)，02=课程分类(可含子项)
  final String categoryLevel;

  /// 子课程组（从 flat list 按 FKZH→KZH 构建）
  final List<GraduationCategory> children;

  const GraduationCategory({
    required this.name,
    required this.categoryType,
    required this.requiredCredits,
    required this.completedCredits,
    required this.expectCredits,
    required this.completedCount,
    required this.isPassed,
    this.remark = '',
    this.optionalCourseCount,
    required this.controlId,
    required this.parentId,
    required this.categoryLevel,
    this.children = const [],
  });

  factory GraduationCategory.fromJson(Map<String, dynamic> json) {
    return GraduationCategory(
      name: json['KZM']?.toString() ?? '',
      categoryType: json['KCXZDM_DISPLAY']?.toString() ?? '',
      requiredCredits: double.tryParse(json['ZDXDZF']?.toString() ?? '0') ?? 0,
      completedCredits: double.tryParse(json['WCXF']?.toString() ?? '0') ?? 0,
      expectCredits: double.tryParse(json['YQXF']?.toString() ?? '0') ?? 0,
      completedCount: int.tryParse(json['WCMS']?.toString() ?? '0') ?? 0,
      isPassed: json['SFTG']?.toString() == '1',
      remark: json['BZ']?.toString() ?? '',
      optionalCourseCount: int.tryParse(json['KXKCS']?.toString() ?? ''),
      controlId: json['KZH']?.toString() ?? '',
      parentId: json['FKZH']?.toString() ?? '',
      categoryLevel: json['KZLXDM']?.toString() ?? '',
    );
  }

  /// 是否根节点（父级为 "-1"）
  bool get isRoot => parentId == '-1';

  /// 是否有子节点
  bool get hasChildren => children.isNotEmpty;

  /// 完成进度百分比
  double get progress {
    final target = requiredCredits > 0 ? requiredCredits : expectCredits;
    if (target <= 0) return 1.0;
    return (completedCredits / target).clamp(0.0, 1.0);
  }

  /// 进度文本
  String get progressText {
    final target = requiredCredits > 0 ? requiredCredits : expectCredits;
    return '${completedCredits.toStringAsFixed(1)}/$target';
  }
}

/// 学业概况
class GraduationSummary {
  final String planName;
  final double totalCredits;
  final double earnedCredits;
  final String studentName;

  const GraduationSummary({
    required this.planName,
    required this.totalCredits,
    required this.earnedCredits,
    required this.studentName,
  });

  double get progress {
    if (totalCredits <= 0) return 0;
    return (earnedCredits / totalCredits).clamp(0.0, 1.0);
  }

  double get remaining =>
      (totalCredits - earnedCredits).clamp(0, double.infinity);
}

/// 学业完成结果
class GraduationResult {
  final GraduationSummary summary;
  final List<GraduationCategory> rootCategories;

  const GraduationResult({
    required this.summary,
    required this.rootCategories,
  });
}
