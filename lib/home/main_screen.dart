import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/data_cache.dart';
import '../core/http_client.dart';
import '../settings/settings_page.dart';
import 'home_dashboard.dart';
import 'app_data.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

class MainScreen extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const MainScreen({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: Container(
        color: _isDark(context) ? const Color(0xFF1A1A2E) : const Color(0xFFF0F4FF),
      ),
      statusBarStyle: GlassStatusBarStyle.auto,
      contentAwareBrightness: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.12, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: [
          HomeDashboard(
            key: const ValueKey('home'),
            client: widget.client,
            userId: widget.userId,
          ),
          _AppsPage(
            key: const ValueKey('apps'),
            client: widget.client,
            userId: widget.userId,
          ),
          SettingsPage(key: const ValueKey('settings'), client: widget.client),
        ][_currentIndex],
      ),
      bottomBar: Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _yibinBlue,
            primary: _yibinBlue,
          ),
        ),
        child: GlassTabBar.bottom(
          settings: const LiquidGlassSettings(
            thickness: 32,
            blur: 1,
            glowIntensity: 1,
            refractiveIndex: 2.5,
            standardOpacityMultiplier: 1,
          ),
          selectedIndex: _currentIndex,
          onTabSelected: (i) => setState(() => _currentIndex = i),
          tabs: [
            GlassTab(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, color: _yibinBlue),
              label: '首页',
            ),
            GlassTab(
              icon: Icon(Icons.apps_rounded),
              activeIcon: Icon(Icons.apps_rounded, color: _yibinBlue),
              label: '应用',
            ),
            GlassTab(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, color: _yibinBlue),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}

class _AppsPage extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const _AppsPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<_AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<_AppsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';
  int _tabIndex = 0;

  // 最近使用列表（最多 6 个，存名称）
  List<String> _recents = [];

  static const _tabLabels = ['最近', '全部', '教务', '服务', '资讯'];

  static const _tabIcons = [
    Icons.history_rounded,
    Icons.grid_view_rounded,
    Icons.school_rounded,
    Icons.miscellaneous_services_rounded,
    Icons.rss_feed_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _searchCtrl.addListener(() {
      setState(() => _searchText = _searchCtrl.text.trim());
    });
  }

  void _loadRecents() {
    // 从缓存读取最近使用
    final cached = DataCache().get<List<String>>('app_recents');
    if (cached != null) {
      _recents = cached;
    }
  }

  void _recordUsage(String name) {
    _recents.remove(name);
    _recents.insert(0, name);
    if (_recents.length > 6) _recents = _recents.sublist(0, 6);
    DataCache().set('app_recents', _recents);
  }

  List<AppEntry> get _filteredApps {
    List<AppEntry> items;
    switch (_tabIndex) {
      case 0: // 最近
        items = allApps.where((a) => _recents.contains(a.name)).toList();
        items.sort((a, b) {
          final ia = _recents.indexOf(a.name);
          final ib = _recents.indexOf(b.name);
          return ia.compareTo(ib);
        });
        break;
      case 1: // 全部
        items = List.from(allApps);
        break;
      case 2: // 教务
        items = allApps.where((a) => a.category == AppCategory.jiaowu).toList();
        break;
      case 3: // 服务
        items = allApps.where((a) => a.category == AppCategory.service).toList();
        break;
      case 4: // 资讯
        items = allApps.where((a) => a.category == AppCategory.news).toList();
        break;
      default:
        items = [];
    }
    if (_searchText.isNotEmpty) {
      items = items
          .where((a) => a.name.toLowerCase().contains(_searchText.toLowerCase()))
          .toList();
    }
    return items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _filteredApps;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索框
          _buildSearchBar(),
          const SizedBox(height: 20),
          // 分类标签
          _buildTabBar(),
          const SizedBox(height: 20),
          // 应用网格
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      _searchText.isNotEmpty ? '未找到 "$_searchText"' : '暂无最近使用',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: apps.length,
              itemBuilder: (context, index) => _buildAppCard(apps[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '搜索应用名称…',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: Colors.grey[400]),
                  onPressed: () { _searchCtrl.clear(); },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabLabels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == _tabIndex;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? _yibinBlue : Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _tabIcons[i],
                    size: 16,
                    color: selected ? Colors.white : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tabLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppCard(AppEntry entry) {
    final isRecent = _recents.contains(entry.name);
    return GestureDetector(
      onTap: () {
        _recordUsage(entry.name);
        final page = entry.pageBuilder(context, widget.client, widget.userId);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _yibinBlue.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _yibinBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(entry.icon, color: _yibinBlue, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isRecent)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
