import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
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
      final service = GraduationService(client: widget.client);
      final result = await service.fetchResult();
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
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('学业完成情况'),
          centerTitle: true,
          actions: [
            if (_result != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  DataCache().invalidateAll();
                  _load();
                },
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _buildError();
    }
    if (_result == null) {
      return Center(
        child: Text('暂无数据',
            style: TextStyle(fontSize: 14, color: Colors.grey[400])),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        DataCache().invalidateAll();
        return _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _buildSummaryCard(_result!.summary),
          const SizedBox(height: 18),
          ..._buildTree(_result!.rootCategories),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(GraduationSummary summary) {
    final progress = summary.progress;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _yibinBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school_rounded,
                        color: _yibinBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.studentName.isNotEmpty
                              ? summary.studentName
                              : '学生',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (summary.planName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(summary.planName,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                      AlwaysStoppedAnimation(_yibinBlue.withValues(alpha: 0.7)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('总学分', summary.totalCredits.toStringAsFixed(1)),
                  _summaryItem('已修', summary.earnedCredits.toStringAsFixed(1)),
                  _summaryItem(
                      '剩余', summary.remaining.toStringAsFixed(1)),
                  _summaryItem(
                      '完成度', '${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _yibinBlue)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
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

    widgets.add(_buildCategoryCard(
      node,
      indent: depth,
      isRoot: depth == 0,
      isExpanded: isExpanded,
      onTap: hasChildren
          ? () => setState(() {
                if (isExpanded) {
                  _expandedIds.remove(node.controlId);
                } else {
                  _expandedIds.add(node.controlId);
                }
              })
          : null,
    ));

    if (isExpanded && hasChildren) {
      for (final child in node.children) {
        widgets.addAll(_buildTreeRecursive(child, depth + 1));
      }
    }
    return widgets;
  }

  Widget _buildCategoryCard(GraduationCategory item,
      {int indent = 0,
      bool isRoot = false,
      bool isExpanded = false,
      VoidCallback? onTap}) {
    final progress = item.progress;
    final statusColor = progress >= 1.0
        ? Colors.green[700]
        : progress >= 0.7
            ? Colors.orange[700]
            : Colors.red[600];

    return Padding(
      padding: EdgeInsets.only(left: (12.0 * indent).toDouble()),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor!,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.hasChildren)
                                Icon(
                                  isExpanded
                                      ? Icons.expand_more_rounded
                                      : Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                              if (!item.hasChildren)
                                const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: isRoot ? 15 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.categoryType.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(item.categoryType,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                  statusColor.withValues(alpha: 0.8)),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(item.progressText,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(width: 16),
                              Icon(Icons.menu_book_rounded,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text('${item.completedCount}门',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                              const Spacer(),
                              if (item.optionalCourseCount != null)
                                Text(
                                  '可选${item.optionalCourseCount}门',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[400]),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 状态标签
                if (isRoot)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        progress >= 1.0 ? '已完成' : '进行中',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('获取失败',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
              onPressed: () {
                DataCache().invalidateAll();
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _yibinBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
