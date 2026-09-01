import 'dart:convert';

/// 住宿信息（学工系统 `//syt/sgxt/bed/querylist.htm?xh=&type=ZSXX`）
///
/// 接口返回分页结构 `{ total, data: [ {...} ] }`，取 `data[0]` 即当前学生的
/// 住宿记录：
/// - `sslmc` 楼栋名称（如「临港4舍」）
/// - `ssmc`  宿舍号（如「805」）
/// - `unit`  单元（如「1单元」，可能为 null）
class DormInfo {
  /// 楼栋名称（sslmc）
  final String building;

  /// 宿舍号（ssmc）
  final String room;

  /// 单元（unit，可为空）
  final String unit;

  /// 学号（xh）
  final String studentId;

  /// 姓名（xm）
  final String name;

  const DormInfo({
    this.building = '',
    this.room = '',
    this.unit = '',
    this.studentId = '',
    this.name = '',
  });

  bool get isEmpty => building.isEmpty && room.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// 展示用文案，如「临港4舍 805」
  String get summary {
    if (isEmpty) return '';
    final parts = <String>[if (building.isNotEmpty) building, if (room.isNotEmpty) room];
    return parts.join(' ');
  }

  factory DormInfo.fromJson(Map<String, dynamic> json) => DormInfo(
        building: _str(json['sslmc']),
        room: _str(json['ssmc']),
        unit: _str(json['unit']),
        studentId: _str(json['xh']),
        name: _str(json['xm']),
      );

  /// 解析接口响应体：成功返回 DormInfo（可能为空对象），无数据/解析失败返回 null
  static DormInfo? parseResponse(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      List<dynamic>? rows;
      if (decoded is Map<String, dynamic>) {
        rows = decoded['data'] as List<dynamic>?;
      } else if (decoded is List) {
        rows = decoded;
      }
      if (rows == null || rows.isEmpty) return null;
      final first = rows.first;
      if (first is! Map) return null;
      return DormInfo.fromJson(first as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// 转为个人信息页「住宿信息」区块字段（空字段不展示）
  ///
  /// 只展示楼栋名称与宿舍号（单元不展示）
  Map<String, String> toSection() => {
        if (building.isNotEmpty) '楼栋名称': building,
        if (room.isNotEmpty) '宿舍号': room,
      };

  /// 从缓存区块字段反解（旧缓存无该区块时返回空对象）
  static DormInfo fromSection(Map<String, String>? section) {
    if (section == null || section.isEmpty) return const DormInfo();
    return DormInfo(
      building: section['楼栋名称'] ?? '',
      room: section['宿舍号'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'building': building,
        'room': room,
        'unit': unit,
        'studentId': studentId,
        'name': name,
      };

  factory DormInfo.fromCacheJson(Map<String, dynamic> json) => DormInfo(
        building: json['building']?.toString() ?? '',
        room: json['room']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
        studentId: json['studentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  static String _str(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return (s.isEmpty || s.toLowerCase() == 'null') ? '' : s;
  }
}
