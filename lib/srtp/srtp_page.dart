import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/data_cache.dart';
import '../core/pill_tab_bar.dart';
import 'srtp.dart';
import 'srtp_service.dart';
import 'srtp_detail_page.dart';

/// 大学生创新创业训练计划（SRTP）主页
///
/// 双 Tab：我参与的项目（listIsMeJoinProjectsPage）/ 我申请的项目（listProjectProgressPage）
class SrtpPage extends StatefulWidget {
  final SharedHttpClient client;

  const SrtpPage({super.key, required this.client});

  @override
  State<SrtpPage> createState() => _SrtpPageState();
}

class _SrtpPageState extends State<SrtpPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // 监听 tab 变化以驱动药丸滑块
    _tabCtrl.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('创新创业'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: PillTabBar(
              controller: _tabCtrl,
              labels: const ['我参与的项目', '我申请的项目'],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _JoinedTab(client: widget.client),
            _AppliedTab(client: widget.client),
          ],
        ),
      ),
    );
  }
}

/// 我参与的项目（listIsMeJoinProjectsPage）
class _JoinedTab extends StatefulWidget {
  final SharedHttpClient client;

  const _JoinedTab({required this.client});

  @override
  State<_JoinedTab> createState() => _JoinedTabState();
}

class _JoinedTabState extends State<_JoinedTab>
    with AutomaticKeepAliveClientMixin {
  late final SrtpService _service;

  List<SrtpProjectItem> _list = [];
  bool _isLoading = true;
  String? _error;

  int _currentPage = 1;
  int _totalPage = 1;
  bool _isLoadingMore = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _service = SrtpService(client: widget.client);
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
      final result = await _service.fetchMyJoinedProjects(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
        _isLoading = false;
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
        await _loadData();
      } else {
        setState(() {
          _error = 'scjx2 登录失败，请前往 WebView 登录后再试';
          _isLoading = false;
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
          await _service.fetchMyJoinedProjects(page: _currentPage + 1);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError(context, _error!, onRetry: _loadData);
    }
    if (_list.isEmpty) {
      return _buildEmpty(context, Icons.rocket_launch_outlined, '暂无参与的项目',
          Colors.indigo.shade300);
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
          return _buildJoinedCard(_list[index]);
        },
      ),
    );
  }

  Widget _buildJoinedCard(SrtpProjectItem item) {
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
              const _ProjectIcon(),
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
                    if (item.subject.isNotEmpty)
                      _infoRow(context, Icons.school_outlined, item.subject),
                    const SizedBox(height: 2),
                    if (formatMidTime(item.midTime).isNotEmpty)
                      _infoRow(
                          context, Icons.event_outlined, formatMidTime(item.midTime)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SideTags(stage: item.stage, state: item.state),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(SrtpProjectItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SrtpDetailPage(
          client: widget.client,
          projectId: item.id,
          projectName: item.name,
          planName: item.subject,
          stage: item.stage,
          state: item.state,
        ),
      ),
    );
  }
}

/// 我申请的项目（listProjectProgressPage）
class _AppliedTab extends StatefulWidget {
  final SharedHttpClient client;

  const _AppliedTab({required this.client});

  @override
  State<_AppliedTab> createState() => _AppliedTabState();
}

class _AppliedTabState extends State<_AppliedTab>
    with AutomaticKeepAliveClientMixin {
  late final SrtpService _service;

  List<SrtpAppliedProjectItem> _list = [];
  bool _isLoading = true;
  String? _error;

  int _currentPage = 1;
  int _totalPage = 1;
  bool _isLoadingMore = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _service = SrtpService(client: widget.client);
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
      final result = await _service.fetchMyAppliedProjects(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _list = result.list;
        _currentPage = result.currPage;
        _totalPage = result.totalPage;
        _isLoading = false;
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
        await _loadData();
      } else {
        setState(() {
          _error = 'scjx2 登录失败，请前往 WebView 登录后再试';
          _isLoading = false;
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
          await _service.fetchMyAppliedProjects(page: _currentPage + 1);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError(context, _error!, onRetry: _loadData);
    }
    if (_list.isEmpty) {
      return _buildEmpty(context, Icons.rocket_launch_outlined, '暂无申请的项目',
          Colors.indigo.shade300);
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
          return _buildAppliedCard(_list[index]);
        },
      ),
    );
  }

  Widget _buildAppliedCard(SrtpAppliedProjectItem item) {
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
              const _ProjectIcon(),
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
                    const SizedBox(height: 4),
                    if (item.stuName.isNotEmpty)
                      Text(
                        '负责人：${item.stuName}'
                        '${item.stuNo.isNotEmpty ? "（${item.stuNo}）" : ""}',
                        style: TextStyle(
                            fontSize: 12, color: textHint(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.summary,
                          style: TextStyle(
                              fontSize: 12, color: textHint(context)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (item.depName.isNotEmpty || item.applyDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(
                        context,
                        Icons.business_outlined,
                        [
                          if (item.depName.isNotEmpty) item.depName,
                          if (item.applyDate.isNotEmpty)
                            item.applyDate.substring(0, 10),
                        ].join(' · '),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SideTags(stage: item.stage, state: item.state),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(SrtpAppliedProjectItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SrtpDetailPage(
          client: widget.client,
          projectId: item.id,
          projectName: item.name,
          stage: item.stage,
          state: item.state,
          routePath: SrtpService.myProjectRoutePath,
        ),
      ),
    );
  }
}

// ==================== 共享组件 / 工具 ====================

/// 项目卡片左侧图标块
class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.rocket_launch_rounded,
          color: Colors.indigo.shade400, size: 22),
    );
  }
}

/// 卡片右侧：阶段标签 + 状态色点 + 箭头
class _SideTags extends StatelessWidget {
  final int stage;
  final int state;

  const _SideTags({required this.stage, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _stageTag(context, stage),
        const SizedBox(height: 6),
        _stateDot(context, state),
        const SizedBox(height: 6),
        Icon(Icons.chevron_right, color: textHint(context)),
      ],
    );
  }
}

/// 阶段标签：0=申报 / 1=中期 / 4=结题
Widget _stageTag(BuildContext context, int stage) {
  final (text, color) = switch (stage) {
    0 => ('申报', Colors.blue),
    1 => ('中期', Colors.orange),
    4 => ('结题', Colors.green),
    _ => ('阶段 $stage', Colors.blueGrey),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  );
}

/// 状态色点：-1=终止(红) / 0=申报中(橙) / 4=已结题(绿) / 其他=蓝
Widget _stateDot(BuildContext context, int state) {
  final (text, color) = switch (state) {
    -1 => ('已终止', Colors.red),
    0 => ('申报中', Colors.orange),
    4 => ('已结题', Colors.green),
    _ => ('状态 $state', Colors.blue),
  };
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: textHint(context))),
    ],
  );
}

/// mid_time "start,end" → "中期：start ~ end"（截日期部分）
String formatMidTime(String midTime) {
  if (midTime.isEmpty) return '';
  final parts = midTime.split(',');
  if (parts.length < 2) return '';
  String cut(String s) => s.length > 10 ? s.substring(0, 10) : s;
  return '中期：${cut(parts[0])} ~ ${cut(parts[1])}';
}

/// 错误态（图标 + 文字 + 重试）
Widget _buildError(BuildContext context, String error,
    {required VoidCallback onRetry}) {
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
          Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textHint(context))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              DataCache().invalidateAll();
              onRetry();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}

/// 空态
Widget _buildEmpty(
    BuildContext context, IconData icon, String text, Color color) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 12),
        Text(text,
            style: TextStyle(fontSize: 15, color: textHint(context))),
      ],
    ),
  );
}

/// 信息行（小图标 + 次要文字）
Widget _infoRow(BuildContext context, IconData icon, String text) {
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
