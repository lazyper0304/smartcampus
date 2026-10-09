import 'package:flutter/foundation.dart';

import 'order_qrcode_model.dart';
import 'order_qrcode_service.dart';

/// 点餐码列表状态。
///
/// 参考工程是 Riverpod `StateNotifier`；本项目无 Riverpod，
/// 改用 `ChangeNotifier` + `ListenableBuilder`（状态语义保持一致）。
/// ⚠️ 页面必须监听 **本对象**（而不是 Controller）。
class OrderQrcodeState extends ChangeNotifier {
  List<OrderQRCode> items = const [];
  List<OrderCampusGroup> campuses = const [];
  List<OrderCategoryGroup> categories = const [];

  /// 校区筛选（空 = 全部校区）
  String selectedCampus = '';

  /// 分类筛选（空 = 全部）
  String selectedCategory = '';

  /// 搜索关键字
  String keyword = '';

  /// 首次加载完成（用于区分「还在转」与「转完了但空」）
  bool initialLoadComplete = false;

  /// 正在刷新（空列表时的阻塞加载）
  bool refreshing = false;

  /// 无数据时的致命错误；已有数据时静默失败不覆盖
  String? loadError;

  bool get hasData => items.isNotEmpty || campuses.isNotEmpty || categories.isNotEmpty;

  bool get showBootstrapLoading => !hasData && !initialLoadComplete;

  /// 当前筛选下的可见条目（校区在客户端二次过滤，后端 campus 参数可能有延迟）
  List<OrderQRCode> get visibleItems {
    if (selectedCampus.isEmpty) return items;
    return items.where((e) => e.campus == selectedCampus).toList(growable: false);
  }

  /// 按校区分组（未选校区时用于分组展示）
  Map<String, List<OrderQRCode>> groupByCampus() {
    final map = <String, List<OrderQRCode>>{};
    for (final it in visibleItems) {
      final key = it.campus.isEmpty ? '其他校区' : it.campus;
      map.putIfAbsent(key, () => []).add(it);
    }
    return map;
  }

  void setMeta({
    List<OrderCampusGroup>? campuses,
    List<OrderCategoryGroup>? categories,
  }) {
    if (campuses != null) this.campuses = campuses;
    if (categories != null) this.categories = categories;
    notifyListeners();
  }

  void setItems(List<OrderQRCode> v) {
    items = v;
    notifyListeners();
  }

  void setLoading({bool? refreshing}) {
    if (refreshing != null) this.refreshing = refreshing;
    notifyListeners();
  }

  void setInitialLoadComplete() {
    if (initialLoadComplete) return;
    initialLoadComplete = true;
    notifyListeners();
  }

  void setLoadError(String? v) {
    loadError = v;
    notifyListeners();
  }

  void setFilter({String? campus, String? category, String? keyword}) {
    if (campus != null) selectedCampus = campus;
    if (category != null) selectedCategory = category;
    if (keyword != null) this.keyword = keyword;
    notifyListeners();
  }
}

/// 点餐码列表控制器。
///
/// ⚠️ 本类**不是** `ChangeNotifier`：通知统一由 [OrderQrcodeState] 发出
/// （与一卡通模块同构，避免出现两个通知源导致页面收不到刷新）。
class OrderQrcodeController {
  OrderQrcodeController({OrderQrcodeService? service, OrderQrcodeState? state})
      : _service = service ?? OrderQrcodeService.instance,
        _state = state ?? OrderQrcodeState(),
        _ownsState = state == null;

  final OrderQrcodeService _service;
  final OrderQrcodeState _state;
  final bool _ownsState;
  bool _disposed = false;

  OrderQrcodeState get state => _state;

  /// 加载列表。
  ///
  /// [silent] 为 true 时失败不覆盖已有数据（下拉刷新 / 切筛选后的补全请求）。
  /// 校区与分类元数据只在为空时拉取一次，之后沿用（与参考工程一致）。
  Future<void> load({bool silent = false}) async {
    final effectiveSilent = silent || _state.hasData;
    if (_state.items.isEmpty && !_state.initialLoadComplete) {
      _state.setLoading(refreshing: true);
    }
    _state.setLoadError(null);

    try {
      if (_state.campuses.isEmpty || _state.categories.isEmpty) {
        final results = await Future.wait([
          _service.campuses(),
          _service.categories(),
        ]);
        if (_disposed) return;
        _state.setMeta(
          campuses: results[0] as List<OrderCampusGroup>,
          categories: results[1] as List<OrderCategoryGroup>,
        );
      }

      final items = await _service.list(
        campus: _state.selectedCampus,
        category: _state.selectedCategory,
        q: _state.keyword.trim(),
      );
      if (_disposed) return;
      _state.setItems(items);
    } catch (e) {
      if (_disposed) return;
      debugPrint('[OrderQrcode] load失败: $e');
      if (!effectiveSilent && _state.items.isEmpty) {
        _state.setLoadError('数据获取失败，请稍后重试');
      }
    } finally {
      if (!_disposed) {
        _state.setLoading(refreshing: false);
        _state.setInitialLoadComplete();
      }
    }
  }

  /// 下拉刷新
  Future<void> refresh() => load(silent: _state.items.isNotEmpty);

  /// 切换分类（'' = 全部）
  Future<void> selectCategory(String category) async {
    if (_state.selectedCategory == category) return;
    _state.setFilter(category: category);
    await load(silent: true);
  }

  /// 切换校区（'' = 全部）
  Future<void> selectCampus(String campus) async {
    if (_state.selectedCampus == campus) return;
    _state.setFilter(campus: campus);
    await load(silent: true);
  }

  /// 搜索（防抖由页面侧控制）
  Future<void> setKeyword(String keyword) async {
    if (_state.keyword == keyword) return;
    _state.setFilter(keyword: keyword);
    await load(silent: true);
  }

  void dispose() {
    _disposed = true;
    if (_ownsState) _state.dispose();
  }
}
