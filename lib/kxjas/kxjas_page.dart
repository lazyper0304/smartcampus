import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/smooth_styles.dart';
import '../core/glass_filter_chip.dart';
import '../core/glass_action_button.dart';
import '../main.dart';
import 'kxjas.dart';
import 'kxjas_service.dart';

/// 空闲教室查询页面
///
/// 查询条件：星期（周一~周日 chips）+ 周次 + 教学楼（可选），
/// 数据来自 ehall jwapp「空闲教室」（kxjas 模块）：
/// - 教学楼列表：jxlcx.do
/// - 空闲教室：cxjsqk.do（实时查询，分页无限滚动）
class KxjasPage extends StatefulWidget {
  final SharedHttpClient client;

  const KxjasPage({super.key, required this.client});

  @override
  State<KxjasPage> createState() => _KxjasPageState();
}

class _KxjasPageState extends State<KxjasPage> {
  static const List<String> _weekdayNames = [
    '周一', '周二', '周三', '周四', '周五', '周六', '周日',
  ];

  late final KxjasService _service;

  /// 当前学期只读展示文案：如 "2025-2026 学年 第 2 学期"
  String get _semesterText {
    final parts = _service.defaultXnxqdm.split('-');
    if (parts.length >= 3) {
      return '${parts[0]}-${parts[1]} 学年 第 ${parts[2]} 学期';
    }
    return _service.defaultXnxqdm;
  }

  // ---- 查询条件 ----
  int _day = DateTime.now().weekday; // 1=周一 .. 7=周日，默认今天
  String _week = '1'; // 教学周次
  String _jxldm = ''; // '' = 全部教学楼
  int _period = 0; // 0 = 全部节次（大节）
  List<KxjasBuilding> _buildings = [];
  List<KxjasPeriod> _periods = [];

  // ---- 列表态 ----
  List<KxjasClassroom> _list = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalSize = 0;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = KxjasService(client: widget.client);
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  /// 首载：当前周次 + 教学楼列表 + 大节列表，然后自动查询第一页
  Future<void> _init() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchCurrentWeek(),
        _service.fetchBuildings(),
        _service.fetchPeriods(),
      ]);
      final week = results[0] as int;
      final buildings = results[1] as List<KxjasBuilding>;
      final periods = results[2] as List<KxjasPeriod>;
      if (!mounted) return;
      setState(() {
        _week = week.toString();
        _buildings = buildings;
        _periods = periods;
      });
      await _loadFirstPage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchFreeClassrooms(
        week: int.tryParse(_week) ?? 1,
        day: _day,
        jxldm: _jxldm,
        period: _period,
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
      final result = await _service.fetchFreeClassrooms(
        week: int.tryParse(_week) ?? 1,
        day: _day,
        jxldm: _jxldm,
        period: _period,
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
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// 下拉刷新 / AppBar 刷新：刷新教学楼 + 大节 + 教室数据（不打断列表）
  Future<void> _onRefresh() async {
    try {
      final results = await Future.wait([
        _service.fetchBuildings(forceRefresh: true),
        _service.fetchPeriods(forceRefresh: true),
        _service.fetchFreeClassrooms(
          week: int.tryParse(_week) ?? 1,
          day: _day,
          jxldm: _jxldm,
          period: _period,
          pageNumber: 1,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _buildings = results[0] as List<KxjasBuilding>;
        _periods = results[1] as List<KxjasPeriod>;
        final r = results[2] as KxjasPageResult;
        _list = r.rows;
        _currentPage = 1;
        _totalSize = r.totalSize;
      });
    } catch (_) {}
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('空闲教室'),
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
            _buildFilterBar(),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ==================== 筛选区 ====================

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 当前学期（只读展示，不可选择）
          Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 14, color: textHint(context)),
              const SizedBox(width: 6),
              Text('当前学期：$_semesterText',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            ],
          ),
          const SizedBox(height: 10),
          // 星期
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int d = 1; d <= 7; d++) _dayChip(d),
              ],
            ),
          ),
          if (_periods.isNotEmpty) ...[
            const SizedBox(height: 8),
            // 大节（节次时段）
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _periodChip(0, '全部节次'),
                  for (final p in _periods) _periodChip(p.dj, p.displayName),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // 周次 + 教学楼
          Row(
            children: [
              Expanded(
                child: SmoothSelect<String>(
                  value: _week,
                  hint: Text('选择周次',
                      style: TextStyle(
                          color: accentColorNotifier.value
                              .withValues(alpha: 0.4))),
                  // 玻璃化：背景同色填充（公共 smoothGlassStyle）
                  style: smoothGlassStyle(context),
                  highlight: smoothHighlight(context),
                  menuMaxHeight: 300,
                  items: [
                    for (int w = 1; w <= 25; w++)
                      SmoothSelectItem<String>(
                        value: '$w',
                        child: Text('第 $w 周',
                            style: TextStyle(color: textPrimary(context))),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _week = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SmoothSelect<String>(
                  value: _jxldm,
                  hint: Text('选择教学楼',
                      style: TextStyle(
                          color: accentColorNotifier.value
                              .withValues(alpha: 0.4))),
                  // 玻璃化：背景同色填充（公共 smoothGlassStyle）
                  style: smoothGlassStyle(context),
                  highlight: smoothHighlight(context),
                  menuMaxHeight: 300,
                  items: [
                    SmoothSelectItem<String>(
                      value: '',
                      child: Text('全部教学楼',
                          style: TextStyle(color: textPrimary(context))),
                    ),
                    for (final b in _buildings)
                      SmoothSelectItem<String>(
                        value: b.jxldm,
                        child: Text(b.displayName,
                            style: TextStyle(color: textPrimary(context))),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _jxldm = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 查询按钮：玻璃操作按钮（GlassActionButton）
          GlassActionButton(
            label: _isLoading ? '查询中…' : '查询空闲教室',
            icon: Icons.search,
            loading: _isLoading,
            onPressed: _isLoading ? null : _loadFirstPage,
          ),
        ],
      ),
    );
  }

  Widget _dayChip(int day) {
    final selected = _day == day;
    // 玻璃筛选按钮（GlassFilterChip）
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassFilterChip(
        label: _weekdayNames[day - 1],
        selected: selected,
        onTap: () => setState(() => _day = day),
        fontSize: 13,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),
    );
  }

  Widget _periodChip(int dj, String label) {
    final selected = _period == dj;
    // 玻璃筛选按钮（GlassFilterChip）
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassFilterChip(
        label: label,
        selected: selected,
        onTap: () => setState(() => _period = dj),
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
            Icon(Icons.meeting_room_outlined,
                size: 64, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text('该时段暂无空闲教室',
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
          return _buildClassroomCard(_list[index]);
        },
      ),
    );
  }

  Widget _buildClassroomCard(KxjasClassroom c) {
    final isLab = c.jaslxdm.contains('实验') ||
        c.jaslxDisplay.contains('实验');
    final infoParts = <String>[
      if (c.jaslxDisplay.isNotEmpty) c.jaslxDisplay,
      if (c.lc.isNotEmpty) '${c.lc}层',
      c.seatText,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLab
                    ? Icons.science_rounded
                    : Icons.meeting_room_rounded,
                color: Colors.green.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.jasmc,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(infoParts.join(' · '),
                      style: TextStyle(fontSize: 12, color: textHint(context))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('空闲',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
