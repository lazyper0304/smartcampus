import 'package:flutter/material.dart';

import '../core/http_client.dart';
import 'plan.dart';
import 'plan_service.dart';

/// 个人培养方案查询页面
class PlanPage extends StatefulWidget {
  final SharedHttpClient client;

  const PlanPage({super.key, required this.client});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  PlanResult? _result;
  bool _isLoading = true;
  String? _error;
  final Set<String> _expandedGroups = {};
  final Set<String> _expandedCourses = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = PlanService(client: widget.client);
      final result = await service.fetchPlan();
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人培养方案'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_result == null) {
      return const Center(child: Text('暂无数据'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSummaryCard(),
          if (_result!.detail != null) ...[
            const SizedBox(height: 8),
            _buildDetailCard(_result!.detail!),
          ],
          const SizedBox(height: 12),
          const Text('课程组结构',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._buildTree(_result!.groups),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final s = _result!.summary;
    final progress = s.progress;
    final color = progress >= 1.0
        ? Colors.green
        : progress >= 0.6
            ? Colors.orange
            : Colors.red;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.planName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('姓名', s.studentName),
                      const SizedBox(height: 6),
                      _infoRow('年级', s.grade),
                      const SizedBox(height: 6),
                      _infoRow('专业', s.major),
                      const SizedBox(height: 6),
                      _infoRow('学院', s.college),
                      const SizedBox(height: 6),
                      _infoRow(
                          '已修', '${s.earnedCredits.toStringAsFixed(1)} 学分'),
                      const SizedBox(height: 6),
                      _infoRow(
                          '总需', '${s.totalCredits.toStringAsFixed(1)} 学分'),
                      const SizedBox(height: 6),
                      _infoRow(
                          '剩余',
                          '${(s.totalCredits - s.earnedCredits).toStringAsFixed(1)} 学分'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(PlanDetail d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('开始学期：${d.startSemester}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('学制：${d.duration}年 | 学期类型：${d.semesterType}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('学位：${d.degree}',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  List<Widget> _buildTree(List<PlanGroup> roots) {
    final widgets = <Widget>[];
    for (final root in roots) {
      widgets.addAll(_buildNode(root, 0));
    }
    return widgets;
  }

  List<Widget> _buildNode(PlanGroup node, int depth) {
    final widgets = <Widget>[];
    final isExpanded = _expandedGroups.contains(node.groupId);
    final color = _getColor(depth);

    widgets.add(_buildGroupCard(node, depth, isExpanded, color));

    if (isExpanded) {
      for (final child in node.children) {
        widgets.addAll(_buildNode(child, depth + 1));
      }
      if (node.courses.isNotEmpty) {
        final showCourses = _expandedCourses.contains(node.groupId);
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16.0 * (depth + 1)),
            child: Card(
              margin: const EdgeInsets.only(bottom: 4, left: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (showCourses) {
                      _expandedCourses.remove(node.groupId);
                    } else {
                      _expandedCourses.add(node.groupId);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        showCourses
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '课程列表（${node.courses.length}门）',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (showCourses) {
          for (final course in node.courses) {
            widgets.add(_buildCourseCard(course, depth + 1));
          }
        }
      }
    }

    return widgets;
  }

  Widget _buildGroupCard(
      PlanGroup node, int depth, bool isExpanded, Color color) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * depth),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: node.hasChildren
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedGroups.remove(node.groupId);
                    } else {
                      _expandedGroups.add(node.groupId);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (node.hasChildren)
                      Icon(
                        isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    if (!node.hasChildren) const SizedBox(width: 20),
                    Icon(
                      node.isRoot
                          ? Icons.folder
                          : Icons.folder_open,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        node.name,
                        style: TextStyle(
                          fontSize: depth == 0 ? 15 : 14,
                          fontWeight:
                              depth == 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                    _statusBadge(node.groupType, Colors.blue),
                    if (node.requiredType.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _statusBadge(
                          node.requiredType,
                          node.requiredType == '必修'
                              ? Colors.red
                              : Colors.orange),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (node.requiredCredits > 0)
                      _miniChip('需${node.requiredCredits}学分', Colors.grey),
                    if (node.totalCredits > 0) ...[
                      const SizedBox(width: 8),
                      _miniChip('共${node.totalCredits}学分', Colors.blue),
                    ],
                    if (node.courseCount > 0) ...[
                      const SizedBox(width: 8),
                      _miniChip('${node.courseCount}门', Colors.teal),
                    ],
                    if (node.totalHours > 0) ...[
                      const SizedBox(width: 8),
                      _miniChip('${node.totalHours.toInt()}学时',
                          Colors.purple),
                    ],
                    if (node.isSelectable) ...[
                      const SizedBox(width: 8),
                      _miniChip('选修', Colors.orange),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(PlanCourse course, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * (depth + 1) + 12, right: 4),
      child: Card(
        margin: const EdgeInsets.only(bottom: 3),
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: course.examType == '考试'
                      ? Colors.red
                      : Colors.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.credits}学分 ${course.hours.toInt()}学时',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.semester,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _miniChip(
                      course.examType,
                      course.examType == '考试'
                          ? Colors.red
                          : Colors.blue),
                  const SizedBox(height: 4),
                  if (course.requiredType.isNotEmpty)
                    _miniChip(
                        course.requiredType,
                        course.requiredType == '必修'
                            ? Colors.red
                            : Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Color _getColor(int depth) {
    const colors = [
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
    ];
    return colors[depth % colors.length];
  }
}
