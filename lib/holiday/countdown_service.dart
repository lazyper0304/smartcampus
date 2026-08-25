/// 节日倒计时服务：聚合内置节日并计算剩余天数。
///
/// 自定义倒计时已独立为 `lib/countdown/` 模块（[CountdownService]），
/// 本模块只负责内置节日清单。
library;

import 'festival.dart';
import 'holiday_data.dart';

/// 单条节日倒计时展示数据（已算好剩余天数与精确时长）。
class CountdownEntry {
  final String name;
  final DateTime target; // 下一次到来的日期（忽略时分秒）
  final int daysLeft; // 日期差（0=今天）
  final Duration remaining; // 精确到秒的剩余（target - now）
  final bool isPast; // 已到来

  const CountdownEntry({
    required this.name,
    required this.target,
    required this.daysLeft,
    required this.remaining,
    required this.isPast,
  });

  String get daysLabel => isPast ? '已到来' : '还有$daysLeft天';
}

/// 节日倒计时聚合服务。
class HolidayService {
  /// 内置节日倒计时（按剩余天数升序，最近优先）。
  static List<CountdownEntry> buildFestivalEntries(DateTime now) {
    final list = kFestivalSources.map((s) => _toEntry(s, now)).toList();
    list.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return list;
  }

  static CountdownEntry _toEntry(CountdownSource src, DateTime now) {
    final target = src.nextOccurrence(now);
    final fromDay = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    final daysLeft = targetDay.difference(fromDay).inDays;
    return CountdownEntry(
      name: src.name,
      target: target,
      daysLeft: daysLeft,
      remaining: target.difference(now),
      isPast: target.isBefore(now),
    );
  }
}
