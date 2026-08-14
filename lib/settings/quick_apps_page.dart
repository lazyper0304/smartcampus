import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/ios_kit.dart';
import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../home/app_data.dart';

/// 常用功能管理页（设置 → 常用功能）
///
/// 增删 / 拖拽排序首页快捷入口，配置持久化到 `home_quick_apps`，
/// 修改后通过 [quickAppsChangedNotifier] 通知首页宫格刷新。
class QuickAppsPage extends StatefulWidget {
  const QuickAppsPage({super.key});

  @override
  State<QuickAppsPage> createState() => _QuickAppsPageState();
}

class _QuickAppsPageState extends State<QuickAppsPage> {
  List<AppEntry> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await QuickAppsStore.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
    });
  }

  /// 保存并通知首页刷新
  Future<void> _save(List<AppEntry> items) async {
    await QuickAppsStore.save(items);
    if (mounted) setState(() => _items = items);
    quickAppsChangedNotifier.value++;
  }

  void _remove(AppEntry entry) {
    final next = List<AppEntry>.from(_items)..remove(entry);
    _save(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = List<AppEntry>.from(_items);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _save(next);
  }

  Future<void> _add() async {
    final picked = await showQuickAppPicker(
      context,
      exclude: _items.map((e) => e.name).toSet(),
      maxCount: QuickAppsStore.maxCount,
    );
    if (picked == null || !mounted) return;
    _save([..._items, picked]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final full = _items.length >= QuickAppsStore.maxCount;
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        // 顶部标题参考隐私协议页：AppBar 导航栏标题（非大标题）
        appBar: AppBar(title: const Text('常用功能')),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: [
              MaxWidthContent(
                child: Column(
                  // stretch 强制卡片同宽
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 已添加列表（拖拽排序 / 左滑删除） ──
                    IosSectionHeader(
                        '已添加（${_items.length}/${QuickAppsStore.maxCount}）'),
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        alignment: Alignment.center,
                        child: Text('暂无常用功能，点击下方添加',
                            style: TextStyle(fontSize: 13, color: textHint(context))),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        onReorderItem: _reorder,
                        itemBuilder: (context, i) {
                          final entry = _items[i];
                          return Dismissible(
                            key: ValueKey('quick_${entry.name}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _remove(entry),
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(kIosCardRadius),
                              ),
                              padding: const EdgeInsets.only(right: 20),
                              alignment: Alignment.centerRight,
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            child: ReorderableDelayedDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _buildTileRow(entry),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 4),
                    // ── 添加 ──
                    IosListGroup(
                      // ListView 已提供水平 padding，分组卡不再自带 margin
                      margin: EdgeInsets.zero,
                      children: [
                        IosListTile(
                          icon: Icons.add_rounded,
                          title: '添加常用功能',
                          subtitle: full
                              ? '已达上限（${QuickAppsStore.maxCount} 个）'
                              : '从全部应用中选择',
                          onTap: full ? null : _add,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '长按拖动排序 · 左滑删除 · 最多 ${QuickAppsStore.maxCount} 个',
                        style: TextStyle(
                          fontSize: 12,
                          color: textHint(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileRow(AppEntry entry) {
    final color = accentOf(context);
    return GlassListTile.standalone(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(entry.icon, color: color, size: 18),
      ),
      title: Text(entry.name,
          // 显式主题色：深色模式防黑字（GlassListTile 默认取 Cupertino
          // fallback 黑色，见 2026-08-14 修复）
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimary(context))),
      trailing: const Icon(Icons.drag_handle, size: 22, color: Color(0xFF8E8E93)),
    );
  }
}
