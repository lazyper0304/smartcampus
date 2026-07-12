import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/local_storage.dart';
import 'xuegong_data_service.dart';

/// 学生信息数据
class StudentInfo {
  final String name;
  final String studentId;
  final String department;
  final String major;
  final String className;
  final String gender;
  final String ethnicity;
  final String politicsStatus;
  final String idNumber;
  final String phone;
  final String photoUrl;
  final List<int> photoBytes;
  final Map<String, Map<String, String>> allData;
  final DateTime fetchedAt;

  StudentInfo({
    required this.name,
    required this.studentId,
    required this.department,
    required this.major,
    required this.className,
    required this.gender,
    required this.ethnicity,
    required this.politicsStatus,
    required this.idNumber,
    required this.phone,
    this.photoUrl = '',
    this.photoBytes = const [],
    this.allData = const {},
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  // 序列化
  Map<String, dynamic> toJson() => {
        'name': name,
        'studentId': studentId,
        'department': department,
        'major': major,
        'className': className,
        'gender': gender,
        'ethnicity': ethnicity,
        'politicsStatus': politicsStatus,
        'idNumber': idNumber,
        'phone': phone,
        'photoUrl': photoUrl,
        'photoBytesBase64': base64Encode(photoBytes),
        'allData': allData,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory StudentInfo.fromJson(Map<String, dynamic> json) => StudentInfo(
        name: json['name']?.toString() ?? '',
        studentId: json['studentId']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        major: json['major']?.toString() ?? '',
        className: json['className']?.toString() ?? '',
        gender: json['gender']?.toString() ?? '',
        ethnicity: json['ethnicity']?.toString() ?? '',
        politicsStatus: json['politicsStatus']?.toString() ?? '',
        idNumber: json['idNumber']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        photoUrl: json['photoUrl']?.toString() ?? '',
        photoBytes: _decodeBytes(json['photoBytesBase64']),
        allData: _decodeAllData(json['allData']),
        fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ?? DateTime.now(),
      );

  static List<int> _decodeBytes(dynamic v) {
    if (v == null || v.toString().isEmpty) return [];
    try {
      return base64Decode(v.toString());
    } catch (_) {
      return [];
    }
  }

  static Map<String, Map<String, String>> _decodeAllData(dynamic v) {
    if (v == null) return {};
    try {
      final raw = v as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  bool get hasPhoto => photoBytes.isNotEmpty;
  bool get isExpired => DateTime.now().difference(fetchedAt).inHours > 1;
}

/// 学生信息管理器 - 后台提取并缓存
class StudentInfoManager {
  static const String _cacheKey = 'student_info_cache';

  /// 从缓存中获取学生信息
  static Future<StudentInfo?> getCached() async {
    final raw = await LocalStorage.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return StudentInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 后台提取并缓存学生信息（失败自动重试 1 次）
  static Future<StudentInfo?> fetchAndCache(SharedHttpClient client) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt == 1) {
          // 首次失败后，等待 2 秒让 CAS session 完全生效
          await Future.delayed(const Duration(seconds: 2));
        }

        final service = XuegongDataService(client);
        final data = await service.extractStructuredData(
          'https://ybxyxsglxt.yibinu.edu.cn/syt/xsinfo/stuinfo.htm',
        );

        // 检查是否提取到了基本信息
        final basic = (data['基本信息'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            {};
        final xueji = (data['学籍信息'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            {};

        // 未获取到姓名说明页面解析失败（session 还未就绪）
        if (basic['姓名']?.isEmpty ?? true) {
          if (attempt == 0) continue; // 重试
          return null;
        }

        final info = StudentInfo(
          name: basic['姓名'] ?? '',
          studentId: basic['学号'] ?? '',
          department: xueji['院系'] ?? '',
          major: xueji['专业'] ?? '',
          className: xueji['班级'] ?? '',
          gender: basic['性别'] ?? '',
          ethnicity: basic['民族'] ?? '',
          politicsStatus: basic['政治面貌'] ?? '',
          idNumber: basic['身份证号'] ?? '',
          phone: basic['联系电话'] ?? '',
          photoUrl: data['_photoUrl']?.toString() ?? '',
          photoBytes: (data['_photoBytes'] as List<int>?) ?? [],
          allData: data.map((k, v) {
            if (v is Map) return MapEntry(k, v.map((k2, v2) => MapEntry(k2.toString(), v2.toString())));
            return MapEntry(k, <String, String>{});
          }),
        );

        await LocalStorage.setString(_cacheKey, jsonEncode(info.toJson()));
        return info;
      } catch (e) {
        debugPrint('StudentInfo fetch attempt $attempt error: $e');
        if (attempt == 0) continue; // 重试
      }
    }
    return null;
  }

  /// 清除缓存
  static Future<void> clearCache() async {
    await LocalStorage.remove(_cacheKey);
  }

  /// 持续重试直到成功获取个人信息
  static Future<StudentInfo> fetchUntilSuccess(SharedHttpClient client) async {
    while (true) {
      final info = await fetchAndCache(client);
      if (info != null) return info;
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
