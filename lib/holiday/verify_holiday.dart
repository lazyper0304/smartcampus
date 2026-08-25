/// 数值验证：以 2026-08-25（周二）为基准，核对 8 条倒计时天数。
/// 运行：flutter/bin/dart run lib/holiday/verify_holiday.dart
// ignore_for_file: avoid_print
library;

import 'holiday_data.dart';

void main() {
  final from = DateTime(2026, 8, 25, 18, 21); // 周二
  int daysLeft(DateTime target) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(target.year, target.month, target.day);
    return t.difference(f).inDays;
  }

  final expected = {
    '周六': 4,
    '元旦': 129,
    '春节': 165,
    '元宵节': 179,
    '劳动节': 249,
    '端午节': 288,
    '中秋节': 31,
    '国庆节': 37,
  };

  int pass = 0;
  int fail = 0;
  for (final s in kFestivalSources) {
    final target = s.nextOccurrence(from);
    final got = daysLeft(target);
    final exp = expected[s.name]!;
    final ok = got == exp;
    if (ok) {
      pass++;
    } else {
      fail++;
    }
    print(
      '${ok ? '✅' : '❌'} 距『${s.name}』还有$got天'
      '  (期望$exp, 目标日 ${_fmt(target)})',
    );
  }
  print('\n结果：通过 $pass / 失败 $fail');
  if (fail > 0) throw StateError('倒计时算法校验未通过');
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
