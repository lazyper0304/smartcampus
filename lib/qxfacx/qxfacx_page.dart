import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/navigation.dart';
import '../core/glass_filter_chip.dart';
import '../core/glass_action_button.dart';
import '../main.dart';
import 'qxfacx.dart';
import 'qxfacx_service.dart';
import 'qxfacx_detail_page.dart';

/// 全校方案查询页面（培养方案查询）
///
/// 数据来自 ehall jwapp「全校方案查询」（qxfacx 模块，qxpyfacx.do）：
/// - 默认仅查询已发布方案（FAZTDM=99），支持按方案名称搜索
/// - 排序与网页端一致：年级倒序、院系、专业
/// - 分页无限滚动 + 下拉刷新，点击进入方案详情
class QxFacxPage extends StatefulWidget {
  final SharedHttpClient client;

  const QxFacxPage({super.key, required this.client});

  @override
  State<QxFacxPage> createState() => _QxFacxPageState();
}

class _QxFacxPageState extends State<QxFacxPage> {
  late final QxFacxService _service;

  final TextEditingController _nameCtrl = TextEditingController();

  /// 年级分类（空串 = 全部），与网页端「点击年级分类」一致
  String _njd = '';

  /// 可选年级（当前 2026-2027 学年新生 2026 级，往前覆盖历届）
  static const List<String> _gradeOptions = [
    '2026',
    '2025',
    '2024',
    '2023',
    '2022',
    '2021',
  ];

  List<QxFacxPlan> _list = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalSize = 0;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = QxFacxService(client: widget.client);
    _scrollCtrl.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      final result = await _service.fetchPlans(
        njd: _njd,
        nameQuery: _nameCtrl.text.trim(),
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
      final result = await _service.fetchPlans(
        njd: _njd,
        nameQuery: _nameCtrl.text.trim(),
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
      // 加载更多失败：保留已加载列表
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadFirstPage();
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('全校方案'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildGradeFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  /// 顶部搜索栏：方案名称包含搜索
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                hintText: '搜索培养方案名称',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassActionButton(
            label: '查询',
            onPressed: _isLoading ? null : _submitSearch,
            fullWidth: false,
            height: 48,
            fontSize: 14,
          ),
        ],
      ),
    );
  }

  /// 年级分类 chips（全部 / 2026级 / ...）
  Widget _buildGradeFilter() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _gradeChip('全部', ''),
          for (final g in _gradeOptions) _gradeChip('$g级', g),
        ],
      ),
    );
  }

  Widget _gradeChip(String label, String value) {
    final selected = _njd == value;
    // 玻璃筛选按钮（GlassFilterChip）
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassFilterChip(
        label: label,
        selected: selected,
        onTap: () {
          if (_njd == value) return;
          setState(() => _njd = value);
          _loadFirstPage();
        },
        radius: 14,
        fontSize: 12.5,
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
            Icon(Icons.menu_book_outlined,
                size: 64, color: Colors.blue.shade300),
            const SizedBox(height: 12),
            Text('暂无培养方案',
                style: TextStyle(fontSize: 15, color: textHint(context))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _list.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildPlanCard(_list[index]);
        },
      ),
    );
  }

  Widget _buildPlanCard(QxFacxPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(plan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: Colors.blue.shade600, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        _metaLine(Icons.calendar_month_outlined,
                            plan.njdDisplay.isNotEmpty
                                ? plan.njdDisplay
                                : '年级 ${plan.njd}'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: textHint(context)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (plan.dwdmDisplay.isNotEmpty)
                    _tag(Icons.business_outlined, plan.dwdmDisplay),
                  if (plan.zydmDisplay.isNotEmpty)
                    _tag(Icons.school_outlined, plan.zydmDisplay),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.hourglass_bottom_rounded,
                      size: 13, color: textHint(context)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      [
                        if (plan.xdlxdmDisplay.isNotEmpty) plan.xdlxdmDisplay,
                        if (plan.xznx > 0) '${plan.xznx} 年制',
                        if (plan.zsyqxf > 0) '${_numText(plan.zsyqxf)} 学分',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: textHint(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: textHint(context)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: textHint(context)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColorNotifier.value),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: accentColorNotifier.value)),
        ],
      ),
    );
  }

  String _numText(double v) {
    return v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
  }

  void _openDetail(QxFacxPlan plan) {
    // 统一 iOS 右滑转场
    pushPage(
      context,
      QxFacxDetailPage(client: widget.client, plan: plan),
    );
  }
}
