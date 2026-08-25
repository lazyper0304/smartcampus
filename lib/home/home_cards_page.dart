import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/ios_kit.dart';
import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'home_cards.dart';

/// 首页卡片管理页（设置 → 首页卡片 / 首页右上「编辑卡片」）
///
/// 增删 / 拖拽排序首页信息卡片，配置持久化到 `home_cards`，
/// 修改后通过 [homeCardsChangedNotifier] 通知首页刷新。
class HomeCardsPage extends StatefulWidget {
  const HomeCardsPage({super.key});

  @override
  State<HomeCardsPage> createState() => _HomeCardsPageState();
}

class _HomeCardsPageState extends State<HomeCardsPage> {
  List<String> _visible = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await HomeCardsStore.load();
    if (!mounted) return;
    setState(() {
      _visible = ids;
      _loaded = true;
    });
  }

  /// 未显示（可添加）的卡片，按注册表顺序
  List<HomeCardMeta> get _hidden {
    final shown = _visible.toSet();
    return kHomeCardsCatalog.where((c) => !shown.contains(c.id)).toList();
  }

  /// 保存并通知首页刷新
  Future<void> _save(List<String> ids) async {
    await HomeCardsStore.save(ids);
    if (mounted) setState(() => _visible = ids);
    homeCardsChangedNotifier.value++;
  }

  void _remove(String id) {
    final next = List<String>.from(_visible)..remove(id);
    _save(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = List<String>.from(_visible);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _save(next);
  }

  void _add(HomeCardMeta meta) => _save([..._visible, meta.id]);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final hidden = _hidden;
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: const Text('首页卡片')),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: [
              MaxWidthContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 已显示列表（拖拽排序 / 左滑删除） ──
                    IosSectionHeader('已显示（${_visible.length}）'),
                    if (_visible.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        alignment: Alignment.center,
                        child: Text('首页暂无卡片，从下方添加',
                            style:
                                TextStyle(fontSize: 13, color: textHint(context))),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        padding: EdgeInsets.zero,
                        itemCount: _visible.length,
                        onReorderItem: _reorder,
                        itemBuilder: (context, i) {
                          final id = _visible[i];
                          final meta = homeCardMetaById(id);
                          if (meta == null) return const SizedBox.shrink();
                          return Dismissible(
                            key: ValueKey('home_card_$id'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _remove(id),
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                borderRadius:
                                    BorderRadius.circular(kIosCardRadius),
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
                                child: _buildTileRow(meta),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 4),
                    // ── 可添加 ──
                    IosSectionHeader('可添加'),
                    if (hidden.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        child: Text('已添加全部卡片',
                            style:
                                TextStyle(fontSize: 13, color: textHint(context))),
                      )
                    else
                      IosListGroup(
                        // ListView 已提供水平 padding，分组卡不再自带 margin
                        margin: EdgeInsets.zero,
                        children: hidden
                            .map((meta) => IosListTile(
                                  icon: meta.icon,
                                  title: meta.name,
                                  subtitle: '点击添加到首页',
                                  onTap: () => _add(meta),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '长按拖动排序 · 左滑删除',
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

  Widget _buildTileRow(HomeCardMeta meta) {
    final color = accentOf(context);
    return GlassListTile.standalone(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(meta.icon, color: color, size: 18),
      ),
      title: Text(meta.name,
          // 显式主题色：深色模式防黑字（同常用功能管理页修复）
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimary(context))),
      trailing: const Icon(Icons.drag_handle, size: 22, color: Color(0xFF8E8E93)),
    );
  }
}
