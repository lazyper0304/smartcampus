import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme_utils.dart';
import '../main.dart';
import 'course.dart';
import 'course_config.dart';

/// 星期标签（周→文字）
const List<String> kDayLabels = ['一', '二', '三', '四', '五', '六', '日'];

/// 从当前主题色生成 12 级课程卡片色阶，若配置了自定义颜色则优先使用
List<Color> generateCourseColors(CourseTableConfig? config) {
  if (config != null && config.customColors.length >= 12) {
    return config.customColors;
  }
  final base = accentColorNotifier.value;
  return List.generate(12, (i) {
    final t = i / 11;
    return Color.lerp(base, Colors.white, t * 0.55)!;
  });
}

/// 根据课程 tag 返回标签底色
Color tagBadgeColor(String tag) {
  switch (tag) {
    case '实验':
      return Colors.orange.shade500;
    case '调':
    case '停':
    case '补':
      return const Color(0xFFC2410C);
    default:
      return accentColorNotifier.value;
  }
}

List<String> _splitNames(String raw) => raw
    .split(RegExp(r'[、，,]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// 合并同一节课多位老师的记录为一张卡片，防止同一时间格多张卡片堆叠。
///
/// 分组条件：同一天 + 同名 + 同标签；组内**节次有重叠**才合并
/// （教师/教室去重后以「、」拼接，节次/周次取并集，颜色/备注取首条）。
/// 节次完全不重叠（如 1-2 节与 5-6 节）保持为独立卡片。
List<Course> mergeSameSlotTeachers(List<Course> courses) {
  final groups = <String, List<Course>>{};
  for (final c in courses) {
    final key = '${c.day}|${c.name}|${c.tag}';
    groups.putIfAbsent(key, () => []).add(c);
  }

  Course mergeTwo(Course a, Course b) {
    final teachers = <String>{..._splitNames(a.teacher), ..._splitNames(b.teacher)};
    final positions = <String>{..._splitNames(a.position), ..._splitNames(b.position)};
    return Course(
      name: a.name,
      teacher: teachers.join('、'),
      position: positions.join('、'),
      day: a.day,
      weeks: {...a.weeks, ...b.weeks}.toList()..sort(),
      sections: {...a.sections, ...b.sections}.toList()..sort(),
      colorIndex: a.colorIndex,
      tag: a.tag,
      remark: a.remark.isNotEmpty ? a.remark : b.remark,
    );
  }

  final result = <Course>[];
  for (final group in groups.values) {
    if (group.length == 1) {
      result.add(group.first);
      continue;
    }
    final merged = <Course>[];
    for (final c in group) {
      int? hit;
      for (int i = 0; i < merged.length; i++) {
        if (merged[i].sections.any(c.sections.contains)) {
          hit = i;
          break;
        }
      }
      if (hit == null) {
        merged.add(c);
      } else {
        merged[hit] = mergeTwo(merged[hit], c);
      }
    }
    result.addAll(merged);
  }
  return result;
}

/// 可复用的周课表网格（个人课表与全校班级课表共用）
///
/// [courses] 必须是**已按当前周过滤**后的课程列表。
///
/// [mergeSections] 为 true 时每两小节课合并为一个显示单元
/// （1、2 / 3、4 / 5、6 …），网格行数与左侧节次标签同步合并，
/// 课程卡片按所属大节单元撑满显示（全校课表详情使用）。
class CourseScheduleGrid extends StatelessWidget {
  final List<Course> courses;
  final CourseTableConfig config;
  final int currentWeek;
  final int todayWeek;
  final int todayDay;
  final DateTime? firstMonday;
  final int maxWeek;
  final void Function(int direction)? onSwipe; // +1=下一周, -1=上一周
  final void Function(Course)? onCourseTap;
  final List<String> dayLabels;
  final bool mergeSections;

  const CourseScheduleGrid({
    super.key,
    required this.courses,
    required this.config,
    required this.currentWeek,
    this.todayWeek = 1,
    this.todayDay = 0,
    this.firstMonday,
    this.maxWeek = 20,
    this.onSwipe,
    this.onCourseTap,
    this.dayLabels = kDayLabels,
    this.mergeSections = true,
  });

  @override
  Widget build(BuildContext context) {
    // 同一节课多位老师（同天+同名+同标签+节次重叠）先合并为一张卡片，
    // 教师/教室拼接显示，避免同一时间格多张卡片堆叠
    final mergedCourses = mergeSameSlotTeachers(courses);

    int maxSection = 12;
    for (final c in mergedCourses) {
      for (final s in c.sections) {
        if (s > maxSection) maxSection = s;
      }
    }

    final cfg = config;
    final cColors = generateCourseColors(cfg);
    final cellH = cfg.cellHeight;
    final headH = cfg.headerHeight;
    final showTimeCol = !cfg.hideTimeLabels;
    // 节次列统一 30px（2026-08-14 用户要求；原合并 35 / 非合并 44）
    final timeColWidth = showTimeCol ? 30.0 : 8.0;
    final showDates = !cfg.hideDate;
    final showGrid = cfg.showGridLines;
    final textScale = cfg.textScale;

    // 行数：合并模式每两小节一行（12 节 → 6 行）
    final rowCount = mergeSections ? (maxSection + 1) ~/ 2 : maxSection;

    double? swipeStartX;

    return Listener(
      onPointerDown: (event) => swipeStartX = event.position.dx,
      onPointerUp: (event) {
        if (swipeStartX == null) return;
        final dx = event.position.dx - swipeStartX!;
        swipeStartX = null;
        if (dx.abs() < 50) return;
        if (dx < 0 && currentWeek < maxWeek) {
          onSwipe?.call(1);
        } else if (dx > 0 && currentWeek > 1) {
          onSwipe?.call(-1);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: LayoutBuilder(
          key: ValueKey('week_$currentWeek'),
          builder: (context, constraints) {
            final dayWidth = (constraints.maxWidth - timeColWidth) / 7;
            final totalWidth = timeColWidth + dayWidth * 7;
            final gridHeight = rowCount * cellH;

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    _WeekHeader(
                      dayWidth: dayWidth,
                      headH: headH,
                      showTimeCol: showTimeCol,
                      timeColWidth: timeColWidth,
                      showDates: showDates,
                      showGrid: showGrid,
                      textScale: textScale,
                      currentWeek: currentWeek,
                      todayWeek: todayWeek,
                      todayDay: todayDay,
                      firstMonday: firstMonday,
                      dayLabels: dayLabels,
                    ),
                    SizedBox(
                      height: gridHeight,
                      child: Stack(
                        children: [
                          Column(
                            children: List.generate(rowCount, (rowIdx) {
                              final period = rowIdx + 1;
                              return _GridRow(
                                period: period,
                                mergeSections: mergeSections,
                                dayWidth: dayWidth,
                                cellH: cellH,
                                showTimeCol: showTimeCol,
                                timeColWidth: timeColWidth,
                                showGrid: showGrid,
                                textScale: textScale,
                                currentWeek: currentWeek,
                                todayWeek: todayWeek,
                                todayDay: todayDay,
                                dayLabels: dayLabels,
                              );
                            }),
                          ),
                          ...mergedCourses.map((course) {
                            final firstSec = course.sections.isNotEmpty
                                ? course.sections.first
                                : 1;
                            final lastSec = course.sections.isNotEmpty
                                ? course.sections.last
                                : firstSec;
                            // 合并模式：按双节单元定位（第 1、2 节同属单元 1）
                            final topUnit = mergeSections
                                ? (firstSec + 1) ~/ 2
                                : firstSec;
                            final unitCount = mergeSections
                                ? ((lastSec + 1) ~/ 2) - topUnit + 1
                                : lastSec - firstSec + 1;
                            final dayIdx = course.day - 1;
                            if (dayIdx < 0 || dayIdx > 6) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: timeColWidth + dayIdx * dayWidth,
                              top: (topUnit - 1) * cellH,
                              width: dayWidth,
                              height: unitCount * cellH,
                              child: _CourseCard(
                                course: course,
                                colors: cColors,
                                config: cfg,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  final double dayWidth;
  final double headH;
  final bool showTimeCol;
  final double timeColWidth;
  final bool showDates;
  final bool showGrid;
  final double textScale;
  final int currentWeek;
  final int todayWeek;
  final int todayDay;
  final DateTime? firstMonday;
  final List<String> dayLabels;

  const _WeekHeader({
    required this.dayWidth,
    required this.headH,
    required this.showTimeCol,
    required this.timeColWidth,
    required this.showDates,
    required this.showGrid,
    required this.textScale,
    required this.currentWeek,
    required this.todayWeek,
    required this.todayDay,
    required this.firstMonday,
    required this.dayLabels,
  });

  String? _dateForWeekday(int weekday) {
    if (firstMonday == null) return null;
    try {
      final targetDate =
          firstMonday!.add(Duration(days: (currentWeek - 1) * 7 + (weekday - 1)));
      // 点分隔 + 月/日补零（原 M/d 斜杠分隔：8/14 → 8.14），与日历观感一致
      return '${targetDate.month}.${targetDate.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showTimeCol)
          Container(
            width: timeColWidth,
            height: headH,
            decoration: BoxDecoration(
              color: accentColorNotifier.value.withValues(alpha: 0.06),
              border: showGrid
                  ? Border.all(
                      color: isDark(context)
                          ? const Color(0xFF4A4A5E)
                          : Colors.grey.shade300,
                      width: 0.5)
                  : null,
            ),
            child: Center(
                child: Text('节次',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11))),
          ),
        ...List.generate(7, (i) {
          final day = i + 1;
          final isToday = todayWeek == currentWeek && day == todayDay;
          final isWeekend = i >= 5;
          final date = _dateForWeekday(day);

          return Expanded(
            child: SizedBox(
              height: headH,
              child: Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context).colorScheme.primaryContainer
                      : accentColorNotifier.value.withValues(alpha: 0.06),
                  border: showGrid
                      ? Border.all(
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : isDark(context)
                                  ? const Color(0xFF4A4A5E)
                                  : Colors.grey.shade300,
                          width: isToday ? 1.5 : 0.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '周${dayLabels[day - 1 < dayLabels.length ? day - 1 : 0]}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13 * textScale,
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : isWeekend
                                ? textHint(context)
                                : textPrimary(context),
                      ),
                    ),
                    if (showDates && date != null)
                      Text(
                        date,
                        style: TextStyle(
                          // 10 * textScale：与「周X」视觉协调（原 9 偏小）
                          fontSize: 10 * textScale,
                          fontWeight: FontWeight.w500,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              // ⚠️ 原 Colors.black87 深色模式下黑字不可见
                              // → 跟随主题（textSecondary 深色浅灰）
                              : textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _GridRow extends StatelessWidget {
  final int period;
  final bool mergeSections;
  final double dayWidth;
  final double cellH;
  final bool showTimeCol;
  final double timeColWidth;
  final bool showGrid;
  final double textScale;
  final int currentWeek;
  final int todayWeek;
  final int todayDay;
  final List<String> dayLabels;

  const _GridRow({
    required this.period,
    this.mergeSections = false,
    required this.dayWidth,
    required this.cellH,
    required this.showTimeCol,
    required this.timeColWidth,
    required this.showGrid,
    required this.textScale,
    required this.currentWeek,
    required this.todayWeek,
    required this.todayDay,
    required this.dayLabels,
  });

  @override
  Widget build(BuildContext context) {
    final unifiedBg = accentColorNotifier.value.withValues(alpha: 0.06);
    return SizedBox(
      height: cellH,
      child: Row(
        children: [
          if (showTimeCol)
            Container(
              width: timeColWidth,
              height: cellH,
              decoration: BoxDecoration(
                color: unifiedBg,
                border: showGrid
                    ? Border.all(
                        color: isDark(context)
                            ? const Color(0xFF4A4A5E)
                            : Colors.grey.shade300,
                        width: 0.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  mergeSections
                      ? '${period * 2 - 1}-${period * 2}节'
                      : '第$period节',
                  textAlign: TextAlign.center,
                  // 30px 窄列 + 大 textScale 下防折行破版（超宽截断）
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 10 * textScale, height: 1.2),
                ),
              ),
            ),
          ...List.generate(7, (dayIdx) {
            final day = dayIdx + 1;
            final isToday = todayWeek == currentWeek && day == todayDay;
            return Expanded(
              child: Container(
                height: cellH,
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35)
                      : null,
                  border: showGrid
                      ? Border.all(
                          color: isDark(context)
                              ? const Color(0xFF4A4A5E)
                              : Colors.grey.shade300,
                          width: 0.5)
                      : isToday
                          ? const Border(
                              bottom: BorderSide(
                                color: Colors.transparent,
                                width: 0,
                              ),
                            )
                          : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final List<Color> colors;
  final CourseTableConfig config;

  const _CourseCard({
    required this.course,
    required this.colors,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final color = colors[course.colorIndex % colors.length];
    final ts = config.textScale;
    final radius = config.cardRadius;
    final hideTeacher = config.hideTeacher;
    final showTag = course.tag.isNotEmpty;

    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => showCourseDetailSheet(context, course),
          child: Padding(
            padding: EdgeInsets.all(radius > 0 ? 4 : 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showTag)
                  Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                    decoration: BoxDecoration(
                      color: tagBadgeColor(course.tag),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      course.tag,
                      style: TextStyle(
                          fontSize: 6.5 * ts,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.3),
                    ),
                  ),
                const SizedBox(height: 1),
                // 课程名：Flexible 约束高度（卡片尺寸不变，内部自适应剩余空间），
                // 字号调小保证默认配置下完整显示课程名/教师/教室（2026-08-13）
                Flexible(
                  child: Text(
                    course.name,
                    style: TextStyle(
                      fontSize: 10 * ts,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!hideTeacher && course.teacher.isNotEmpty)
                  Text(
                    course.teacher,
                    style: TextStyle(
                      fontSize: 7.5 * ts,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                    // 多位教师「、」拼接后可换行完整显示
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                if (course.position.isNotEmpty)
                  Text(
                    course.position,
                    style: TextStyle(
                        fontSize: 7.5 * ts,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3),
                    // 教室允许换行（窄列不再省略），3 行兜底防极端溢出
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (radius > 0) {
      cardBody = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: cardBody,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(radius > 0 ? 1.5 : 1),
      child: cardBody,
    );
  }
}

/// 课程详情底部弹窗（个人课表与班级课表共用）
void showCourseDetailSheet(BuildContext context, Course course) {
  final tagColor = course.tag.isNotEmpty
      ? (course.tag == '实验'
          ? Colors.orange.shade500
          : tagBadgeColor(course.tag))
      : null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      // 图标行：彩色圆角底容器 + 语义配色（与设置页 IosListTile 风格统一，
      // 2026-08-14 优化；原灰色 textHint 小图标过素）
      Widget detailRow(IconData icon, Color iconColor, String text) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(text,
                    style:
                        TextStyle(fontSize: 14, color: textPrimary(context))),
              ),
            ],
          ),
        );
      }

      // ⚠️ 磨砂玻璃容器（与 showQuickAppPicker 同款）：主背景
      // scaffoldBackgroundColor 全局为透明（main.dart），不能用它做弹窗底色，
      // 否则内容直接透出底下页面（2026-08-09 修复课程详情弹窗背景透明）。
      // 顶部 40 留白放最外层 Padding——若放 Container margin，
      // BackdropFilter 会覆盖整片（含留白区），弹窗上方出现多余模糊带。
      final sheetIsDark = Theme.of(ctx).brightness == Brightness.dark;
      final sheetBase =
          sheetIsDark ? const Color(0xFF1C1C1E) : Colors.white;
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              decoration: BoxDecoration(
                // 顶部略亮模拟玻璃反光，主体半透明透出模糊背景
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    sheetBase.withValues(alpha: sheetIsDark ? 0.55 : 0.45),
                    sheetBase.withValues(alpha: sheetIsDark ? 0.48 : 0.38),
                  ],
                  stops: const [0.0, 0.45],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22)),
                border: Border(
                  top: BorderSide(
                    color: sheetIsDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: textHint(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (course.tag.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(course.tag,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      Expanded(
                        child: Text(course.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (course.teacher.isNotEmpty)
                    detailRow(Icons.person_outline, Colors.blue, course.teacher),
                  if (course.position.isNotEmpty)
                    detailRow(
                        Icons.room_outlined, Colors.green.shade600, course.position),
                  detailRow(
                    Icons.schedule_outlined,
                    Colors.orange.shade700,
                    '周${kDayLabels[course.day - 1 < kDayLabels.length ? course.day - 1 : 0]}  ${course.sectionRangesCompact}',
                  ),
                  detailRow(
                    Icons.date_range_outlined,
                    Colors.teal,
                    course.weeksDisplay,
                  ),
                  if (course.remark.isNotEmpty)
                    detailRow(
                        Icons.notes_rounded, Colors.indigo, course.remark),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 周次切换工具条（个人课表与班级课表共用）
class CourseWeekBar extends StatelessWidget {
  final int currentWeek;
  final int maxWeek;
  final int? todayWeek;
  final VoidCallback? onJumpToday;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const CourseWeekBar({
    super.key,
    required this.currentWeek,
    required this.maxWeek,
    this.todayWeek,
    this.onJumpToday,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final canPrev = currentWeek > 1 && onPrev != null;
    final canNext = currentWeek < maxWeek && onNext != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor(context))),
      ),
      child: Row(
        children: [
          Text('第 $currentWeek 周',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          if (todayWeek != null && currentWeek != todayWeek)
            GestureDetector(
              onTap: onJumpToday,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('回到本周',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: canPrev ? onPrev : null,
            child: Icon(Icons.chevron_left,
                size: 20,
                color: canPrev
                    ? textSecondary(context)
                    : isDark(context)
                        ? const Color(0xFF4A4A5E)
                        : Colors.grey.shade300),
          ),
          Text('$currentWeek/$maxWeek',
              style: TextStyle(color: textSecondary(context))),
          GestureDetector(
            onTap: canNext ? onNext : null,
            child: Icon(Icons.chevron_right,
                size: 20,
                color: canNext
                    ? textSecondary(context)
                    : isDark(context)
                        ? const Color(0xFF4A4A5E)
                        : Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}
