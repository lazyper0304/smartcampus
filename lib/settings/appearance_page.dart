import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../core/local_storage.dart';
import '../core/theme_utils.dart';
import '../main.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  final ImagePicker _picker = ImagePicker();
  String? _previewBgPath;
  Color _selectedColor = accentColorNotifier.value;

  // 预设主题色板
  static const List<Color> _presetColors = [
    Color.fromRGBO(25, 25, 153, 1),   // 宜院蓝（默认）
    Color.fromRGBO(33, 150, 243, 1),  // 亮蓝
    Color.fromRGBO(52, 152, 219, 1),  // 天蓝
    Color.fromRGBO(26, 188, 156, 1),  // 青绿
    Color.fromRGBO(46, 204, 113, 1),  // 翠绿
    Color.fromRGBO(255, 235, 59, 1),  // 明黄
    Color.fromRGBO(243, 156, 18, 1),  // 橙黄
    Color.fromRGBO(230, 126, 34, 1),  // 琥珀
    Color.fromRGBO(231, 76, 60, 1),   // 朱红
    Color.fromRGBO(192, 57, 43, 1),   // 中国红
    Color.fromRGBO(233, 30, 99, 1),   // 樱花粉
    Color.fromRGBO(156, 39, 176, 1),  // 紫罗兰
  ];

  @override
  void initState() {
    super.initState();
    _previewBgPath = backgroundNotifier.value;
  }

  Future<void> _setAccentColor(Color color) async {
    setState(() => _selectedColor = color);
    accentColorNotifier.value = color;
    await LocalStorage.setString('accent_color', colorToHex(color));
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // 复制到应用持久目录，避免原图被删除后丢失
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.split('.').last;
    final dest = '${dir.path}/background.$ext';
    final file = File(picked.path);
    await file.copy(dest);

    if (!mounted) return;
    setState(() => _previewBgPath = dest);
    final appState = SmartCampusApp.of(context);
    await appState?.setBackground(dest);
  }

  Future<void> _resetBackground() async {
    setState(() => _previewBgPath = null);
    final appState = SmartCampusApp.of(context);
    await appState?.setBackground(null);
  }

  @override
  Widget build(BuildContext context) {
    final hasBg = _previewBgPath != null;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        return GlassPage(
          statusBarStyle: GlassStatusBarStyle.auto,
          child: Scaffold(
            appBar: AppBar(title: const Text('外观')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('主题模式'),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color.fromRGBO(25, 25, 153, 1)
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildThemeOption(
                            icon: Icons.brightness_auto_rounded,
                            label: '跟随系统',
                            selected: currentMode == ThemeMode.system,
                            onTap: () => _setMode(ThemeMode.system),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildThemeOption(
                            icon: Icons.light_mode_rounded,
                            label: '浅色',
                            selected: currentMode == ThemeMode.light,
                            onTap: () => _setMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildThemeOption(
                            icon: Icons.dark_mode_rounded,
                            label: '深色',
                            selected: currentMode == ThemeMode.dark,
                            onTap: () => _setMode(ThemeMode.dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _buildCurrentModeHint(currentMode),
                ),
                const SizedBox(height: 28),
                _buildSection('主题颜色'),
                const SizedBox(height: 8),
                _buildColorSection(),
                const SizedBox(height: 28),
                _buildSection('自定义背景'),
                const SizedBox(height: 8),
                _buildBackgroundSection(hasBg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
              children: _presetColors.map((color) {
                final selected = color.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () => _setAccentColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            ),
            const SizedBox(height: 12),
            // 自定义颜色按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showColorPicker(context),
                icon: Icon(Icons.colorize_rounded,
                    color: accentColorNotifier.value),
                label: Text(
                  '自定义颜色',
                  style: TextStyle(color: accentColorNotifier.value),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '当前主题色将应用到应用主色、按钮、导航栏等',
              style: TextStyle(fontSize: 12, color: textHint(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final initial = _selectedColor;
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initialColor: initial),
    );
    if (result != null && mounted) {
      _setAccentColor(result);
    }
  }

  Widget _buildBackgroundSection(bool hasBg) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预览图
            if (hasBg) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_previewBgPath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: Center(
                      child: Text('图片加载失败',
                          style: TextStyle(color: textHint(context))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.image_outlined,
                    label: '选择图片',
                    onTap: _pickImage,
                  ),
                ),
                if (hasBg) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.restart_alt_rounded,
                      label: '恢复默认',
                      color: Colors.red,
                      onTap: _resetBackground,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasBg ? '点击"恢复默认"可使用纯色背景' : '从相册选择一张图片作为应用背景',
              style: TextStyle(fontSize: 12, color: textHint(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? accentColorNotifier.value;
    return Material(
      color: effectiveColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: effectiveColor, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 以下为与之前一致的方法 ──

  Future<void> _setMode(ThemeMode mode) async {
    final appState = SmartCampusApp.of(context);
    await appState?.setThemeMode(mode);
  }

  Widget _buildCurrentModeHint(ThemeMode mode) {
    String desc;
    switch (mode) {
      case ThemeMode.system:
        desc = '跟随系统设置，自动切换浅色/深色模式';
        break;
      case ThemeMode.light:
        desc = '始终保持浅色模式';
        break;
      case ThemeMode.dark:
        desc = '始终保持深色模式';
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        desc,
        key: ValueKey('hint_${mode.name}'),
        style: TextStyle(fontSize: 13, color: textSecondary(context)),
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color blue = accentColorNotifier.value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? blue.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? blue.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? blue : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? blue : textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedScale(
              scale: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: selected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
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
}

/// HSV 调色盘对话框
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
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

  String _hex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
    return AlertDialog(
      title: const Text('自定义颜色'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 颜色预览
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
            // 色值显示
            Text(
              _hex(color),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // 色相滑块
            _buildSlider('色相', _hue, 0, 360, (v) => setState(() => _hue = v)),
            const SizedBox(height: 8),
            // 饱和度滑块
            _buildSlider('饱和度', _saturation, 0, 1, (v) => setState(() => _saturation = v)),
            const SizedBox(height: 8),
            // 明度滑块
            _buildSlider('明度', _value, 0, 1, (v) => setState(() => _value = v)),
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

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
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