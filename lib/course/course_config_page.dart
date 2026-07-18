import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'course_config.dart';

class CourseTableConfigPage extends StatefulWidget {
  final CourseTableConfig config;
  final ValueChanged<CourseTableConfig> onChanged;

  const CourseTableConfigPage({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<CourseTableConfigPage> createState() => _CourseTableConfigPageState();
}

class _CourseTableConfigPageState extends State<CourseTableConfigPage> {
  late CourseTableConfig _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = widget.config.copy();
  }

  void _update() {
    _cfg.save();
    widget.onChanged(_cfg.copy());
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: const Text('课程表设置')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('布局'),
            const SizedBox(height: 8),
            _switchTile('显示调课入口', '在顶部栏显示「调课」按钮',
                _cfg.showChangesButton, (v) {
              setState(() => _cfg.showChangesButton = v);
              _update();
            }),
            const SizedBox(height: 24),
            _section('显示'),
            const SizedBox(height: 8),
            _switchTile('隐藏时间段', '隐藏左侧节次标签列', _cfg.hideTimeLabels, (v) {
              setState(() => _cfg.hideTimeLabels = v);
              _update();
            }),
            const SizedBox(height: 6),
            _switchTile('隐藏日期', '隐藏表头的日期文字', _cfg.hideDate, (v) {
              setState(() => _cfg.hideDate = v);
              _update();
            }),
            const SizedBox(height: 6),
            _switchTile('显示网格线', '显示单元格边框分隔线', _cfg.showGridLines, (v) {
              setState(() => _cfg.showGridLines = v);
              _update();
            }),
            const SizedBox(height: 6),
            _switchTile('隐藏教师', '隐藏卡片上的教师姓名', _cfg.hideTeacher, (v) {
              setState(() => _cfg.hideTeacher = v);
              _update();
            }),
            const SizedBox(height: 24),
            _section('尺寸'),
            const SizedBox(height: 8),
            _sliderTile('单元格高度: ${_cfg.cellHeight.toInt()}px', _cfg.cellHeight,
                80, 200, (v) {
              setState(() => _cfg.cellHeight = v);
              _update();
            }),
            const SizedBox(height: 6),
            _sliderTile(
                '头部高度: ${_cfg.headerHeight.toInt()}px', _cfg.headerHeight,
                35, 60, (v) {
              setState(() => _cfg.headerHeight = v);
              _update();
            }),
            const SizedBox(height: 6),
            _sliderTile('文字缩放: ${_cfg.textScale.toStringAsFixed(2)}x',
                _cfg.textScale, 0.7, 1.5, (v) {
              setState(() => _cfg.textScale = v);
              _update();
            }, divisions: 8),
            const SizedBox(height: 24),
            _section('样式'),
            const SizedBox(height: 8),
            _sliderTile(
                '圆角半径: ${_cfg.cardRadius.toInt()}px', _cfg.cardRadius,
                0, 16, (v) {
              setState(() => _cfg.cardRadius = v);
              _update();
            }),
            const SizedBox(height: 24),
            _section('课程颜色'),
            const SizedBox(height: 8),
            _colorSection(),
            const SizedBox(height: 24),
            _section('预览'),
            const SizedBox(height: 8),
            _buildPreview(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary(context),
        ),
      ),
    );
  }

  Widget _switchTile(
      String label, String? subtitle, bool value, ValueChanged<bool> onChanged) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColorNotifier.value.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          style:
                              TextStyle(fontSize: 11, color: textHint(context))),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: accentColorNotifier.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderTile(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColorNotifier.value.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ??
                  ((max - min) / 1).round().clamp(1, 200),
              onChanged: onChanged,
              activeColor: accentColorNotifier.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: accentColorNotifier.value.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('课程卡片配色',
                style:
                    TextStyle(fontSize: 13, color: textSecondary(context))),
            const SizedBox(height: 4),
            Text('点击色块更换颜色，长按恢复默认',
                style: TextStyle(fontSize: 11, color: textHint(context))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_cfg.customColors.length, (i) {
                final color = _cfg.customColors[i];
                return GestureDetector(
                  onTap: () => _pickColor(i),
                  onLongPress: () {
                    setState(() {
                      _cfg.customColors[i] =
                          CourseTableConfig.defaultColors[i];
                    });
                    _update();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final cfg = _cfg;
    final colors = cfg.customColors;
    final scale = 0.55;
    final cellH = 44 * scale;
    final headH = 30 * scale;
    final radius = cfg.cardRadius;
    final ts = cfg.textScale * scale;
    final hideTeacher = cfg.hideTeacher;
    final showGrid = cfg.showGridLines;

    // mock 课程数据（Map 格式避免本地类问题）
    final mocks = [
      {'name': '高等数学', 'teacher': '张老师', 'position': 'A101',
       'day': 1, 'first': 1, 'last': 2, 'colorIndex': 0, 'tag': ''},
      {'name': '大学英语', 'teacher': '李老师', 'position': 'B202',
       'day': 2, 'first': 1, 'last': 2, 'colorIndex': 1, 'tag': ''},
      {'name': 'Python实验', 'teacher': '王老师', 'position': 'C303',
       'day': 3, 'first': 3, 'last': 4, 'colorIndex': 2, 'tag': '实验'},
    ];

    final dayCount = 3;
    const dayLabels = ['', '一', '二', '三'];
    final timeColW = 42 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayW = (constraints.maxWidth - timeColW) / dayCount;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: accentColorNotifier.value.withValues(alpha: 0.08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('实时预览，配置变化即时反映',
                    style: TextStyle(
                        fontSize: 12, color: textHint(context))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: timeColW + dayW * dayCount,
                    child: Column(
                      children: [
                        // header
                        Row(
                          children: [
                            Container(
                              width: timeColW,
                              height: headH,
                              color: accentColorNotifier.value
                                  .withValues(alpha: 0.06),
                              alignment: Alignment.center,
                              child: Text('节次',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9 * cfg.textScale)),
                            ),
                            ...List.generate(dayCount, (i) {
                              return Container(
                                width: dayW,
                                height: headH,
                                color: accentColorNotifier.value
                                    .withValues(alpha: 0.06),
                                alignment: Alignment.center,
                                child: Text('周${dayLabels[i + 1]}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9 * cfg.textScale)),
                              );
                            }),
                          ],
                        ),
                        // grid
                        SizedBox(
                          height: 4 * cellH,
                          child: Stack(
                            children: [
                              // background rows
                              Column(
                                children: List.generate(4, (i) {
                                  final period = i + 1;
                                  return SizedBox(
                                    height: cellH,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: timeColW,
                                          height: cellH,
                                          color: accentColorNotifier.value
                                              .withValues(alpha: 0.06),
                                          alignment: Alignment.center,
                                          child: Text('第$period节',
                                              style: TextStyle(
                                                  fontSize:
                                                      8 * cfg.textScale)),
                                        ),
                                        ...List.generate(dayCount, (_) {
                                          return Container(
                                            width: dayW,
                                            height: cellH,
                                            decoration: showGrid
                                                ? BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors.grey
                                                            .shade300,
                                                        width: 0.3))
                                                : null,
                                          );
                                        }),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                              // course cards
                              ...mocks.map((m) {
                                final first = m['first'] as int;
                                final last = m['last'] as int;
                                final sc = last - first + 1;
                                return Positioned(
                                  left: timeColW + ((m['day'] as int) - 1) * dayW,
                                  top: (first - 1) * cellH,
                                  width: dayW,
                                  height: sc * cellH,
                                  child: _buildPreviewCard(
                                    m, colors, radius, ts, hideTeacher,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard(
    Map<String, dynamic> course,
    List<Color> colors,
    double radius,
    double ts,
    bool hideTeacher,
  ) {
    final color = colors[(course['colorIndex'] as int) % colors.length];
    final showTag = (course['tag'] as String?)?.isNotEmpty ?? false;
    final name = course['name'] as String? ?? '';
    final teacher = course['teacher'] as String? ?? '';
    final position = course['position'] as String? ?? '';

    return Container(
      margin: EdgeInsets.all(radius > 0 ? 1 : 0.5),
      child: Material(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(radius),
        elevation: radius > 0 ? 1 : 0,
        shadowColor: color.withValues(alpha: 0.3),
        child: Padding(
          padding: EdgeInsets.all(radius > 0 ? 3 : 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showTag)
                Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text('实验',
                      style: TextStyle(
                          fontSize: 6 * ts,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.2)),
                ),
              Text(name,
                  style: TextStyle(
                    fontSize: 9 * ts,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
              if (!hideTeacher && teacher.isNotEmpty)
                Text(teacher,
                    style: TextStyle(
                        fontSize: 7 * ts,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.3),
                    textAlign: TextAlign.center),
              if (position.isNotEmpty)
                Text(position,
                    style: TextStyle(
                        fontSize: 7 * ts,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3),
                    textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickColor(int index) async {
    final initial = _cfg.customColors[index];
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPickerDialog(initialColor: initial),
    );
    if (result != null && mounted) {
      setState(() {
        _cfg.customColors[index] = result;
      });
      _update();
    }
  }
}

/// HSV 调色盘对话框
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const ColorPickerDialog({required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => ColorPickerDialogState();
}

class ColorPickerDialogState extends State<ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
    return AlertDialog(
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '#${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _slider('色相', _hue, 0, 360, (v) => setState(() => _hue = v)),
            const SizedBox(height: 8),
            _slider(
                '饱和度', _saturation, 0, 1, (v) => setState(() => _saturation = v)),
            const SizedBox(height: 8),
            _slider('明度', _value, 0, 1, (v) => setState(() => _value = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: _currentColor,
        ),
      ],
    );
  }
}
