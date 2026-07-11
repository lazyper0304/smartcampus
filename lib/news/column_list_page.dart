import 'package:flutter/material.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/data_cache.dart';
import 'news.dart';
import 'column_service.dart';
import 'news_detail_page.dart';
import 'webview_page.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class ColumnListPage extends StatefulWidget {
  final String title;
  final String columnId;
  final String firstPageUrl;

  const ColumnListPage({
    super.key,
    required this.title,
    required this.columnId,
    required this.firstPageUrl,
  });

  @override
  State<ColumnListPage> createState() => _ColumnListPageState();
}

class _ColumnListPageState extends State<ColumnListPage> {
  late final ColumnService _service;
  final List<NewsItem> _items = [];
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextPageUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = ColumnService(
      columnId: widget.columnId,
      firstPageUrl: widget.firstPageUrl,
    );
    _loadFirstPage();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_nextPageUrl == null || _isLoadingMore) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    if (max - current < 300) {
      _loadNextPage();
    }
  }

  void _checkLoadMore() {
    if (_nextPageUrl == null || _isLoadingMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final pixels = _scrollCtrl.position.pixels;
      if (max - pixels < 300) {
        _loadNextPage();
      }
    });
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _items.clear();
    });
    try {
      final result = await _service.fetchPage();
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextPageUrl = result.nextPageUrl;
        _isLoading = false;
      });
      _checkLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_nextPageUrl == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.fetchPage(url: _nextPageUrl);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextPageUrl = result.nextPageUrl;
        _isLoadingMore = false;
      });
      _checkLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载更多失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
              ElevatedButton(onPressed: () { DataCache().invalidateAll(); _loadFirstPage(); }, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }
    return RefreshIndicator(
      onRefresh: () { DataCache().invalidateAll(); return _loadFirstPage(); },
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _items.length + (_nextPageUrl != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return _buildLoadMoreIndicator();
          }
          return _buildCard(_items[index], index);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_isLoadingMore && _nextPageUrl == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('— 已显示全部 —',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox(height: 24),
      ),
    );
  }

  Widget _buildCard(NewsItem item, int index) {
    return Cue.onMount(
      motion: .smooth(),
      child: Actor(
        delay: Duration(milliseconds: (index % 10) * 30),
        acts: [.fadeIn(), .slideY(from: 0.08)],
        child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _yibinBlue,
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
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: Colors.grey[300]),
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
    ),
  );
}

  Future<void> _openDetail(NewsItem item) async {
    // 外部链接（非 yibinu.edu.cn）→ 用 WebView 打开
    final urlHost = Uri.tryParse(item.url)?.host ?? '';
    if (urlHost.isNotEmpty && !urlHost.contains('yibinu.edu.cn')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebViewPage(
            url: item.url,
            title: '${widget.title}详情',
          ),
        ),
      );
      return;
    }

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
      final detail = await _service.fetchDetail(item.url);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailPage(detail: detail),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }
}
