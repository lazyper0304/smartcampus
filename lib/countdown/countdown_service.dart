/// 自定义倒计时服务：模型 + 本地持久化 + 条目计算。
///
/// 从 holiday（摸鱼日历）模块独立拆出，成为单独的「倒计时」功能：
///  - 模型 [CustomTarget]：一次性目标日期，支持 emoji/强调色/置顶；
///  - 持久化经 [LocalStorage]（沿用键 `moyu_custom_countdowns`，兼容旧数据）；
///  - [CountdownService.buildItems] 计算剩余天数并排序（置顶优先 → 天数升序）。
library;

import 'dart:convert';

import 'package:flutter/material.dart' show Color, ValueNotifier;

import '../core/local_storage.dart';

/// 用户自定义倒计时目标（一次性日期）。
class CustomTarget {
  final String name;
  final String? emoji;
  final DateTime targetDate;
  final int? colorValue;
  final bool pinned;
  final String id;
  final DateTime createdAt;

  const CustomTarget({
    required this.id,
    required this.name,
    this.emoji,
    required this.targetDate,
    this.colorValue,
    this.pinned = false,
    required this.createdAt,
  });

  CustomTarget copyWith({
    String? name,
    String? emoji,
    DateTime? targetDate,
    int? colorValue,
    bool? pinned,
  }) =>
      CustomTarget(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        targetDate: targetDate ?? this.targetDate,
        colorValue: colorValue ?? this.colorValue,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'targetDate': targetDate.toIso8601String(),
        'colorValue': colorValue,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomTarget.fromJson(Map<String, dynamic> j) => CustomTarget(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String?,
        targetDate: DateTime.parse(j['targetDate'] as String),
        colorValue: j['colorValue'] as int?,
        pinned: j['pinned'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// 单条倒计时展示数据（已算好剩余天数）。
class CountdownItem {
  final CustomTarget target;
  final int daysLeft; // 日期差（0=今天）
  final bool isPast; // 已过期 / 已到来

  const CountdownItem({
    required this.target,
    required this.daysLeft,
    required this.isPast,
  });

  String get daysLabel => isPast ? '已到来' : '还有$daysLeft天';
}

/// 自定义倒计时聚合与持久化服务。
class CountdownService {
  static const String _key = 'moyu_custom_countdowns';

  /// 数据变更信号（增删改/置顶后自增），供首页卡片等常驻组件即时重载。
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  /// 全部自定义目标（置顶在前 → 天数升序）。
  static Future<List<CustomTarget>> getTargets() async {
    final raw = await LocalStorage.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final targets = list.map(CustomTarget.fromJson).toList();
      _sort(targets);
      return targets;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addTarget(CustomTarget t) async {
    final list = await getTargets();
    list.add(t);
    await _save(list);
  }

  static Future<void> removeTarget(String id) async {
    final list = await getTargets();
    list.removeWhere((e) => e.id == id);
    await _save(list);
  }

  static Future<void> updateTarget(CustomTarget t) async {
    final list = await getTargets();
    final i = list.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      list[i] = t;
      await _save(list);
    }
  }

  static Future<void> togglePin(String id) async {
    final list = await getTargets();
    final i = list.indexWhere((e) => e.id == id);
    if (i >= 0) {
      list[i] = list[i].copyWith(pinned: !list[i].pinned);
      await _save(list);
    }
  }

  /// 计算展示条目（[source] 缺省时从存储读取后计算；排序同存储顺序）。
  static List<CountdownItem> buildItems(
    DateTime now, [
    List<CustomTarget>? source,
  ]) =>
      (source ?? []).map((c) {
        final fromDay = DateTime(now.year, now.month, now.day);
        final targetDay = DateTime(
            c.targetDate.year, c.targetDate.month, c.targetDate.day);
        return CountdownItem(
          target: c,
          daysLeft: targetDay.difference(fromDay).inDays,
          isPast: c.targetDate.isBefore(now),
        );
      }).toList();

  static void _sort(List<CustomTarget> list) {
    list.sort((a, b) => a.pinned == b.pinned
        ? a.targetDate.compareTo(b.targetDate)
        : (a.pinned ? -1 : 1));
  }

  static Future<void> _save(List<CustomTarget> list) async {
    _sort(list);
    await LocalStorage.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
    changed.value++;
  }
}

/// 强调色解析（自定义目标可带主题色，否则返回 null 由调用方取默认）。
Color? parseAccentColor(int? value) => value == null ? null : Color(value);
