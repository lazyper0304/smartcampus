import 'dart:io';
import '../core/liquid_background.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme_utils.dart';
import '../core/glass_style.dart';
import '../core/ios_kit.dart';
import '../main.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  final ImagePicker _picker = ImagePicker();
  String? _previewBgPath;

  @override
  void initState() {
    super.initState();
    _previewBgPath = backgroundNotifier.value;
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // 复制到应用持久目录，避免原图被删除后丢失。
    // 文件名带毫秒时间戳保证路径唯一：FileImage 按路径缓存，旧版固定名
    // （background.jpg）重选同格式图片时既命中缓存、notifier 值也不变，
    // 导致背景一直停留在第一张。
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.split('.').last.toLowerCase();
    final dest =
        '${dir.path}/background_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(picked.path).copy(dest);

    if (!mounted) return;
    setState(() => _previewBgPath = dest);
    final appState = SmartCampusApp.of(context);
    await appState?.setBackground(dest);
    _cleanupOldBackgroundFiles(dir, keep: dest);
  }

  Future<void> _resetBackground() async {
    setState(() => _previewBgPath = null);
    final appState = SmartCampusApp.of(context);
    await appState?.setBackground(null);
    final dir = await getApplicationDocumentsDirectory();
    _cleanupOldBackgroundFiles(dir);
  }

  /// 清理本模块产生的历史背景文件（旧版固定名 background.* 与新版
  /// background_<时间戳>.*），按文件名匹配、与 keep 比较基名以规避
  /// 路径分隔符差异；删除失败静默，不影响主流程。
  void _cleanupOldBackgroundFiles(Directory dir, {String? keep}) {
    final keepName = keep?.split('/').last.split('\\').last;
    final pattern = RegExp(
        r'^background(?:_\d+)?\.(jpe?g|png|webp|gif|bmp)$',
        caseSensitive: false);
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!pattern.hasMatch(name)) continue;
      if (keepName != null && name == keepName) continue;
      try {
        entity.deleteSync();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBg = _previewBgPath != null;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        return GlassPage(
          // 主界面同款液态玻璃背景（模块化组件）
          background: const LiquidBackground(),
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
                      color: solidHairline(context),
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

  Widget _buildBackgroundSection(bool hasBg) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: solidHairline(context),
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
    return IosSectionHeader(title, padding: const EdgeInsets.fromLTRB(4, 4, 4, 8));
  }
}
