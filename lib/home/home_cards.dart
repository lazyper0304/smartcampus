/// 首页信息卡片配置数据层。
///
/// 首页右栏卡片（今日课程/校园新闻/倒计时/摸鱼日历/电费）支持
/// 增删与排序，配置持久化到 LocalStorage `home_cards`（可见卡片 id 数组，
/// 顺序即展示顺序；未列入 = 已删除，可随时加回）。
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/local_storage.dart';

/// 卡片元数据
class HomeCardMeta {
  final String id;
  final String name;
  final IconData icon;

  /// 卡片图标配色（彩色图标，2026-09-20）：换色只改这里
  final Color color;

  const HomeCardMeta(this.id, this.name, this.icon, this.color);
}

/// 全部可选卡片（固定注册表）
///
/// 配色与设置页对应行保持一致（见 `lib/settings/settings_page.dart`）。
const List<HomeCardMeta> kHomeCardsCatalog = [
  HomeCardMeta('today_courses', '今日课程', Icons.calendar_month_rounded,
      Color(0xFF3B6BFF)), // 蓝（同「我的课表」）
  HomeCardMeta('news', '校园新闻', Icons.newspaper_rounded,
      Color(0xFFFF8A3D)), // 橙（资讯类）
  HomeCardMeta('countdown', '倒计时', Icons.timer_outlined,
      Color(0xFFF2545B)), // 红（同设置页「倒计时」）
  HomeCardMeta('moyu', '摸鱼日历', Icons.celebration_rounded,
      Color(0xFFF5A623)), // 金（同设置页「摸鱼日历」）
  HomeCardMeta('dianfei', '电费', Icons.bolt_rounded,
      Color(0xFFFFB020)), // 琥珀（同「临港电费」）
];

/// 按 id 查元数据
HomeCardMeta? homeCardMetaById(String id) {
  for (final c in kHomeCardsCatalog) {
    if (c.id == id) return c;
  }
  return null;
}

/// 按 id 取卡片图标配色（未登记回退中性灰）
Color homeCardColorOf(String id,
        {Color fallback = const Color(0xFF78849E)}) =>
    homeCardMetaById(id)?.color ?? fallback;

class HomeCardsStore {
  HomeCardsStore._();

  static const String storageKey = 'home_cards';

  /// 默认全显示，顺序即当前右栏排布
  static const List<String> defaults = [
    'today_courses',
    'news',
    'countdown',
    'moyu',
    'dianfei',
  ];

  /// 读取可见卡片 id 列表（过滤已下架 id，损坏时回退默认全量）
  static Future<List<String>> load() async {
    try {
      final raw = await LocalStorage.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        return (jsonDecode(raw) as List).cast<String>().where((id) {
          return kHomeCardsCatalog.any((c) => c.id == id);
        }).toList();
      }
    } catch (_) {/* 配置损坏时回退默认 */}
    return List.of(defaults);
  }

  /// 保存（id 数组，顺序即展示顺序）
  static Future<void> save(List<String> ids) =>
      LocalStorage.setString(storageKey, jsonEncode(ids));
}

/// 配置变更通知（管理页修改后自增，首页监听自动刷新）
final ValueNotifier<int> homeCardsChangedNotifier = ValueNotifier(0);
