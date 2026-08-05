import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/navigation.dart';
import '../core/glass_filter_chip.dart';
import '../core/glass_action_button.dart';
import '../main.dart';
import 'kccx.dart';
import 'kccx_service.dart';
import 'kccx_detail_page.dart';

/// 课程查询页面
///
/// 数据来自 ehall jwapp「课程查询」（kccx 模块，kcxxcx.do）：
/// - 支持按 课程名 / 课程号 搜索，按 考试类型 / 课程层次 筛选
/// - 默认仅查询启用状态的课程，分页无限滚动
class KccxPage extends StatefulWidget {
  final SharedHttpClient client;

  const KccxPage({super.key, required this.client});

  @override
  State<KccxPage> createState() => _KccxPageState();
}

class _KccxPageState extends State<KccxPage> {
  late final KccxService _service;

  // ---- 搜索条件 ----
  final TextEditingController _kcmCtrl = TextEditingController();
  final TextEditingController _kchCtrl = TextEditingController();
  String _kslxdm = ''; // '' = 全部考试类型
  String _kcccdm = ''; // '' = 全部课程层次

  // ---- 列表态 ----
  List<KccxCourse> _list = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalSize = 0;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = KccxService(client: widget.client);
    _scrollCtrl.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _kcmCtrl.dispose();
    _kchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  /// 提交搜索：收起键盘并重新查询第一页
  /// （键盘收起必须放在按钮/提交回调里，不能在 initState 调用链中执行）
  void _submitSearch() {
    FocusScope.of(context).unfocus();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchCourses(
        kcm: _kcmCtrl.text.trim(),
        kch: _kchCtrl.text.trim(),
        kslxdm: _kslxdm,
        kcccdm: _kcccdm,
        pageNumber: 1,
      );
      if (!mounted) return;
      setState(() {
        _list = result.rows;
        _currentPage = 1;
        _totalSize = result.totalSize;
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

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _list.length < _totalSize) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.fetchCourses(
        kcm: _kcmCtrl.text.trim(),
        kch: _kchCtrl.text.trim(),
        kslxdm: _kslxdm,
        kcccdm: _kcccdm,
        pageNumber: _currentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _list.addAll(result.rows);
        _currentPage = result.pageNumber;
        _totalSize = result.totalSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      // 加载更多失败：保留已加载列表，footer 显示"加载失败，点击重试"
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    try {
      final result = await _service.fetchCourses(
        kcm: _kcmCtrl.text.trim(),
        kch: _kchCtrl.text.trim(),
        kslxdm: _kslxdm,
        kcccdm: _kcccdm,
        pageNumber: 1,
      );
      if (!mounted) return;
      setState(() {
        _list = result.rows;
        _currentPage = 1;
        _totalSize = result.totalSize;
      });
    } catch (_) {}
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('课程查询'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
              tooltip: '刷新',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ==================== 搜索区 ====================

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 课程名 + 课程号
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kcmCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    hintText: '课程名',
                    prefixIcon: const Icon(Icons.menu_book_outlined, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    // fillColor 跟随全局 theme（静态玻璃半透明白）
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _kchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    hintText: '课程号',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    // fillColor 跟随全局 theme（静态玻璃半透明白）
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 考试类型
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('', '全部类型'),
                _filterChip('1', '考试'),
                _filterChip('2', '考查'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 课程层次
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip2('', '全部层次'),
                _filterChip2('01', '本科'),
                _filterChip2('02', '专科'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 查询按钮：玻璃操作按钮（GlassActionButton）
          GlassActionButton(
            label: _isLoading ? '查询中…' : '查询课程',
            icon: Icons.search,
            loading: _isLoading,
            onPressed: _isLoading ? null : _submitSearch,
          ),
        ],
      ),
    );
  }

  /// 考试类型筛选 chip
  Widget _filterChip(String value, String label) {
    final selected = _kslxdm == value;
    // 玻璃筛选按钮（GlassFilterChip）
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassFilterChip(
        label: label,
        selected: selected,
        onTap: () => setState(() => _kslxdm = value),
        radius: 14,
      ),
    );
  }

  /// 课程层次筛选 chip
  Widget _filterChip2(String value, String label) {
    final selected = _kcccdm == value;
    // 玻璃筛选按钮（GlassFilterChip）
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassFilterChip(
        label: label,
        selected: selected,
        onTap: () => setState(() => _kcccdm = value),
        radius: 14,
      ),
    );
  }

  // ==================== 列表区 ====================

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
              Text('查询失败',
                  style: TextStyle(fontSize: 16, color: textHint(context))),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textHint(context))),
              const SizedBox(height: 16),
              GlassActionButton(
                label: '重试',
                icon: Icons.refresh,
                onPressed: _loadFirstPage,
                secondary: true,
                fullWidth: false,
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
            Icon(Icons.search_off_rounded,
                size: 64, color: textHint(context).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('未找到相关课程',
                style: TextStyle(fontSize: 15, color: textHint(context))),
            const SizedBox(height: 4),
            Text('换个关键词或调整筛选条件试试',
                style: TextStyle(fontSize: 12, color: textHint(context))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _list.length + 1,
        itemBuilder: (context, index) {
          if (index == _list.length) {
            return _buildListFooter();
          }
          return _buildCourseCard(_list[index]);
        },
      ),
    );
  }

  /// 列表底部：分页进度 / 加载中 / 加载失败重试
  Widget _buildListFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_list.length < _totalSize) {
      // 未触底：提示还有更多（滚动自动加载下一页）
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('已加载 ${_list.length} / 共 $_totalSize 条 · 上滑加载更多',
              style: TextStyle(fontSize: 12, color: textHint(context))),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text('已加载全部 $_totalSize 条课程',
            style: TextStyle(fontSize: 12, color: textHint(context))),
      ),
    );
  }

  Widget _buildCourseCard(KccxCourse c) {
    final infoParts = <String>[
      if (c.kkdwDisplay.isNotEmpty) c.kkdwDisplay,
      if (c.kslxDisplay.isNotEmpty) c.kslxDisplay,
      if (c.kcccdmDisplay.isNotEmpty) c.kcccdmDisplay,
      if (c.kcfzr.isNotEmpty) '负责人：${c.kcfzr}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // 统一 iOS 右滑转场
          pushPage(
            context,
            KccxDetailPage(
              client: widget.client,
              kch: c.kch,
              initialTitle: c.kcm,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(c.kcm,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text('${c.xfText} · ${c.xsText}',
                      style: TextStyle(
                          fontSize: 12,
                          color: accentColorNotifier.value,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              if (c.kch.isNotEmpty)
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColorNotifier.value.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c.kch,
                          style: TextStyle(
                              fontSize: 11,
                              color: accentColorNotifier.value,
                              fontFamily: 'monospace')),
                    ),
                  ],
                ),
              if (infoParts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(infoParts.join(' · '),
                    style: TextStyle(fontSize: 12, color: textHint(context))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
