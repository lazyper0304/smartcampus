import 'package:flutter/material.dart';

import '../core/data_cache.dart';
import '../core/navigation.dart';
import '../news/webview_page.dart';
import 'employ_service.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


class EmployPage extends StatefulWidget {
  const EmployPage({super.key});

  @override
  State<EmployPage> createState() => _EmployPageState();
}

class _EmployPageState extends State<EmployPage> {
  late final EmployService _service;
  final List<EmployJob> _jobs = [];
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = EmployService();
    _loadPage();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_currentPage >= _totalPages || _isLoadingMore) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    if (max - current < 300) {
      _loadNextPage();
    }
  }

  Future<void> _loadPage({bool refresh = false}) async {
    setState(() {
      if (refresh) {
        _isLoading = true;
        _jobs.clear();
        _currentPage = 1;
      }
      _error = null;
    });
    try {
      final result = await _service.fetchPage(
        page: _currentPage,
        forceRefresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _jobs.addAll(result.jobs);
        _totalPages = result.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_currentPage >= _totalPages || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    try {
      final result = await _service.fetchPage(page: _currentPage);
      if (!mounted) return;
      setState(() {
        _jobs.addAll(result.jobs);
        _totalPages = result.totalPages;
        _isLoadingMore = false;
      });
    } catch (e) {
      _currentPage--;
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
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('就业信息'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadPage(refresh: true),
            ),
          ],
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
              ElevatedButton(
                onPressed: () {
                  DataCache().invalidateAll();
                  _loadPage(refresh: true);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_jobs.isEmpty) {
      return const Center(child: Text('暂无招聘信息'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        DataCache().invalidateAll();
        _currentPage = 1;
        _jobs.clear();
        await _loadPage(refresh: true);
      },
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _jobs.length + 1,
        itemBuilder: (context, index) {
          if (index == _jobs.length) {
            return _buildFooter();
          }
          return _buildCard(_jobs[index], index);
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_currentPage >= _totalPages) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('— 已显示全部 $_totalPages 页 —',
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

  Widget _buildCard(EmployJob job, int index) {
    return _DelayedFadeSlide(
      delay: Duration(milliseconds: (index % 10) * 30),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(job),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColorNotifier.value.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          job.salary.split('-').firstOrNull ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColorNotifier.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          _metaRow(Icons.business_rounded, job.company),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.grey[300]),
                  ],
                ),
                const SizedBox(height: 12),
                // 底部信息行
                Row(
                  children: [
                    _chip(Icons.monetization_on_outlined, job.salary,
                        accentColorNotifier.value),
                    const SizedBox(width: 8),
                    _chip(Icons.visibility_outlined, '${job.views}次浏览',
                        Colors.grey[600]!),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
}

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  void _openDetail(EmployJob job) {
    pushPage(
      context,
      WebViewPage(
        url: job.detailUrl,
        title: '职位详情',
      ),
    );
  }
}

class _DelayedFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _DelayedFadeSlide({required this.child, this.delay = Duration.zero});

  @override
  State<_DelayedFadeSlide> createState() => _DelayedFadeSlideState();
}

class _DelayedFadeSlideState extends State<_DelayedFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
