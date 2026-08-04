import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/data_cache.dart';
import '../core/navigation.dart';
import 'race.dart';
import 'race_service.dart';
import 'my_race_detail_page.dart';

/// 我的竞赛页面（listMyRacePage）
class MyRacePage extends StatefulWidget {
  final SharedHttpClient client;

  /// 嵌入模式：作为 Tab 内容时隐藏自身 Scaffold/AppBar，仅渲染列表主体
  final bool embedded;

  const MyRacePage({super.key, required this.client, this.embedded = false});

  @override
  State<MyRacePage> createState() => _MyRacePageState();
}

class _MyRacePageState extends State<MyRacePage> {
  late final RaceService _service;

  List<MyRaceItem> _list = [];
  bool _isLoading = true;
  String? _error;

  /// 自愈失败（会话过期且无法自动重登）时引导用户重新登录
  bool _loginRequired = false;

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

  Future<void> _loadData({bool force = false}) async {
    // 缓存优先：非强制刷新且有缓存 → 秒开旧数据，后台静默刷新
    if (!force) {
      final cached = _service.cachedMyRaces();
      if (cached != null && cached.list.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _list = cached.list;
          _currentPage = cached.currPage;
          _totalPage = cached.totalPage;
          _totalCount = cached.totalCount;
          _isLoading = false;
          _error = null;
        });
        _refreshSilently();
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchMyRaces(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
        _totalCount = result.totalCount;
        _isLoading = false;
        _loginRequired = false;
      });
    } catch (e) {
      // 如果未登录，自动引导登录
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) {
        await _tryBootstrap();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = msg.replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// 后台静默刷新：成功则更新列表，失败静默保留缓存数据
  Future<void> _refreshSilently() async {
    try {
      final result = await _service.fetchMyRaces(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
        _totalCount = result.totalCount;
      });
    } catch (_) {
      // 静默失败：保留缓存展示
    }
  }

  /// 引导登录 scjx2，成功后重试加载
  Future<void> _tryBootstrap() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ok = await _service.bootstrapLogin();
      if (!mounted) return;
      if (ok) {
        // 登录成功，重新加载（强制走网络，拿到最新数据）
        await _loadData(force: true);
      } else {
        setState(() {
          _error = '登录已过期，请重新登录后再试';
          _isLoading = false;
          _loginRequired = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '引导登录失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.fetchMyRaces(page: _currentPage + 1);
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
    final body = _buildBody();
    // 嵌入模式（Tab 内容）不渲染自身 Scaffold/AppBar，避免嵌套标题栏
    if (widget.embedded) return body;
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_totalCount > 0 ? '我的竞赛 ($_totalCount)' : '我的竞赛'),
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
        body: body,
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
              if (_loginRequired) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => pushAndClear(context, const LoginPage()),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('重新登录'),
                ),
              ],
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
            Icon(Icons.emoji_events_outlined,
                size: 64, color: Colors.amber.shade300),
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

  Widget _buildRaceCard(MyRaceItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(item),
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
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.workspaces_outline,
                        item.raceSubName.isNotEmpty ? item.raceSubName : '—'),
                    const SizedBox(height: 2),
                    _buildInfoRow(Icons.business_outlined,
                        item.raceDepName.isNotEmpty ? item.raceDepName : '—'),
                    const SizedBox(height: 4),
                    _buildMetaRow(item),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStateTag(item.stateName),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right, color: textHint(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 学年 + 团队标记行
  Widget _buildMetaRow(MyRaceItem item) {
    final pieces = <String>[
      if (item.yearterm.isNotEmpty) item.yearterm,
      if (item.isteam == 1) '团队' else '个人',
    ];
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 13, color: textHint(context)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(pieces.join(' · '),
              style: TextStyle(fontSize: 12, color: textHint(context)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// 审核状态标签（按状态着色）
  Widget _buildStateTag(String stateName) {
    if (stateName.isEmpty) return const SizedBox.shrink();
    final color = _stateColor(stateName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(stateName,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  /// 状态 → 颜色：通过=绿 / 驳回=红 / 审核中=橙 / 其他=蓝
  Color _stateColor(String stateName) {
    if (stateName.contains('通过')) return Colors.green;
    if (stateName.contains('驳回') ||
        stateName.contains('不通过') ||
        stateName.contains('未通过')) {
      return const Color(0xFFC2410C);
    }
    if (stateName.contains('待审') || stateName.contains('审核中')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  void _openDetail(MyRaceItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyRaceDetailPage(
          client: widget.client,
          item: item,
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
