import 'package:flutter/material.dart';

import '../core/data_cache.dart';
import '../core/navigation.dart';
import '../main.dart';
import 'office_detail_page.dart';
import 'office_file_preview_page.dart';
import 'office_models.dart';
import 'office_service.dart';

/// 办公网单栏目列表（支持分页：offset 每页 +20）
class OfficeListPage extends StatefulWidget {
  final int? bId; // 搜索模式下为 null
  final String? searchKeyword; // 非空表示搜索模式
  final String title;

  const OfficeListPage({
    super.key,
    this.bId,
    this.searchKeyword,
    required this.title,
  }) : assert(bId != null || searchKeyword != null,
            'bId 与 searchKeyword 必须二选一');

  @override
  State<OfficeListPage> createState() => _OfficeListPageState();
}

class _OfficeListPageState extends State<OfficeListPage> {
  final List<OfficeItem> _items = [];
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  int? _nextOffset;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_nextOffset == null || _loadingMore) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    if (max - current < 300) {
      _loadNextPage();
    }
  }

  void _checkLoadMore() {
    if (_nextOffset == null || _loadingMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final pixels = _scrollCtrl.position.pixels;
      if (max - pixels < 300) {
        _loadNextPage();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextOffset = null;
      _loadingMore = false;
    });
    try {
      final result = widget.searchKeyword != null
          ? await OfficeService().search(widget.searchKeyword!, offset: 0)
          : await OfficeService().fetchColumn(widget.bId!, offset: 0);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextOffset = result.nextOffset;
        _loading = false;
      });
      _checkLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_nextOffset == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = widget.searchKeyword != null
          ? await OfficeService().search(widget.searchKeyword!, offset: _nextOffset!)
          : await OfficeService().fetchColumn(widget.bId!, offset: _nextOffset!);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextOffset = result.nextOffset;
        _loadingMore = false;
      });
      _checkLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载更多失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        DataCache().invalidateAll();
        return _load();
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _items.length + (_nextOffset != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return _buildLoadMoreIndicator();
        }
        return _buildCard(_items[index], index);
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('— 加载更多 —',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ),
    );
  }

  Widget _buildCard(OfficeItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: accentColorNotifier.value.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColorNotifier.value,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(item.publishDate,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                          const Spacer(),
                          if (item.isFile)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.picture_as_pdf_rounded,
                                  size: 16,
                                  color: accentColorNotifier.value),
                            ),
                          Icon(
                            item.isFile
                                ? Icons.open_in_new_rounded
                                : Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.grey[300],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(OfficeItem item) async {
    // showdoc.asp 为直接返回的 PDF 文件流 → 走统一文件预览页
    if (item.isFile) {
      pushPage(
        context,
        OfficeFilePreviewPage(url: item.url, name: item.title),
      );
      return;
    }

    // detail.asp 文章 → 原生解析后展示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('加载中...'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final detail = await OfficeService().fetchDetail(item.url);
      if (!mounted) return;
      Navigator.of(context).pop();
      pushPage(context, OfficeDetailPage(detail: detail, title: item.title));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }
}
