import 'package:flutter/material.dart';

import 'student_avatar.dart';
import 'student_info_manager.dart';
import '../main.dart';
import '../core/http_client.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


/// 学生信息详情页面
class StudentInfoDetailPage extends StatelessWidget {
  final StudentInfo info;

  /// 登录会话客户端（传给头像组件拉取学籍照片；null 时头像仅显示姓氏占位）
  final SharedHttpClient? client;

  const StudentInfoDetailPage({super.key, required this.info, this.client});

  /// 仅展示这三个区块（其余区块不展示）
  static const List<String> _sectionOrder = ['基本信息', '学籍信息', '住宿信息'];

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('个人信息'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 头像 + 姓名
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: accentColorNotifier.value.withValues(alpha: 0.05),
                      border: Border.all(color: accentColorNotifier.value.withValues(alpha: 0.1)),
                    ),
                    child: StudentAvatar(
                      info: info,
                      client: client,
                      radius: 17,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(info.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(info.studentId, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  // 住宿信息摘要（楼栋 + 宿舍号），有数据显示在学号下方
                  if (info.dorm.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _DormChip(text: info.dorm.summary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 各区块数据
            for (final section in _sections())
              _buildSectionCard(section),
          ],
        ),
      ),
    );
  }

  List<_SectionData> _sections() {
    final list = <_SectionData>[];
    // 只渲染 基本信息 / 学籍信息 / 住宿信息，其余区块一律不展示
    for (final key in _sectionOrder) {
      final fields = info.allData[key];
      if (fields != null && fields.isNotEmpty) {
        list.add(_SectionData(key, fields));
      }
    }
    return list;
  }

  Widget _buildSectionCard(_SectionData section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(color: accentColorNotifier.value, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text(section.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ]),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[100]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: section.fields.entries.map((e) => _fieldRow(e.key, e.value)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _SectionData {
  final String title;
  final Map<String, String> fields;
  _SectionData(this.title, this.fields);
}

/// 住宿信息小标签（如「临港4舍 805」）
class _DormChip extends StatelessWidget {
  final String text;
  const _DormChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accentColorNotifier.value.withValues(alpha: 0.08),
        border: Border.all(color: accentColorNotifier.value.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bed_outlined,
              size: 14, color: accentColorNotifier.value.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColorNotifier.value.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
