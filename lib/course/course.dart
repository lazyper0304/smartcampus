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

  Course({
    required this.name,
    required this.teacher,
    this.position = '',
    required this.day,
    required this.weeks,
    required this.sections,
    this.colorIndex = 0,
  });

  /// 从 Wisedu API xskcb.do 返回的 JSON row 创建 Course
  factory Course.fromJson(Map<String, dynamic> json, {int colorIndex = 0}) {
    // 周次：解析 SKZC 二进制字符串，如 "01111111111111111100" → 2-18周
    // 或 "00101010101010101000" → 3,5,7,9,11,13,15,17周（单周）
    // 或 "00000000110000000000" → 9-10周
    final skzc = json['SKZC']?.toString() ?? '';
    final weeks = <int>[];

    if (skzc.isNotEmpty && RegExp(r'^[01]+$').hasMatch(skzc)) {
      for (int i = 0; i < skzc.length; i++) {
        if (skzc[i] == '1') {
          weeks.add(i + 1);
        }
      }
    } else {
      // 回退到解析 ZCMC 文本格式，如 "2-18周"、"3-17周(单)"、"9-10周"
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

  /// 节次范围文本
  String get sectionRange {
    if (sections.isEmpty) return '';
    return '${sections.first}-${sections.last}节';
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
