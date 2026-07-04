/// 校历条目信息
class CalendarEntry {
  /// 标题（如"宜宾学院2025-2026学年度校历"）
  final String title;

  /// 详情页 URL（完整）
  final String url;

  /// 发布日期（如"2025-06-06"）
  final String publishDate;

  /// 学年学期描述
  final String academicYear;

  /// 是否上期
  final bool isFirstSemester;

  CalendarEntry({
    required this.title,
    required this.url,
    required this.publishDate,
    required this.academicYear,
    this.isFirstSemester = true,
  });
}

/// 校历详情（包含 PDF 链接）
class CalendarDetail {
  /// 校历条目基本信息
  final CalendarEntry entry;

  /// PDF 文件完整 URL
  final String pdfUrl;

  /// 预览图片 URL（可能为空）
  final String? previewImageUrl;

  CalendarDetail({
    required this.entry,
    required this.pdfUrl,
    this.previewImageUrl,
  });
}

/// 学期时间节点
class SemesterPeriod {
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  SemesterPeriod({
    required this.name,
    required this.startDate,
    required this.endDate,
  });
}
