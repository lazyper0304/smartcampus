/// 学期课表公共视图（个人课表与全校班级课表共用）。
///
/// 样式与个人课表一致：按星期分组展示课程卡片，
/// 同一天内「课程名+教师+类型」相同的多个时间片合并为一张卡片。
/// 原实现在 course_page.dart 内部，已抽取到本文件消除重复。
library;

import 'package:flutter/material.dart';

import '../core/theme_utils.dart';
import '../main.dart';
import 'course.dart';
import 'course_config.dart';
import 'course_grid.dart';

/// 同一天内，将「课程名+教师+类型」相同的多个时间片合并为一张卡片。
///
/// 合并后：
/// - sections: 所有节次并集（去重 + 排序）
/// - weeks: 所有周次并集（去重 + 排序）
/// - position: 全部去重后用「、」拼接
/// - teacher/remark: 取第一个
/// - tag/colorIndex: 不变（理论课和实验课 tag 不同会天然分开）
List<Course> mergeSameCourses(List<Course> courses) {
  final groups = <String, List<Course>>{};
  for (final c in courses) {
    final key = '${c.name}|${c.teacher}|${c.tag}';
    groups.putIfAbsent(key, () => []).add(c);
  }

  return groups.values.map((group) {
    if (group.length == 1) return group.first;
    final first = group.first;
    final allSections = <int>{};
    final allWeeks = <int>{};
    final positions = <String>{};
    for (final c in group) {
      allSections.addAll(c.sections);
      allWeeks.addAll(c.weeks);
      if (c.position.isNotEmpty) positions.add(c.position);
    }
    return Course(
      name: first.name,
      teacher: first.teacher,
      position: positions.join('、'),
      day: first.day,
      weeks: allWeeks.toList()..sort(),
      sections: allSections.toList()..sort(),
      colorIndex: first.colorIndex,
      tag: first.tag,
      remark: first.remark,
    );
  }).toList();
}

/// 生成学期课表条目（「共 N 门课程」标题 + 按星期分组 + 课程卡片）。
///
/// 返回不带外层 padding 的 widget 序列，方便嵌入已有 ListView / Column
/// （如全校课表详情在学期视图下方继续展示未排课程、调停补记录）。
/// 独立的学期课表页面可直接使用 [SemesterCourseListView]。
List<Widget> buildSemesterCourseItems(
  BuildContext context,
  List<Course> courses,
  CourseTableConfig config, {
  void Function(Course)? onCourseTap,
}) {
  if (courses.isEmpty) {
    return [
      const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无课程数据', style: TextStyle(fontSize: 16)),
        ),
      ),
    ];
  }

  // 按星期分组
  final byDay = <int, List<Course>>{};
  for (final c in courses) {
    if (c.day >= 1 && c.day <= 7) {
      byDay.putIfAbsent(c.day, () => []).add(c);
    }
  }

  final widgets = <Widget>[];
  // 标题
  widgets.add(Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      '共 ${courses.length} 门课程',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
  ));

  for (int day = 1; day <= 7; day++) {
    final dayCourses = byDay[day] ?? [];
    if (dayCourses.isEmpty) continue;

    // 同一天 + 相同课程名 + 相同教师 + 相同类型（实验/普通）→ 合并
    // 合并后节次/周次/教室都取并集，理论课和实验课天然按 tag 分开
    final merged = mergeSameCourses(dayCourses);

    final isWeekend = day >= 6;
    widgets.add(Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColorNotifier.value.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '周${kDayLabels[day - 1 < kDayLabels.length ? day - 1 : 0]}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isWeekend ? textHint(context) : textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    ));

    for (final course in merged) {
      widgets.add(TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SemesterCourseCard(
          course: course,
          config: config,
          onTap: onCourseTap == null ? null : () => onCourseTap(course),
        ),
      ));
    }
  }

  return widgets;
}

/// 学期课表视图（独立滚动列表，个人课表使用）。
///
/// 若需要在学期视图下方拼接其他内容（如全校课表的未排课程、
/// 调停补记录），请改用 [buildSemesterCourseItems] 嵌入外层列表。
class SemesterCourseListView extends StatelessWidget {
  final List<Course> courses;
  final CourseTableConfig config;
  final void Function(Course)? onCourseTap;

  const SemesterCourseListView({
    super.key,
    required this.courses,
    required this.config,
    this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children:
          buildSemesterCourseItems(context, courses, config, onCourseTap: onCourseTap),
    );
  }
}

/// 学期课表课程卡片（左侧主题色条 + 课程信息）。
///
/// 默认点击弹出课程详情（[showCourseDetailSheet]），可通过 [onTap] 自定义。
class SemesterCourseCard extends StatelessWidget {
  final Course course;
  final CourseTableConfig config;
  final VoidCallback? onTap;

  const SemesterCourseCard({
    super.key,
    required this.course,
    required this.config,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = config;
    final cColors = generateCourseColors(cfg);
    final color = cColors[course.colorIndex % cColors.length];
    final ts = cfg.textScale;
    final radius = cfg.cardRadius;
    final hideTeacher = cfg.hideTeacher;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius > 0 ? radius : 4),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: radius > 0 ? 1 : 0,
      child: InkWell(
        onTap: onTap ?? () => showCourseDetailSheet(context, course),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧色条
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // 课程信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (course.tag.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: tagBadgeColor(course.tag),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              course.tag,
                              style: TextStyle(
                                fontSize: 10 * ts,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            course.name,
                            style: TextStyle(
                              fontSize: 15 * ts,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hideTeacher && course.teacher.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 14 * ts, color: textHint(context)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(course.teacher,
                                style: TextStyle(
                                    fontSize: 12 * ts,
                                    color: textHint(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (course.position.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.room,
                              size: 14 * ts, color: textHint(context)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(course.position,
                                style: TextStyle(
                                    fontSize: 12 * ts,
                                    color: textHint(context))),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14 * ts, color: color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${course.sectionRangesCompact}  ${course.weeksDisplay}',
                            style: TextStyle(fontSize: 12 * ts, color: color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
