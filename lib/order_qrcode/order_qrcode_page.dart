import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/glass_style.dart';
import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'order_qrcode_controller.dart';
import 'order_qrcode_detail_page.dart';
import 'order_qrcode_model.dart';
import 'order_qrcode_my_page.dart';
import 'order_qrcode_submit_page.dart';
import 'widgets/order_qrcode_widgets.dart';

/// 点餐码列表页。
///
/// 参考实现 `order_qrcode_list_page.dart`（BingoApp）。差异：
/// - 无 Riverpod（`ListenableBuilder` + `ChangeNotifier`）、无 easy_localization；
/// - 页面壳用 [SimplePage]（`AppPageScaffold` 等价物）；
/// - 校区筛选改为**手动选择**（参考工程依赖 GPS 自动定位校区，本项目
///   不引入定位依赖）；
/// - 上传入口同时放在标题栏「+」与「我的上传」页。
class OrderQrcodePage extends StatefulWidget {
  const OrderQrcodePage({super.key});

  @override
  State<OrderQrcodePage> createState() => _OrderQrcodePageState();
}

class _OrderQrcodePageState extends State<OrderQrcodePage> {
  final OrderQrcodeController _controller = OrderQrcodeController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _controller.setKeyword(value);
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchDebounce?.cancel();
    _controller.setKeyword('');
  }

  Future<void> _openDetail(OrderQRCode item) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(builder: (_) => OrderQrcodeDetailPage(item: item)),
    );
  }

  Future<void> _openMy() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(builder: (_) => const OrderQrcodeMyPage()),
    );
  }

  Future<void> _openSubmit() async {
    final ok = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const OrderQrcodeSubmitPage()),
    );
    if (ok == true && mounted) {
      await _controller.refresh();
    }
  }

  /// 校区选择（参考工程导航栏右侧的同款入口，改为手动选择）
  Future<void> _pickCampus() async {
    final s = _controller.state;
    final names = <String>{
      for (final c in s.campuses) c.campus,
      ...OrderQrcodeUtils.campusPresets,
    }.where((e) => e.isNotEmpty).toList()
      ..sort();

    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择校区'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(
              '全部校区',
              style: TextStyle(
                fontWeight: s.selectedCampus.isEmpty
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
          for (final name in names)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, name),
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: s.selectedCampus == name
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _controller.selectCampus(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      // ⚠️ 必须监听 state（唯一 Listenable），监听 controller 收不到通知
      child: ListenableBuilder(
        listenable: _controller.state,
        builder: (context, _) {
          final s = _controller.state;
          // ⚠️ viewPadding 而非 padding：全局沉浸式下 padding.top 恒为 0
          final topPad = MediaQuery.viewPaddingOf(context).top + 44;

          Widget body;
          if (s.showBootstrapLoading || s.refreshing && s.items.isEmpty) {
            body = Padding(
              padding: EdgeInsets.only(top: topPad),
              child: const Center(child: CupertinoActivityIndicator()),
            );
          } else if (s.loadError != null && s.items.isEmpty) {
            body = _buildError(s.loadError!, topPad);
          } else {
            body = _buildList(s, topPad);
          }

          return DefaultTextStyle(
            style: TextStyle(
              decoration: TextDecoration.none,
              color: textPrimary(context),
            ),
            child: body,
          );
        },
      ),
    );
  }

  Widget _buildError(String msg, double topPad) {
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.cloud_download,
                size: 44, color: textHint(context)),
            const SizedBox(height: 12),
            Text(msg,
                style: TextStyle(fontSize: 14, color: textSecondary(context))),
            const SizedBox(height: 16),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: kOrderRatingColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              onPressed: () => _controller.load(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(OrderQrcodeState s, double topPad) {
    final visible = s.visibleItems;
    final grouped = s.selectedCampus.isEmpty ? s.groupByCampus() : null;
    final bottomInset = systemBottomInset(context);

    return RefreshIndicator(
      onRefresh: () => _controller.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 32 + bottomInset),
        children: [
          // ── 标题行 ──
          Row(
            children: [
              Expanded(
                child: Text(
                  '点餐码',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary(context),
                    letterSpacing: -0.4,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              _CampusChip(
                label: s.selectedCampus.isEmpty ? '全部校区' : s.selectedCampus,
                onTap: _pickCampus,
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _openSubmit,
                child: const Icon(CupertinoIcons.add_circled_solid, size: 26),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── 工具栏（搜索 + 我的 + 分类）──
          _buildToolbar(s),
          const SizedBox(height: 12),
          // ── 列表 ──
          if (visible.isEmpty && s.initialLoadComplete)
            const OrderEmptyState()
          else if (grouped != null)
            for (final entry in grouped.entries) ...[
              OrderGroupHeader(title: entry.key, count: entry.value.length),
              for (final item in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OrderShopTile(
                    item: item,
                    onTap: () => _openDetail(item),
                  ),
                ),
            ]
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrderShopTile(item: item, onTap: () => _openDetail(item)),
              ),
        ],
      ),
    );
  }

  Widget _buildToolbar(OrderQrcodeState s) {
    final secondary = textSecondary(context);
    final fieldBorder = solidHairline(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: solidSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fieldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: textHint(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.search, size: 18, color: secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _searchCtrl,
                          placeholder: '搜索商家',
                          placeholderStyle:
                              TextStyle(fontSize: 16, color: secondary),
                          style: TextStyle(
                              fontSize: 16, color: textPrimary(context)),
                          decoration: null,
                          padding: EdgeInsets.zero,
                          clearButtonMode: OverlayVisibilityMode.never,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _onSearchChanged,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _searchCtrl,
                        builder: (context, _) {
                          if (_searchCtrl.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: _clearSearch,
                            child: Icon(CupertinoIcons.clear_circled_solid,
                                size: 20, color: secondary),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openMy,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: textHint(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorder, width: 1),
                  ),
                  child: Text(
                    '我的',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kOrderRatingColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (s.categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            _CategoryTabs(
              categories: s.categories,
              selected: s.selectedCategory,
              onSelected: (c) => _controller.selectCategory(c),
            ),
          ],
        ],
      ),
    );
  }
}

/// 标题栏校区筛选 chip
class _CampusChip extends StatelessWidget {
  const _CampusChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: solidSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: solidHairline(context), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary(context),
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 2),
            Icon(CupertinoIcons.chevron_down,
                size: 12, color: textSecondary(context)),
          ],
        ),
      ),
    );
  }
}

/// 分类横向选择器（与 BingoApp `_OrderQrcodeCategoryTabs` 同构：
/// 选中项放大加粗 + 下方指示条）
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<OrderCategoryGroup> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = textPrimary(context);
    final keys = <String>['', ...categories.map((c) => c.category)];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (_, index) {
          final key = keys[index];
          final label = key.isEmpty ? '全部' : key;
          final active = key == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(key),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: active ? 18 : 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? primary : primary.withValues(alpha: 0.55),
                decoration: TextDecoration.none,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 18,
                      height: 2,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
