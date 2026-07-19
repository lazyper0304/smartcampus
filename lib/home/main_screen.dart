import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../settings/settings_page.dart';
import 'home_dashboard.dart';
import 'app_data.dart';
import '../core/navigation.dart';
import '../main.dart';

/// 当前生效的主题色（跟随外观设置动态变化）
Color get _accentBlue => accentColorNotifier.value;

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
    final defaultBg = _isDark(context)
        ? Color.lerp(_accentBlue, const Color(0xFF1A1A2E), 0.85)!
        : Color.lerp(_accentBlue, Colors.white, 0.9)!;

    return ValueListenableBuilder<String?>(
      valueListenable: backgroundNotifier,
      builder: (context, bgPath, _) {
        return GlassScaffold(
          background: bgPath != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(bgPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: defaultBg),
                    ),
                    // 半透明遮罩确保内容可读性
                    Container(color: defaultBg.withValues(alpha: 0.5)),
                  ],
                )
              : Container(color: defaultBg),
          statusBarStyle: GlassStatusBarStyle.auto,
          contentAwareBrightness: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
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
          SettingsPage(
            key: const ValueKey('settings'),
            client: widget.client,
          ),
        ],
      ),
      bottomBar: Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _accentBlue,
            primary: _accentBlue,
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
              activeIcon: Icon(Icons.home_rounded, color: _accentBlue),
              label: '首页',
            ),
            GlassTab(
              icon: Icon(Icons.apps_rounded),
              activeIcon: Icon(Icons.apps_rounded, color: _accentBlue),
              label: '应用',
            ),
            GlassTab(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, color: _accentBlue),
              label: '设置',
            ),
          ],
        ),
      ),
    );
      },
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

  Future<void> _loadRecents() async {
    final cached = await LocalStorage.getString('app_recents');
    if (cached != null && cached.isNotEmpty && mounted) {
      final list = (jsonDecode(cached) as List).cast<String>();
      setState(() => _recents = list);
    }
  }

  void _recordUsage(String name) {
    _recents.remove(name);
    _recents.insert(0, name);
    if (_recents.length > 6) _recents = _recents.sublist(0, 6);
    LocalStorage.setString('app_recents', jsonEncode(_recents));
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
          // 搜索框（独立渐显）
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
            child: _buildSearchBar(),
          ),
          const SizedBox(height: 20),
          // 分类标签
          _buildTabBar(),
          const SizedBox(height: 20),
          // 应用网格
          _buildContent(apps),
        ],
      ),
    );
  }

  Widget _buildContent(List<AppEntry> apps) {
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48, color: textHint(context)),
              const SizedBox(height: 12),
              Text(
                _searchText.isNotEmpty ? '未找到 "$_searchText"' : '暂无最近使用',
                style: TextStyle(fontSize: 14, color: textHint(context)),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      key: ValueKey('tab_$_tabIndex'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) => _buildAppCard(apps[index]),
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
          hintStyle: TextStyle(fontSize: 14, color: textHint(context)),
          prefixIcon: Icon(Icons.search_rounded, color: textHint(context), size: 20),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: textHint(context)),
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
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: selected ? _accentBlue : Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcons[i],
                      size: 16,
                      color: selected ? Colors.white : textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tabLabels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppCard(AppEntry entry) {
    return GestureDetector(
      onTap: () {
        _recordUsage(entry.name);
        final page = entry.pageBuilder(context, widget.client, widget.userId);
        pushPage(context, page);
      },
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _accentBlue.withValues(alpha: 0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry.icon, color: _accentBlue, size: 20),
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
          ),
          if (entry.badge != null)
            Positioned(
              top: 4,
              right: 4,
              child: entry.badge!,
            ),
        ],
      ),
    );
  }
}
