/// 中国农历（阴阳历）本地转换算法。
///
/// 纯 Dart 实现，无任何网络依赖，用于在客户端离线计算：
///   - 某农历年的正月初一（春节）对应的公历日期；
///   - 任意农历月日（含闰月）对应的公历日期。
///
/// 数据表 [lunarInfo] 覆盖 1900–2100 年，每项 20bit 编码：
///   - 低 4 bit：闰月月份（0 表示当年无闰月，1–12 表示闰某月）；
///   - 第 16 bit（0x10000）：闰月天数（1=30 天，0=29 天）；
///   - 第 15–4 bit：正月…腊月共 12 个正常月的大小月（1=30 天，0=29 天）。
///
/// 基准锚点：农历 1900 年正月初一 = 公历 1900-01-31。
library;

class Lunar {
  /// 农历 1900–2100 年信息表（经典 200 年数据）。
  static const List<int> lunarInfo = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, //
    0x09ad0, 0x055d2, // 1900-1909
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, //
    0x095b0, 0x14977, // 1910-1919
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, //
    0x052f2, 0x04970, // 1920-1929
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, //
    0x1c8d7, 0x0c950, // 1930-1939
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, //
    0x0a950, 0x0b557, // 1940-1949
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, //
    0x0e950, 0x06aa0, // 1950-1959
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, //
    0x05b57, 0x056a0, // 1960-1969
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, //
    0x0b6a0, 0x195a6, // 1970-1979
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, //
    0x0ab60, 0x09570, // 1980-1989
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, //
    0x096d5, 0x092e0, // 1990-1999
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, //
    0x092d0, 0x0cab5, // 2000-2009
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, //
    0x052b0, 0x0a930, // 2010-2019
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, //
    0x0ea65, 0x0d530, // 2020-2029
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, //
    0x0d520, 0x0dd45, // 2030-2039
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, //
    0x06d20, 0x0ada0, // 2040-2049
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, //
    0x1a6c4, 0x0aae0, // 2050-2059
    0x092e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, //
    0x0a6d0, 0x055d4, // 2060-2069
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, //
    0x0a5b0, 0x052b0, // 2070-2079
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, //
    0x054e4, 0x0d160, // 2080-2089
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, //
    0x0d150, 0x0f250, // 2090-2099
    0x0d520, // 2100
  ];

  /// 农历 [year] 年正月初一（春节）对应的公历日期。
  static DateTime springFestival(int year) {
    int offset = 0;
    for (int y = 1900; y < year; y++) {
      offset += _lunarYearDays(y);
    }
    // 1900-01-31 为农历 1900 年正月初一
    return DateTime(1900, 1, 31).add(Duration(days: offset));
  }

  /// 农历 [year] 年总天数（含闰月）。
  static int _lunarYearDays(int year) {
    int sum = 348; // 12 * 29
    final info = lunarInfo[year - 1900];
    for (int i = 0x8000; i > 0x8; i >>= 1) {
      sum += (info & i) != 0 ? 1 : 0;
    }
    return sum + _leapDays(year);
  }

  /// 农历 [year] 年闰哪个月（1–12），无闰月返回 0。
  static int leapMonth(int year) => lunarInfo[year - 1900] & 0xf;

  /// 农历 [year] 年闰月天数（无闰月返回 0）。
  static int _leapDays(int year) {
    if (leapMonth(year) == 0) return 0;
    return (lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
  }

  /// 农历 [year] 年 [month] 月（1–12，正常月）天数。
  static int _monthDays(int year, int month) {
    // bit 15 → 正月, bit 4 → 腊月
    final bit = 16 - month;
    return (lunarInfo[year - 1900] & (1 << bit)) != 0 ? 30 : 29;
  }

  /// 农历 [year] 年 [month] 月 [day] 日对应的公历日期。
  /// [isLeap] 为 true 时表示闰 [month] 月。
  static DateTime lunarToSolar(
    int year,
    int month,
    int day, {
    bool isLeap = false,
  }) {
    final base = springFestival(year);
    int total = day - 1; // 正月内偏移
    final leap = leapMonth(year);
    for (int m = 1; m < month; m++) {
      total += _monthDays(year, m);
      if (leap == m) total += _leapDays(year);
    }
    if (isLeap) total += _monthDays(year, month);
    return base.add(Duration(days: total));
  }
}
