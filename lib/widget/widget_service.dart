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

  /// 保存电费查询参数（meterId / openId / 是否后付费）。
  /// 电费接口无需 cookie，原生桌面组件端可凭此参数直接实时查询；
  /// 传入空 meterId 表示解绑（清空参数）。
  static Future<void> saveDianfeiParams(
    String meterId,
    String wechatUserOpenid, {
    int isAfter = 0,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('saveDianfeiParams', {
        'meterId': meterId,
        'openId': wechatUserOpenid,
        'isAfter': isAfter,
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

  /// 由课程列表 + 当前周次整理课程表组件快照。
  ///
  /// 关键：保存**整个学期**课程（按 weekday 1..7 分组，保留每门课的生效周次 [weeks]），
  /// 不在 Flutter 侧过滤「当前周」、也不写死「今天」。
  /// 由原生 WidgetRenderer 在**每次渲染时**用设备时钟 + [firstMonday] 现场推算教学周次，
  /// 再按当日 weekday 取出今日课程并生成「第 X 周 · 周Y」标签。
  /// 这样即使组件数周未打开 App，只要原生被 AlarmManager 触发重新渲染，
  /// 就能自动翻到正确的星期几与正确的教学周次，彻底消除「周次滞后」。
  ///
  /// [courses] 应为已合并实验课的完整课表；[firstMonday] 为校历第一周周一（用于推算周次）；
  /// [currentWeek] 作为无 [firstMonday] 时的兜底；[now] 仅用于更新时间展示。
  static WidgetCourseData buildCourseData({
    required List<Course> courses,
    required int currentWeek,
    DateTime? firstMonday,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();

    // 按 weekday 分组：保存整学期课程，不按 currentWeek 过滤（周次交给原生现场推算）
    final byDay = <int, List<Course>>{};
    for (final c in courses) {
      (byDay[c.day] ??= []).add(c);
    }

    final days = <int, List<WidgetCourseItem>>{};
    for (int d = 1; d <= 7; d++) {
      final list = byDay[d] ?? <Course>[];
      list.sort((a, b) => (a.sections.isEmpty ? 0 : a.sections.first)
          .compareTo(b.sections.isEmpty ? 0 : b.sections.first));
      days[d] = list.take(12).map((c) => WidgetCourseItem(
            time: c.sectionRangesCompact,
            name: c.name,
            room: [c.position, c.teacher]
                .where((e) => e.isNotEmpty)
                .join(' · '),
            weeks: c.weeks,
          )).toList();
    }

    return WidgetCourseData(
      currentWeek: currentWeek,
      firstMondayMillis: firstMonday?.millisecondsSinceEpoch,
      days: days,
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

  /// 更新时间格式：包含月日时分（如 "8月16日 08:28"）
  static String _formatTime(DateTime t) =>
      '${t.month}月${t.day}日 '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
