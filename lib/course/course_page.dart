import 'package:flutter/material.dart';

import '../core/http_client.dart';
import 'course.dart';
import 'course_service.dart';

class CourseTablePage extends StatefulWidget {
  final SharedHttpClient client;
  final String? userId;

  const CourseTablePage({super.key, required this.client, this.userId});

  @override
  State<CourseTablePage> createState() => _CourseTablePageState();
}

class _CourseTablePageState extends State<CourseTablePage> {
  List<Course>? _courses;
  bool _isLoading = true;
  String? _error;
  int _currentWeek = 1;

  static const _dayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];
  static const _periodLabels = [
    '',
    '1\n8:00', '2\n8:50',
    '3\n9:55', '4\n10:45',
    '5\n11:50', '6\n12:40',
    '7\n14:30', '8\n15:20',
    '9\n16:25', '10\n17:15',
    '11\n19:00', '12\n19:50',
  ];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = CourseService(
        client: widget.client,
        userId: widget.userId,
      );
      final courses = await service.fetchCourses();

      if (!mounted) return;
      setState(() {
        _courses = courses;
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
        title: const Text('课程表'),
        centerTitle: true,
        actions: [
          if (_courses != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('第 $_currentWeek 周',
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
          if (_courses != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCourses,
            ),
        ],
        bottom: _courses != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: _buildWeekSlider(),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildWeekSlider() {
    if (_courses == null || _courses!.isEmpty) return const SizedBox.shrink();

    int maxWeek = 1;
    for (final c in _courses!) {
      for (final w in c.weeks) {
        if (w > maxWeek) maxWeek = w;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('周次:', style: TextStyle(fontSize: 12)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: _currentWeek.toDouble(),
                min: 1,
                max: maxWeek.toDouble(),
                divisions: maxWeek - 1,
                label: '第$_currentWeek周',
                onChanged: (v) => setState(() => _currentWeek = v.round()),
              ),
            ),
          ),
          Text('/$maxWeek', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('获取课程表失败',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCourses,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses == null || _courses!.isEmpty) {
      return const Center(
        child: Text('暂无课程数据', style: TextStyle(fontSize: 16)),
      );
    }

    return _buildTimetable();
  }

  Widget _buildTimetable() {
    // 计算最大节次
    int maxSection = 12;
    for (final c in _courses!) {
      for (final s in c.sections) {
        if (s > maxSection) maxSection = s;
      }
    }

    // 当前周显示的课程
    final weekCourses = _courses!
        .where((c) => c.weeks.contains(_currentWeek))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = (constraints.maxWidth - 44) / 7;
        final rowHeight = 60.0;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 44 + dayWidth * 7,
              child: Column(
                children: [
                  // 表头：星期
                  Row(
                    children: [
                      const SizedBox(
                        width: 44,
                        height: 40,
                        child: Center(
                            child: Text('节次',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11))),
                      ),
                      ...List.generate(7, (i) {
                        final isWeekend = i >= 5;
                        return SizedBox(
                          width: dayWidth,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isWeekend
                                  ? Colors.grey.shade100
                                  : Colors.blue.shade50,
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                            ),
                            child: Center(
                              child: Text(
                                '周${_dayLabels[i + 1]}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isWeekend ? Colors.grey : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  // 行：每节课
                  ...List.generate(maxSection, (rowIdx) {
                    final period = rowIdx + 1;
                    final isOdd = period.isOdd;

                    return SizedBox(
                      height: rowHeight,
                      child: Row(
                        children: [
                          // 左侧节次标签
                          SizedBox(
                            width: 44,
                            height: rowHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isOdd ? Colors.grey.shade50 : Colors.white,
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 0.5),
                              ),
                              child: Center(
                                child: Text(
                                  _periodLabels[period],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 10, height: 1.2),
                                ),
                              ),
                            ),
                          ),
                          // 每天该节次的课程
                          ...List.generate(7, (dayIdx) {
                            final day = dayIdx + 1;
                            final coursesInCell = weekCourses
                                .where((c) =>
                                    c.day == day &&
                                    c.sections.contains(period))
                                .toList();

                            return SizedBox(
                              width: dayWidth,
                              height: rowHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 0.5),
                                ),
                                child: coursesInCell.isEmpty
                                    ? null
                                    : _buildCourseCard(
                                        coursesInCell.first, dayWidth),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(Course course, double width) {
    final color = Color(courseColors[course.colorIndex % courseColors.length]);

    return Container(
      width: width,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            course.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (course.position.isNotEmpty)
            Text(
              course.position,
              style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
