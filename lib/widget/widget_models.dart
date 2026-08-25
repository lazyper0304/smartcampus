/// 桌面组件数据模型：Flutter 侧整理课程/电费快照，
/// 序列化为 JSON 后经 MethodChannel 写入 SharedPreferences（原生可读）。
library;

/// 单节课程在组件上的展示信息
class WidgetCourseItem {
  final String time; // 节次，如 "1-2节"
  final String name; // 课程名
  final String room; // 教室
  final List<int> weeks; // 该课程出现的教学周（空 = 每周都有）；用于原生按「今天所在周」过滤
  const WidgetCourseItem({
    required this.time,
    required this.name,
    this.room = '',
    this.weeks = const [],
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'name': name,
        'room': room,
        'weeks': weeks,
      };
}

/// 课程表组件整体数据
///
/// 注意：组件「今天」的星期几必须在**原生渲染时**用当前日期计算，
/// 不能在 Flutter 侧写死。因此这里保存整周（7 天）的课程 + 当前周次，
/// 由原生 WidgetRenderer 在每次渲染时按当天 weekday 取出今日课程并生成标签。
/// 这样即使组件多日未刷新，只要原生重新渲染就会显示正确的「今天」。
class WidgetCourseData {
  final String title;
  final int currentWeek; // 兜底用：当前教学周（优先用 firstMondayMillis 现场计算）
  final int? firstMondayMillis; // 校历第一周周一（epoch millis），用于原生按设备时钟推算周次
  final Map<int, List<WidgetCourseItem>> days; // key = weekday(1=周一 … 7=周日)，存整学期课程（含 weeks）
  final String updatedAt; // 如 "8月16日 08:28"

  const WidgetCourseData({
    this.title = '今日课程',
    this.currentWeek = 1,
    this.firstMondayMillis,
    this.days = const {},
    this.updatedAt = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'currentWeek': currentWeek,
        if (firstMondayMillis != null) 'firstMonday': firstMondayMillis,
        'updatedAt': updatedAt,
        'days': days.map(
          (k, v) => MapEntry(
            k.toString(),
            v.map((c) => c.toJson()).toList(),
          ),
        ),
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

/// 摸鱼日历组件 · 节日条目：给出未来多次到来的日期表（当年+次年），
/// [weekly] 非 0 时（1=周一…7=周日）原生按设备时钟现算下一个该星期几。
class WidgetMoyuFestival {
  final String name;
  final int weekly; // 0 = 非周循环
  final List<int> dates; // epoch millis（零点），升序

  const WidgetMoyuFestival({
    required this.name,
    this.weekly = 0,
    required this.dates,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (weekly != 0) 'weekly': weekly,
        'dates': dates,
      };
}

/// 摸鱼日历组件整体数据（仅内置节日）。
///
/// 「还有几天」不在 Flutter 侧写死：节日存未来日期表、周循环只存 weekday，
/// 由原生 WidgetRenderer 在每次渲染时按当日零点现场计算，配合 AlarmManager
/// 30 分钟重绘实现跨天自动翻正。
class WidgetMoyuData {
  final List<WidgetMoyuFestival> festivals;
  final String updatedAt;

  const WidgetMoyuData({
    this.festivals = const [],
    this.updatedAt = '',
  });

  Map<String, dynamic> toJson() => {
        'festivals': festivals.map((f) => f.toJson()).toList(),
        'updatedAt': updatedAt,
      };
}

/// 倒计时组件 · 单条自定义目标（过期由原生过滤）
class WidgetCountdownItem {
  final String name;
  final int date; // epoch millis（零点）

  const WidgetCountdownItem({required this.name, required this.date});

  Map<String, dynamic> toJson() => {'name': name, 'date': date};
}

/// 倒计时组件整体数据（仅自定义目标）。
/// 「还有几天」同样由原生在每次渲染时按当日零点现场计算。
class WidgetCountdownData {
  final List<WidgetCountdownItem> items;
  final String updatedAt;

  const WidgetCountdownData({this.items = const [], this.updatedAt = ''});

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt,
      };
}
