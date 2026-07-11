import 'package:flutter/material.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/smooth_styles.dart';
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
  late final GraduationService _service;
  final _courseCache = <String, List<CourseDetail>>{};

  @override
  void initState() {
    super.initState();
    _service = GraduationService(client: widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchResult(forceRefresh: true);
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

  /// 获取指定课程组的课程明细
  Future<void> _loadCourseDetails(String kzh) async {
    if (_courseCache.containsKey(kzh)) return;
    try {
      final courses = await _service.fetchCategoryCourses(kzh);
      if (!mounted) return;
      setState(() => _courseCache[kzh] = courses);
    } catch (e) {
      debugPrint('加载课程明细失败 [$kzh]: $e');
      if (!mounted) return;
      setState(() => _courseCache[kzh] = []);
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

    return Cue.onMount(
      motion: .smooth(),
      acts: [.fadeIn(), .slideY(from: 0.08)],
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
    return roots.map((r) => _buildTreeRecursive(r, 0)).toList();
  }

  Widget _buildTreeRecursive(GraduationCategory node, int depth) {
    final hasChildren = node.hasChildren;
    final progress = node.progress;
    final isRoot = depth == 0;
    final ctrlId = node.controlId;

    // 构建子节点
    final List<Widget> childrenWidgets;
    if (hasChildren) {
      childrenWidgets = node.children.map(
        (child) => _buildTreeRecursive(child, depth + 1),
      ).toList();
    } else {
      final courses = _courseCache[ctrlId];
      childrenWidgets = [
        Padding(
          padding: const EdgeInsets.all(12),
          child: courses == null
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : courses.isEmpty
                  ? const Center(
                      child: Text('暂无课程明细',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    )
                  : _buildCourseDetailTable(courses),
        ),
      ];
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: _buildCategoryContent(node, isRoot, false),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        (12.0 * depth).toDouble() + 4,
        0,
        4,
        10,
      ),
      child: SmoothExpansionTile(
        initiallyExpanded: false,
        style: smoothStyle(context),
        headerBuilder: (context, expand, controller) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!hasChildren) _loadCourseDetails(ctrlId);
            controller.toggle();
          },
          child: header,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...childrenWidgets,
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent(
    GraduationCategory item,
    bool isRoot,
    bool isExpanded,
  ) {
    final progress = item.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: _yibinBlue,
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
                          _yibinBlue.withValues(alpha: 0.8)),
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
        // 状态标签（仅根节点）
        if (isRoot)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _yibinBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                progress >= 1.0 ? '已完成' : '进行中',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _yibinBlue,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCourseDetailTable(List<CourseDetail> courses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        // 表头
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(
            children: [
              _headerText('课程', 3),
              _headerText('学分', 0.8),
              _headerText('成绩', 0.7),
              _headerText('学期', 1.5),
            ],
          ),
        ),
        ...courses.map((c) => _buildCourseRow(c)),
      ],
    );
  }

  Widget _headerText(String text, double flex) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500])),
    );
  }

  Widget _buildCourseRow(CourseDetail course) {
    final scoreText = course.score?.toString() ?? '-';
    final scoreColor = course.score != null
        ? (course.score! >= 60 ? Colors.green[700] : Colors.red[600])
        : Colors.grey[400];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 30,
            child: Text(course.name,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 8,
            child: Text(course.credit.toStringAsFixed(1),
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 7,
            child: Text(scoreText,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scoreColor)),
          ),
          Expanded(
            flex: 15,
            child: Text(
                course.semesterDisplay.isNotEmpty
                    ? course.semesterDisplay
                    : '未修读',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
          ),
        ],
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
