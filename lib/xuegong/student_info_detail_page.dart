import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'student_info_manager.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

/// 学生信息详情页面
class StudentInfoDetailPage extends StatelessWidget {
  final StudentInfo info;

  const StudentInfoDetailPage({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
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
                      color: _yibinBlue.withValues(alpha: 0.05),
                      border: Border.all(color: _yibinBlue.withValues(alpha: 0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: info.hasPhoto
                          ? Image.memory(Uint8List.fromList(info.photoBytes), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarFallback(info.name))
                          : _avatarFallback(info.name),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(info.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(info.studentId, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
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

  Widget _avatarFallback(String name) {
    return Container(
      color: _yibinBlue.withValues(alpha: 0.08),
      child: Center(
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: _yibinBlue)),
      ),
    );
  }

  List<_SectionData> _sections() {
    final list = <_SectionData>[];
    if (info.allData.containsKey('基本信息')) {
      list.add(_SectionData('基本信息', info.allData['基本信息']!));
    }
    if (info.allData.containsKey('学籍信息')) {
      list.add(_SectionData('学籍信息', info.allData['学籍信息']!));
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
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(color: _yibinBlue, borderRadius: BorderRadius.circular(2)),
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
