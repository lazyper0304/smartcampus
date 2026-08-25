/// 内置节日注册表（展示顺序由 [HolidayService] 按剩余天数升序排列）。
///
/// 法定节假日：元旦 / 春节 / 劳动 / 端午 / 中秋 / 国庆。
/// 其它节日：元宵。
/// 每周循环：周六（摸鱼首选）。
library;

import 'festival.dart';

/// 内置节日来源（不带 emoji，展示按剩余天数升序）。
const List<CountdownSource> kFestivalSources = [
  WeeklyFestival('周六', DateTime.saturday),
  SolarFestival('元旦', 1, 1),
  LunarFestival('春节', 1, 1),
  LunarFestival('元宵节', 1, 15),
  SolarFestival('劳动节', 5, 1),
  LunarFestival('端午节', 5, 5),
  LunarFestival('中秋节', 8, 15),
  SolarFestival('国庆节', 10, 1),
];
