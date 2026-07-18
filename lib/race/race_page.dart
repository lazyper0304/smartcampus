import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/data_cache.dart';
import 'race.dart';
import 'race_service.dart';

/// 学科竞赛页面
class RacePage extends StatefulWidget {
  final SharedHttpClient client;

  const RacePage({super.key, required this.client});

  @override
  State<RacePage> createState() => _RacePageState();
}

class _RacePageState extends State<RacePage> {
  late final RaceService _service;

  List<RaceCompetition> _list = [];
  bool _isLoading = true;
  String? _error;

  int _currentPage = 1;
  int _totalPage = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = RaceService(client: widget.client);
    _loadData();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage < _totalPage) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchCompetitions(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
        _totalCount = result.totalCount;
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

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.fetchCompetitions(page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _list.addAll(result.list);
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
        _totalCount = result.totalCount;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    DataCache().invalidateAll();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_totalCount > 0 ? '学科竞赛 ($_totalCount)' : '学科竞赛'),
          centerTitle: true,
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _onRefresh,
                tooltip: '刷新',
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
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text('加载失败',
                  style: TextStyle(fontSize: 16, color: textHint(context))),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textHint(context))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  DataCache().invalidateAll();
                  _loadData();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64,
                color: Colors.amber.shade300),
            const SizedBox(height: 12),
            Text('暂无竞赛记录',
                style: TextStyle(fontSize: 15, color: textHint(context))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _list.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildRaceCard(_list[index]);
        },
      ),
    );
  }

  Widget _buildRaceCard(RaceCompetition race) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  color: Colors.amber.shade600, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(race.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.person_outline, race.teacherName),
                  const SizedBox(height: 2),
                  _buildInfoRow(Icons.business_outlined, race.depName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: textHint(context)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: textHint(context)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
