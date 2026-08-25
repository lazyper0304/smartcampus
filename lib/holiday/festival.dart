/// 倒计时目标的数据模型与计算。
///
/// 三类内置节日来源（均实现 [CountdownSource]，可离线算出"下一次到来"的公历日期）：
///   - [SolarFestival]：公历固定月日（元旦 / 情人节 / 愚人节 / 劳动节 / 国庆节 / 程序员节 / 圣诞节）。
///   - [LunarFestival]：农历月日，经 [Lunar] 转公历（春节 / 元宵 / 端午 / 七夕 / 中秋）。
///   - [WeeklyFestival]：每周循环（周六）。
///
/// 自定义目标见 [countdown_service.dart] 的 [CustomTarget]（同样实现 [CountdownSource]）。
library;

import 'lunar.dart';

/// 倒计时来源：提供名称与"下一次到来"的公历日期。
abstract class CountdownSource {
  const CountdownSource();

  String get name;
  String? get emoji;

  /// 返回不早于 [from] 的最近一次到来日期（按日期，忽略时分秒）。
  DateTime nextOccurrence(DateTime from);

  /// 返回自 [from] 起未来 [count] 次到来的日期（升序，按日期）。
  ///
  /// 用于桌面组件：写入未来多次到来的日期表，原生渲染时按设备时钟
  /// 自行挑选「下一个未到来」的日期，无需在 Kotlin 侧移植农历算法。
  List<DateTime> upcomingOccurrences(DateTime from, int count) {
    final result = <DateTime>[];
    var cursor = from;
    for (int i = 0; i < count; i++) {
      final d = nextOccurrence(cursor);
      result.add(d);
      cursor = d.add(const Duration(days: 1)); // 从次日起找下一次
    }
    return result;
  }

  /// 跨年搜索窗口，覆盖 [from] 前后若干年，确保总能取到未来日期。
  static DateTime _nearest(DateTime from, DateTime Function(DateTime) candidate) {
    DateTime? best;
    for (int y = from.year - 1; y <= from.year + 2; y++) {
      final d = candidate(DateTime(y));
      if (!d.isBefore(from) && (best == null || d.isBefore(best))) best = d;
    }
    return best!;
  }
}

/// 公历固定节日（month/day）。
class SolarFestival extends CountdownSource {
  @override
  final String name;
  @override
  final String? emoji;
  final int month;
  final int day;

  const SolarFestival(this.name, this.month, this.day, {this.emoji});

  @override
  DateTime nextOccurrence(DateTime from) =>
      CountdownSource._nearest(from, (y) => DateTime(y.year, month, day));
}

/// 农历节日（lunarMonth/lunarDay，1–12）。
class LunarFestival extends CountdownSource {
  @override
  final String name;
  @override
  final String? emoji;
  final int lunarMonth;
  final int lunarDay;

  const LunarFestival(this.name, this.lunarMonth, this.lunarDay, {this.emoji});

  @override
  DateTime nextOccurrence(DateTime from) => CountdownSource._nearest(
        from,
        (y) => Lunar.lunarToSolar(y.year, lunarMonth, lunarDay),
      );
}

/// 每周循环节日（weekday：DateTime.monday=1 … sunday=7）。
class WeeklyFestival extends CountdownSource {
  @override
  final String name;
  @override
  final String? emoji;
  final int weekday;

  const WeeklyFestival(this.name, this.weekday, {this.emoji});

  @override
  DateTime nextOccurrence(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final diff = (weekday - from.weekday) % 7; // 0=今天
    return today.add(Duration(days: diff));
  }
}
