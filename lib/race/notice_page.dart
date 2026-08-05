import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/data_cache.dart';
import '../core/navigation.dart';
import '../core/simple_page.dart';
import 'notice.dart';
import 'race_service.dart';
import 'notice_detail_page.dart';

/// 公示公告列表页（scjx2 `/config/sys/baseNotice/listNoticeStuPage`）
///
/// [embedded] 为 true 时不渲染自身 SimplePage/Scaffold/AppBar，
/// 直接嵌入学科竞赛主页 TabBarView（与 MyRacePage 同范式）；
/// 独立使用时（embedded: false）自动带液态玻璃背景 + 标题栏。
class NoticePage extends StatefulWidget {
  final SharedHttpClient client;
  final bool embedded;

  const NoticePage({super.key, required this.client, this.embedded = true});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage>
    with AutomaticKeepAliveClientMixin {
  late final RaceService _service;

  List<RaceNotice> _list = [];
  bool _isLoading = true;
  String? _error;

  /// 自愈失败（会话过期且无法自动重登）时引导用户重新登录
  bool _loginRequired = false;

  int _currentPage = 1;
  int _totalPage = 1;
  bool _isLoadingMore = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

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
    // 缓存优先：非强制刷新且有缓存 → 秒开旧数据，后台静默刷新。
    if (!force) {
      final cached = _service.cachedNotices();
      if (cached != null && cached.list.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _list = cached.list;
          _currentPage = cached.currPage;
          _totalPage = cached.totalPage;
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
      final result = await _service.fetchNotices(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
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
      final result = await _service.fetchNotices(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
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
      final result =
          await _service.fetchNotices(page: _currentPage + 1, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list.addAll(result.list);
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
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
    super.build(context);
    final content = _buildBody();
    if (widget.embedded) return content;
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('公示公告'),
          centerTitle: true,
        ),
        body: content,
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
            Icon(Icons.campaign_outlined, size: 64,
                color: Colors.amber.shade300),
            const SizedBox(height: 12),
            Text('暂无公示公告',
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
          return _buildNoticeCard(_list[index]);
        },
      ),
    );
  }

  Widget _buildNoticeCard(RaceNotice notice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(notice),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.campaign_rounded,
                    color: Colors.orange.shade700, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.subject,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: textHint(context)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            notice.teacherName.isNotEmpty
                                ? notice.teacherName
                                : '教务处',
                            style: TextStyle(
                                fontSize: 12, color: textHint(context)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_rounded,
                            size: 14, color: textHint(context)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(notice.modifyTime,
                              style: TextStyle(
                                  fontSize: 12, color: textHint(context)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: textHint(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(RaceNotice notice) {
    // 统一 iOS 右滑转场（与全 App 二级页面一致）
    pushPage(
      context,
      NoticeDetailPage(
        client: widget.client,
        noticeId: notice.id,
        noticeSubject: notice.subject,
      ),
    );
  }
}
