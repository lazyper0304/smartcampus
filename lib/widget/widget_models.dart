/// 桌面组件数据模型：Flutter 侧整理课程/电费快照，
/// 序列化为 JSON 后经 MethodChannel 写入 SharedPreferences（原生可读）。
library;

/// 单节课程在组件上的展示信息
class WidgetCourseItem {
  final String time; // 节次，如 "1-2节"
  final String name; // 课程名
  final String room; // 教室
  const WidgetCourseItem({
    required this.time,
    required this.name,
    this.room = '',
  });

  Map<String, String> toJson() => {
        'time': time,
        'name': name,
        'room': room,
      };
}

/// 课程表组件整体数据
class WidgetCourseData {
  final String title;
  final String week; // 如 "第3周 · 周六"
  final List<WidgetCourseItem> courses;
  final bool empty;
  final String updatedAt; // 如 "08:30"

  const WidgetCourseData({
    this.title = '今日课程',
    this.week = '',
    this.courses = const [],
    this.empty = false,
    this.updatedAt = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'week': week,
        'courses': courses.map((c) => c.toJson()).toList(),
        'empty': empty,
        'updatedAt': updatedAt,
      };
}

/// 近 7 日单日用电（条形图数据点）
class WidgetDayUsage {
  final String label; // 如 "8/9"
  final double kwh;
  const WidgetDayUsage({required this.label, required this.kwh});

  Map<String, dynamic> toJson() => {
        'label': label,
        'kwh': kwh,
        'kwhText': kwh.toStringAsFixed(1),
      };
}

/// 电费组件整体数据
class WidgetDianfeiData {
  final String balance; // 剩余电量，如 "123.4"
  final String status; // 合闸 / 分闸
  final String monthKwh; // 本月用电
  final String monthMoney; // 本月金额
  final String total; // 累计用电
  final List<WidgetDayUsage> days; // 近 7 日
  final String updatedAt;

  const WidgetDianfeiData({
    this.balance = '--',
    this.status = '',
    this.monthKwh = '--',
    this.monthMoney = '--',
    this.total = '--',
    this.days = const [],
    this.updatedAt = '',
  });

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'status': status,
        'monthKwh': monthKwh,
        'monthMoney': monthMoney,
        'total': total,
        'days': days.map((d) => d.toJson()).toList(),
        'updatedAt': updatedAt,
      };
}
