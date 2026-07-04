import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import 'graduation.dart';
import 'graduation_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class GraduationPage extends StatefulWidget {
  final SharedHttpClient client;
  const GraduationPage({super.key, required this.client});
  @override
  State<GraduationPage> createState() => _GraduationPageState();
}

class _GraduationPageState extends State<GraduationPage> {
  GraduationResult? _result;
  bool _isLoading = true;
  String? _error;
  final Set<String> _expandedIds = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final service = GraduationService(client: widget.client);
      final result = await service.fetchResult();
      if (!mounted) return;
      setState(() { _result = result; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('学业完成情况'),
          centerTitle: true,
          actions: [if (_result != null) IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('获取失败', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('重试')),
        ]),
      ));
    }
    if (_result == null) return const Center(child: Text('暂无数据'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSummaryCard(_result!.summary),
          const SizedBox(height: 8),
          ..._buildTree(_result!.rootCategories),
        ],
      ),
    );
  }

  List<Widget> _buildTree(List<GraduationCategory> roots) {
    final widgets = <Widget>[];
    for (final root in roots) {
      widgets.addAll(_buildTreeRecursive(root, 0));
    }
    return widgets;
  }

  List<Widget> _buildTreeRecursive(GraduationCategory node, int depth) {
    final widgets = <Widget>[];
    final isExpanded = _expandedIds.contains(node.controlId);
    final hasChildren = node.hasChildren;

    widgets.add(_buildCard(node, indent: depth, isRoot: depth == 0, isExpanded: isExpanded,
      onTap: hasChildren ? () => setState(() {
        if (isExpanded) { _expandedIds.remove(node.controlId); } else { _expandedIds.add(node.controlId); }
      }) : null,
    ));

    if (isExpanded && hasChildren) {
      for (final child in node.children) {
        widgets.addAll(_buildTreeRecursive(child, depth + 1));
      }
    }

    return widgets;
  }

  Widget _buildCard(GraduationCategory item, {int indent = 0, bool isRoot = false, bool isExpanded = false, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final progress = item.progress;
    final color = progress >= 1.0 ? Colors.green : progress >= 0.7 ? Colors.orange : Colors.red;

    return Padding(
      padding: EdgeInsets.only(left: 12.0 * indent),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (item.hasChildren)
                  Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 20, color: Colors.grey[600]),
                if (!item.hasChildren) const SizedBox(width: 20),
                if (indent == 0) Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: Icon(Icons.folder, size: 18, color: color),
                ),
                Expanded(child: Text(
                  item.name,
                  style: TextStyle(fontSize: isRoot ? 16 : 14, fontWeight: FontWeight.bold),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(progress >= 1.0 ? '已完成' : '进行中', style: TextStyle(fontSize: 11, color: color)),
                ),
              ]),
              if (item.categoryType.isNotEmpty) const SizedBox(height: 4),
              if (item.categoryType.isNotEmpty)
                Text(item.categoryType, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _chip(Icons.check_circle_outline, item.progressText, theme),
                const SizedBox(width: 12),
                _chip(Icons.bookmark_outline, '${item.completedCount}门', theme),
                const Spacer(),
                if (item.optionalCourseCount != null)
                  Text('可选${item.optionalCourseCount}门', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(GraduationSummary summary) {
    final theme = Theme.of(context);
    final progress = summary.progress;
    final color = progress >= 1.0 ? Colors.green : progress >= 0.7 ? Colors.orange : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.school, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(summary.studentName.isNotEmpty ? summary.studentName : '学生',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(summary.planName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _summaryItem('总学分', summary.totalCredits.toStringAsFixed(1), color),
            _summaryItem('已修', summary.earnedCredits.toStringAsFixed(1), color),
            _summaryItem('剩余', summary.remaining.toStringAsFixed(1), summary.remaining > 0 ? Colors.orange : Colors.green),
            _summaryItem('完成度', '${(progress * 100).toStringAsFixed(0)}%', color),
          ]),
        ]),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _chip(IconData icon, String text, ThemeData theme) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.grey[600]),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ]);
  }
}
