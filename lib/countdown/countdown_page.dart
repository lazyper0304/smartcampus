/// 倒计时管理页：自定义目标的增删改 / 置顶 / 列表总览。
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassStatusBarStyle;

import '../core/ios_kit.dart';
import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../widget/widget_service.dart';
import 'countdown_service.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  List<CustomTarget> _targets = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await CountdownService.getTargets();
    if (!mounted) return;
    setState(() => _targets = list);
    // 数据变化后同步倒计时桌面组件（非 Android 平台静默降级）
    unawaited(
        WidgetService.saveCountdownData(await WidgetService.buildCountdownData()));
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('倒计时'), centerTitle: true),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                kIosPageHPadding,
                8,
                kIosPageHPadding,
                bottomBarSafePadding(context),
              ),
              children: [
                IosSectionHeader('我的倒计时'),
                IosListGroup(
                  children: [
                    IosListTile(
                      icon: Icons.add_circle_outline_rounded,
                      iconColor: accentOf(context),
                      title: '添加目标',
                      trailing: const Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey),
                      onTap: () => _showEditor(context),
                    ),
                    if (_targets.isEmpty)
                      Divider(
                          height: 1,
                          thickness: 0.5,
                          color: dividerColor(context)),
                    if (_targets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('还没有倒计时目标，点上方添加吧～',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    for (final c in _targets) ...[
                      Divider(
                          height: 1,
                          thickness: 0.5,
                          color: dividerColor(context)),
                      _targetRow(context, c),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _targetRow(BuildContext context, CustomTarget c) {
    final item =
        CountdownService.buildItems(DateTime.now(), [c]).first;
    return IosListTile(
      icon: c.emoji != null ? null : Icons.flag_rounded,
      iconColor: c.colorValue == null
          ? accentOf(context)
          : Color(c.colorValue!),
      title: c.emoji != null ? '${c.emoji} ${c.name}' : c.name,
      subtitle: item.isPast
          ? '已到来 · ${c.targetDate.month}/${c.targetDate.day}'
          : '还剩 ${item.daysLeft} 天 · ${c.targetDate.year}/${c.targetDate.month}/${c.targetDate.day}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 18,
              color: c.pinned ? accentOf(context) : textHint(context),
            ),
            onPressed: () async {
              await CountdownService.togglePin(c.id);
              _reload();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: textHint(context)),
            onPressed: () => _confirmDelete(context, c),
          ),
        ],
      ),
      onTap: () => _showEditor(context, existing: c),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CustomTarget c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('确定删除「${c.name}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await CountdownService.removeTarget(c.id);
      _reload();
    }
  }

  void _showEditor(BuildContext context, {CustomTarget? existing}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EditorSheet(
        existing: existing,
        onSave: (name, date) async {
          final target = CustomTarget(
            id: existing?.id ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            // 编辑时保留原有图标；新增不再提供图标输入
            emoji: existing?.emoji,
            targetDate: date,
            pinned: existing?.pinned ?? false,
            createdAt: existing?.createdAt ?? DateTime.now(),
          );
          if (existing != null) {
            await CountdownService.updateTarget(target);
          } else {
            await CountdownService.addTarget(target);
          }
          _reload();
        },
      ),
    );
  }
}

/// 新增/编辑倒计时目标的底部面板（iOS 风格日期选择器 + 玻璃容器）。
class EditorSheet extends StatefulWidget {
  final CustomTarget? existing;
  final void Function(String name, DateTime date) onSave;

  const EditorSheet({super.key, this.existing, required this.onSave});

  @override
  State<EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<EditorSheet> {
  late final TextEditingController _nameCtrl;
  late DateTime _picked;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _picked = widget.existing?.targetDate ??
        DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: base.withValues(alpha: isDark ? 0.6 : 0.5),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.existing != null ? '编辑目标' : '添加目标',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '目标名称',
                    hintText: '如 考研 / 生日 / 放假',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _picked,
                    minimumDate: DateTime(2000),
                    maximumDate: DateTime(2100),
                    onDateTimeChanged: (d) => _picked = d,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          widget.onSave(name, _picked);
                          Navigator.pop(context);
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
