import 'package:flutter/material.dart';
import '../core/local_storage.dart';

String _colorToHex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return const Color(0xFF191999);
  return Color.fromARGB(
    255,
    int.parse(h.substring(0, 2), radix: 16),
    int.parse(h.substring(2, 4), radix: 16),
    int.parse(h.substring(4, 6), radix: 16),
  );
}

/// 课程表配置模型
class CourseTableConfig {
  /// 显示调课入口按钮
  bool showChangesButton;

  /// 隐藏左侧时间段标签
  bool hideTimeLabels;

  /// 隐藏表头日期
  bool hideDate;

  /// 显示网格线
  bool showGridLines;

  /// 单元格高度
  double cellHeight;

  /// 头部高度
  double headerHeight;

  /// 隐藏教师
  bool hideTeacher;

  /// 文字缩放倍数（0.7 ~ 1.5）
  double textScale;

  /// 课程卡片圆角半径
  double cardRadius;

  /// 自定义课程颜色列表
  List<Color> customColors;

  CourseTableConfig({
    this.showChangesButton = true,
    this.hideTimeLabels = false,
    this.hideDate = false,
    this.showGridLines = false,
    this.cellHeight = 120,
    this.headerHeight = 42,
    this.hideTeacher = false,
    this.textScale = 1.0,
    this.cardRadius = 8,
    List<Color>? customColors,
  }) : customColors = customColors ?? List.from(_defaultColors);

  static const List<Color> _defaultColors = [
    Color(0xFF2196F3),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFF9800),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFE91E63),
    Color(0xFF3949AB),
    Color(0xFF00ACC1),
    Color(0xFFFFB300),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
  ];

  /// 默认 12 色配色
  static const List<Color> defaultColors = _defaultColors;

  static const _prefix = 'course_config_';

  /// 保存配置到本地存储
  Future<void> save() async {
    await _saveBool('showChanges', showChangesButton);
    await _saveBool('hideTime', hideTimeLabels);
    await _saveBool('hideDate', hideDate);
    await _saveBool('showGrid', showGridLines);
    await LocalStorage.setString(
        '${_prefix}cellHeight', cellHeight.toStringAsFixed(0));
    await LocalStorage.setString(
        '${_prefix}headerHeight', headerHeight.toStringAsFixed(0));
    await _saveBool('hideTeacher', hideTeacher);
    await LocalStorage.setString(
        '${_prefix}textScale', textScale.toStringAsFixed(2));
    await LocalStorage.setString(
        '${_prefix}cardRadius', cardRadius.toStringAsFixed(0));
    await LocalStorage.setString('${_prefix}colors',
        customColors.map((c) => _colorToHex(c)).join(','));
  }

  Future<void> _saveBool(String key, bool value) async {
    await LocalStorage.setString('${_prefix}$key', value ? '1' : '0');
  }

  /// 从本地存储加载配置
  static Future<CourseTableConfig> load() async {
    final config = CourseTableConfig();
    config.showChangesButton = await _loadBool('showChanges', true);
    config.hideTimeLabels = await _loadBool('hideTime', false);
    config.hideDate = await _loadBool('hideDate', false);
    config.showGridLines = await _loadBool('showGrid', false);

    final cellH = await LocalStorage.getString('${_prefix}cellHeight');
    if (cellH != null) config.cellHeight = double.tryParse(cellH) ?? 120;

    final headH = await LocalStorage.getString('${_prefix}headerHeight');
    if (headH != null) config.headerHeight = double.tryParse(headH) ?? 42;

    config.hideTeacher = await _loadBool('hideTeacher', false);

    final ts = await LocalStorage.getString('${_prefix}textScale');
    if (ts != null) config.textScale = double.tryParse(ts) ?? 1.0;

    final cr = await LocalStorage.getString('${_prefix}cardRadius');
    if (cr != null) config.cardRadius = double.tryParse(cr) ?? 8;

    final colorsStr = await LocalStorage.getString('${_prefix}colors');
    if (colorsStr != null && colorsStr.isNotEmpty) {
      config.customColors =
          colorsStr.split(',').map((h) => _hexToColor(h.trim())).toList();
    }

    return config;
  }

  static Future<bool> _loadBool(String key, bool defaultValue) async {
    final v = await LocalStorage.getString('${_prefix}$key');
    if (v == null) return defaultValue;
    return v == '1';
  }

  CourseTableConfig copy() => CourseTableConfig(
        showChangesButton: showChangesButton,
        hideTimeLabels: hideTimeLabels,
        hideDate: hideDate,
        showGridLines: showGridLines,
        cellHeight: cellHeight,
        headerHeight: headerHeight,
        hideTeacher: hideTeacher,
        textScale: textScale,
        cardRadius: cardRadius,
        customColors: List.from(customColors),
      );

  @override
  String toString() =>
      'CourseTableConfig(showChanges=$showChangesButton, hideTime=$hideTimeLabels, '
      'hideDate=$hideDate, showGrid=$showGridLines, cellH=$cellHeight, '
      'headH=$headerHeight, hideTch=$hideTeacher, '
      'scale=$textScale, radius=$cardRadius, colors=${customColors.length})';
}
