import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ecard_model.dart';
import 'ecard_service.dart';

/// 一卡通页面状态。
///
/// 参考工程用 Riverpod `StateNotifier`，本项目无 Riverpod，
/// 改用 `ChangeNotifier` + `ListenableBuilder`（保持同样的状态语义）。
class EcardState extends ChangeNotifier {
  /// 分页每页条数
  static const int pageSize = 20;

  EcardOverview? overview;
  List<EcardTransaction> transactions = const [];
  int total = 0;

  /// 当前已加载到第几页
  int listPage = 1;

  /// 后端正在同步一卡通数据（true 时继续轮询）
  bool syncing = false;

  /// 正在加载更多
  bool loadingMore = false;

  /// 首次加载完成（不论成败；用于区分「还在转」与「转完了但空」）
  bool initialLoadComplete = false;

  /// 无缓存时的致命错误；有缓存时失败只提示不换错误页
  String? loadError;

  /// 已有任何可展示数据
  bool get hasData => overview != null;

  /// 是否展示骨架/加载态
  bool get showBootstrapLoading => !hasData && (!initialLoadComplete || syncing);

  bool get hasMore => transactions.length < total;

  /// 卡面目录状态
  EcardCardFaceCatalog cardFaces = const EcardCardFaceCatalog(faces: [], selectedId: 0, displayId: 0);

  /// 卡面本地文件路径（faceId -> path）
  final Map<int, String> cardFacePaths = {};

  bool cardFaceLoading = false;

  void setOverview(EcardOverview? v) {
    overview = v;
    notifyListeners();
  }

  void setTransactions(List<EcardTransaction> v, int totalValue, int page) {
    transactions = v;
    total = totalValue;
    listPage = page;
    notifyListeners();
  }

  void setSyncing(bool v) {
    if (syncing == v) return;
    syncing = v;
    notifyListeners();
  }

  void setLoadingMore(bool v) {
    if (loadingMore == v) return;
    loadingMore = v;
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

  void setCardFaces(EcardCardFaceCatalog v) {
    cardFaces = v;
    notifyListeners();
  }

  void setCardFaceLoading(bool v) {
    if (cardFaceLoading == v) return;
    cardFaceLoading = v;
    notifyListeners();
  }

  void setCardFacePath(int faceId, String path) {
    cardFacePaths[faceId] = path;
    notifyListeners();
  }
}

/// 一卡通控制器：串起服务层、缓存与轮询。
/// ⚠️ **本类不是 `ChangeNotifier`**：状态变更通知由 [EcardState]（它才是
/// `ChangeNotifier`）发出。页面必须 `ListenableBuilder(listenable: controller.state)`；
/// 若监听 controller 本身会收不到通知，页面永远停在首帧加载态。
/// 之所以不直接让 Controller 继承 ChangeNotifier，是为了让「可变状态」只有
/// 一个 Listenable，避免出现两个通知源。
///
/// 关键行为：
/// - **首屏即注入本地快照**（在 `load()` 首行 await `readSnapshot()`），
///   避免冷启动白屏；因本项目 `LocalStorage` 全异步，无法在构造函数同步读取，
///   故由页面在首帧后调用 `load()` 完成注入，页面本身有骨架态兜底；
/// - 后端 `syncing=true` 时每 2.5s 轮询一次，同步完成即停，**上限 10 次**；
/// - 同步刚完成且用户已翻页时，补齐全部已加载页，避免分页错位；
/// - 静默刷新失败只保留已有数据，不把已展示内容换成错误页。
class EcardController {
  EcardController({EcardService? service, EcardState? state})
      : _service = service ?? EcardService.instance,
        _state = state ?? EcardState(),
        _ownsState = state == null;

  /// 同步轮询上限（2.5s 一次，约 25s 后放弃并显示已有数据）
  static const int kEcardMaxPolls = 10;

  final EcardService _service;
  final EcardState _state;
  Timer? _pollTimer;
  int _pollCount = 0;
  bool _disposed = false;

  /// 本 Controller 是否是 state 的所有者（决定 dispose 时能否销毁它）
  final bool _ownsState;

  EcardState get state => _state;

  /// 供子页面复用同一份状态（避免各页各建 Controller 导致切换后互不知情）
  EcardController shareWith(EcardState sharedState) =>
      EcardController(service: _service, state: sharedState);

  /// 首屏加载：注入缓存 → 并发拉概览与列表 → 必要时轮询
  ///
  /// [manualRefresh] 为 true 时才会带 `refresh=1` 触发服务端真实同步
  /// （用户主动点刷新按钮）；常规加载/静默刷新都不带。
  Future<void> load({bool silent = false, bool manualRefresh = false}) async {
    // ① 注入本地快照（冷启动首帧即可显示）
    if (_state.transactions.isEmpty && _state.overview == null) {
      final snap = await _service.readSnapshot();
      if (_disposed) return;
      if (!snap.isEmpty) {
        _state.setOverview(snap.overview);
        _state.setTransactions(
          snap.transactions,
          snap.total,
          snap.transactions.isEmpty
              ? 1
              : ((snap.transactions.length + EcardState.pageSize - 1) ~/
                  EcardState.pageSize),
        );
      }
    }

    final effectiveSilent = silent || _state.hasData;
    final keepPagination = effectiveSilent && _state.listPage > 1;
    final fetchSize =
        keepPagination ? _state.listPage * EcardState.pageSize : EcardState.pageSize;

    final wasSyncing = _state.syncing;
    try {
      // ⚠️ **`refresh=1` 不能用于首屏 / 常规加载**：它会让后端触发一次真实
      // 一卡通同步，响应中 `syncing` 恒为 true；若客户端据此轮询，
      // 就会陷入「一直加载中」（实测：带 refresh=1 时 syncing 恒 true，
      // 不带则 false，数据完全一样）。
      // 参考工程也只在用户主动点刷新时才带 refresh。
      // 仅当「上次同步已结束、这次是用户手动刷新」时才强制同步。
      final forceRefresh = manualRefresh && !wasSyncing;
      final results = await Future.wait([
        _service.fetchOverview(refresh: forceRefresh),
        _service.fetchTransactions(
          page: 1,
          size: fetchSize,
          refresh: forceRefresh,
        ),
      ]);
      if (_disposed) return;
      final ov = results[0] as EcardOverview;
      final page = results[1] as EcardTransactionPage;
      final syncing = ov.syncing || page.syncing;

      // 同步刚完成且用户已翻页 → 补齐全部已加载页，防止第 2 页后数据错位
      if (wasSyncing && !syncing && _state.listPage > 1) {
        await refreshAfterSync();
        final ov2 = await _service.fetchOverview();
        if (_disposed) return;
        _state.setOverview(ov2);
        _state.setSyncing(false);
        _state.setLoadError(null);
        await _persist();
        return;
      }

      _state.setOverview(ov);
      _state.setTransactions(
        page.items,
        page.total,
        keepPagination ? _state.listPage : 1,
      );
      _state.setSyncing(syncing);
      _state.setLoadError(null);
      await _persist();
      _schedulePoll(syncing);
    } catch (e) {
      if (_disposed) return;
      debugPrint('[Ecard] load失败: $e');
      if (!effectiveSilent && !_state.hasData) {
        _state.setLoadError('数据获取失败，请稍后重试');
      }
    } finally {
      _state.setInitialLoadComplete();
    }
  }

  /// 加载更多（分页）
  Future<void> loadMore() async {
    if (_state.loadingMore || !_state.hasMore) return;
    _state.setLoadingMore(true);
    try {
      final next = _state.listPage + 1;
      final page = await _service.fetchTransactions(
        page: next,
        size: EcardState.pageSize,
      );
      if (_disposed) return;
      _state.setTransactions(
        [..._state.transactions, ...page.items],
        page.total,
        next,
      );
      // 不阻塞 UI
      unawaited(_persist());
    } catch (_) {
      // 静默失败：保留已有数据，滚动到底由页面停止触发
    } finally {
      _state.setLoadingMore(false);
    }
  }

  /// 同步完成后一次性拉齐已加载的页数
  Future<void> refreshAfterSync() async {
    if (_state.listPage <= 1) return;
    try {
      final page = await _service.fetchTransactions(
        page: 1,
        size: _state.listPage * EcardState.pageSize,
      );
      if (_disposed) return;
      _state.setTransactions(page.items, page.total, _state.listPage);
      await _persist();
    } catch (_) {
      // 静默
    }
  }

  /// 同步中则继续轮询，**但有次数上限**（防止后端一直返回 syncing=true
  /// 导致页面永远停在加载态）。
  void _schedulePoll(bool syncing) {
    _pollTimer?.cancel();
    if (!syncing) {
      _pollCount = 0;
      return;
    }
    if (_pollCount >= kEcardMaxPolls) {
      debugPrint('[Ecard] 同步轮询已达上限 $kEcardMaxPolls 次，停止轮询');
      _state.setSyncing(false);
      return;
    }
    _pollCount++;
    debugPrint('[Ecard] 同步中，第 $_pollCount/$kEcardMaxPolls 次轮询');
    _pollTimer = Timer(
      const Duration(milliseconds: 2500),
      () {
        if (_disposed) return;
        load(silent: true);
      },
    );
  }

  Future<void> _persist() async {
    if (_disposed) return;
    await _service.writeSnapshot(EcardSnapshot(
      overview: _state.overview,
      transactions: _state.transactions,
      total: _state.total,
    ));
  }

  // ── 卡面 ──

  /// 拉卡面目录并把已下载过的图对齐到本地路径
  Future<void> loadCardFaces() async {
    if (_disposed) return;
    _state.setCardFaceLoading(true);
    try {
      final catalog = await _service.fetchCardFaceCatalog();
      if (_disposed) return;
      _state.setCardFaces(catalog);

      // 已缓存的卡面直接回填，未缓存的下载
      //（`cardFaceDir()` 只取一次，避免每张卡面都调一遍 path_provider）
      final dir = await _service.cardFaceDir();
      for (final f in catalog.faces) {
        // id=0 是内置默认卡面，走 asset，无需下载
        if (f.id == 0) continue;
        final file = File(
            '${dir.path}/${EcardService.cardFaceFileName(f.id, f.md5)}');
        if (await file.exists()) {
          _state.setCardFacePath(f.id, file.path);
        } else {
          // ⚠️ 必须 await：否则切卡面时图片还没落盘，主页面拿不到本地路径
          await _downloadFace(f, dir);
        }
      }

      // 服务端推送的卡面：立即消费，使其正式生效
      final auto = catalog.autoApply;
      if (auto != null) {
        unawaited(_consumeAuto(auto.id));
      }
    } catch (e) {
      debugPrint('[Ecard] 卡面目录加载失败: $e');
    } finally {
      if (!_disposed) _state.setCardFaceLoading(false);
    }
  }

  Future<void> _downloadFace(EcardCardFaceMeta face, [Directory? dir0]) async {
    try {
      final bytes = await _service.downloadCardFace(face.id);
      final dir = dir0 ?? await _service.cardFaceDir();
      final file =
          File('${dir.path}/${EcardService.cardFaceFileName(face.id, face.md5)}');
      await file.writeAsBytes(bytes, flush: true);
      if (_disposed) return;
      _state.setCardFacePath(face.id, file.path);
    } catch (e) {
      debugPrint('[Ecard] 卡面 ${face.id} 下载失败: $e');
    }
  }

  Future<void> _consumeAuto(int faceId) async {
    try {
      await _service.consumeAutoCardFace(faceId);
    } catch (_) {
      // 消费失败不影响展示（服务端仍会下发同一张 autoApply）
    }
  }

  /// 选定卡面：先请求服务端成功再改本地状态，失败则不动
  Future<bool> selectCardFace(int faceId) async {
    try {
      await _service.selectCardFace(faceId);
      if (_disposed) return false;
      // ⚠️ 切换前确保图片已落盘：否则主页面立刻切过去却只有空白卡面
      // （id=0 走内置 asset，无需下载）
      if (faceId != 0 && _state.cardFacePaths[faceId] == null) {
        final face = _findFace(faceId);
        if (face != null) {
          await _downloadFace(face);
          if (_disposed) return false;
        }
      }
      _state.setCardFaces(EcardCardFaceCatalog(
        faces: _state.cardFaces.faces,
        selectedId: faceId,
        displayId: faceId,
      ));
      return true;
    } catch (e) {
      debugPrint('[Ecard] 卡面切换失败: $e');
      return false;
    }
  }

  EcardCardFaceMeta? _findFace(int id) {
    for (final f in _state.cardFaces.faces) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 释放轮询定时器（页面 dispose 时调用）
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    // `_ownsState` 为false 表示 state 由外层共享（如详情页复用主页面的 state），
    // 此时不能 dispose，否则主页面会失效
    if (_ownsState) _state.dispose();
  }
}