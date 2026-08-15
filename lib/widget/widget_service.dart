import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../course/course.dart';
import '../dianfei/dianfei_models.dart';
import 'widget_models.dart';

/// 桌面组件桥接服务：
///  - 把课程/电费数据整理为 JSON，经 MethodChannel 写入原生 SharedPreferences
///    （AppWidget 运行在独立进程，无法读 Dart 内存缓存，必须持久化桥接）
///  - 注册原生 → Flutter 的组件点击回调（MainActivity invokeMethod）
///  - 仅 Android 平台生效；其他平台调用安全降级（try-catch 静默）。
class WidgetService {
  WidgetService._();

  static const MethodChannel _channel =
      MethodChannel('com.smartcampus.smartcampus/widget');

  /// 组件点击目标回调（原生热启动时触发）
  static void Function(String target)? _onTarget;

  /// 冷启动时原生暂存的待跳转目标
  static String? _pendingTarget;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 初始化：注册回调 + 拉取冷启动待跳转目标。
  /// [onTarget] 收到组件点击目标（course / dianfei），由调用方执行跳转。
  static Future<void> init({required void Function(String target) onTarget}) async {
    _onTarget = onTarget;
    if (!_isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetClick') {
        final target = call.arguments as String?;
        if (target != null && target.isNotEmpty) _onTarget?.call(target);
      }
    });

    try {
      final pending =
          await _channel.invokeMethod<String>('getPendingWidgetTarget');
      if (pending != null && pending.isNotEmpty) _pendingTarget = pending;
    } catch (_) {
      // 非 Android 或插件未注册，忽略
    }
  }

  /// MainScreen 就绪后消费冷启动待跳转目标（返回后清空）。
  static String? consumePendingTarget() {
    final t = _pendingTarget;
    _pendingTarget = null;
    return t;
  }

  // ==================== 数据写入 ====================

  /// 推送课程表组件数据并刷新所有已添加的课程组件。
  static Future<void> saveCourseData(WidgetCourseData data) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('saveCourseData', {
        'data': jsonEncode(data.toJson()),
      });
    } catch (_) {}
  }

  /// 推送电费组件数据并刷新所有已添加的电费组件。
  static Future<void> saveDianfeiData(WidgetDianfeiData data) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('saveDianfeiData', {
        'data': jsonEncode(data.toJson()),
      });
    } catch (_) {}
  }

  /// 切换组件主题（system 跟随系统 / dark / light）并全量刷新。
  static Future<void> setTheme(String theme) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('setWidgetTheme', {'theme': theme});
    } catch (_) {}
  }

  /// 手动刷新所有组件（重新按当前尺寸渲染）。
  static Future<void> refreshAll() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('refreshAllWidgets');
    } catch (_) {}
  }

  // ==================== 数据整理 ====================

  /// 由课程列表 + 当前周次整理「今日课程」组件快照。
  /// [courses] 应为已合并实验课的完整课表；[now] 用于判定星期几。
  static WidgetCourseData buildCourseData({
    required List<Course> courses,
    required int currentWeek,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    final today = time.weekday; // 1=周一 … 7=周日

    // 今日且本周有课的课程，按开始节次排序
    final todayCourses = courses
        .where((c) => c.day == today && c.weeks.contains(currentWeek))
        .toList()
      ..sort((a, b) => (a.sections.isEmpty ? 0 : a.sections.first)
          .compareTo(b.sections.isEmpty ? 0 : b.sections.first));

    const weekNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final items = todayCourses
        .take(5)
        .map((c) => WidgetCourseItem(
              time: c.sectionRangesCompact,
              name: c.name,
              room: [c.position, c.teacher]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
            ))
        .toList();

    return WidgetCourseData(
      week: '第 $currentWeek 周 · ${weekNames[today - 1]}',
      courses: items,
      empty: items.isEmpty,
      updatedAt: _formatTime(time),
    );
  }

  /// 由电表状态 + 日度明细整理电费组件快照（取最近 7 天画条形图）。
  static WidgetDianfeiData buildDianfeiData({
    required DianfeiStatus status,
    required List<DayData> days,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    final recent =
        days.length > 7 ? days.sublist(days.length - 7) : days;

    return WidgetDianfeiData(
      balance: status.shengyu.toStringAsFixed(1),
      status: status.zhuangtai,
      monthKwh: status.monthKwh.toStringAsFixed(1),
      monthMoney: status.monthMoney.toStringAsFixed(2),
      total: status.leiji.toStringAsFixed(1),
      days: recent.map((d) {
        final parts = d.date.split('-');
        final label = parts.length >= 3
            ? '${int.tryParse(parts[1])}/${int.tryParse(parts[2])}'
            : d.date;
        return WidgetDayUsage(label: label, kwh: d.kwh);
      }).toList(),
      updatedAt: _formatTime(time),
    );
  }

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
