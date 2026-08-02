import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/responsive.dart';
import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../core/guest_mode.dart';
import '../core/guest_guard.dart';
import '../settings/settings_page.dart';
import '../xuegong/student_info_manager.dart';
import 'home_dashboard.dart';
import 'app_data.dart';
import '../core/navigation.dart';
import '../main.dart';

/// 当前生效的主题色（跟随外观设置动态变化）
Color get _accentBlue => accentColorNotifier.value;

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// 侧边导航（宽屏 / 横屏 / 桌面）的标签页定义。
class _RailTabDef {
  final IconData icon;
  final String label;
  const _RailTabDef(this.icon, this.label);
}

const List<_RailTabDef> _railDefs = [
  _RailTabDef(Icons.home_rounded, '首页'),
  _RailTabDef(Icons.apps_rounded, '应用'),
  _RailTabDef(Icons.settings_rounded, '设置'),
];

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
  void initState() {
    super.initState();
    // 进入主界面后后台静默获取个人信息（失败自动重试直到成功），不阻塞 UI；
    // 游客模式无登录凭据，跳过。
    if (widget.userId.isNotEmpty) {
      StudentInfoManager.ensureBackgroundFetch(widget.client);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultBg = _isDark(context)
        ? Color.lerp(_accentBlue, const Color(0xFF1A1A2E), 0.85)!
        : Color.lerp(_accentBlue, Colors.white, 0.9)!;
    final isWide = isWideScreen(context);

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
          body: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSideRail(context),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _buildPages(),
                      ),
                    ),
                  ],
                )
              : IndexedStack(
                  index: _currentIndex,
                  children: _buildPages(),
                ),
      bottomBar: isWide ? null : _buildBottomTabBar(),
    );
      },
    );
  }

  /// 三个主页面（首页 / 应用 / 设置），在底部栏与侧边栏两种布局中复用。
  List<Widget> _buildPages() => [
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
      ];

  /// 紧凑布局（手机竖屏）下的浮动玻璃底部导航栏。
  Widget _buildBottomTabBar() => Theme(
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
      );

  /// 宽屏 / 横屏 / 桌面下的玻璃风格侧边导航栏（替代底部栏）。
  Widget _buildSideRail(BuildContext context) {
    final isDark = _isDark(context);
    return SizedBox(
      width: kRailWidth,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1A1A2E) : Colors.white)
                  .withValues(alpha: 0.45),
              border: Border(
                right: BorderSide(
                  color: (isDark ? Colors.white : _accentBlue).withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 28),
                ...List.generate(
                  _railDefs.length,
                  (i) => _buildRailItem(context, i),
                ),
                const Spacer(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 侧边栏单个标签项。
  Widget _buildRailItem(BuildContext context, int i) {
    final selected = i == _currentIndex;
    final def = _railDefs[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _currentIndex = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? _accentBlue.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: selected
                  ? Border.all(color: _accentBlue.withValues(alpha: 0.3))
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(def.icon,
                    size: 24,
                    color: selected ? _accentBlue : textSecondary(context)),
                const SizedBox(height: 6),
                Text(
                  def.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? _accentBlue : textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
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
    final isWide = isWideScreen(context);
    final topPad = isWide ? 28.0 : 56.0;
    final bottomPad = bottomBarSafePadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, topPad, 20, bottomPad),
      child: MaxWidthContent(
        maxWidth: kGridMaxWidth,
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
    // 根据可用宽度自适应列数：横屏 / 桌面宽屏下展示更多列，避免浪费空间。
    final isWide = isWideScreen(context);
    final width = MediaQuery.of(context).size.width;
    final available = width - (isWide ? kRailWidth : 0.0) - 40;
    final columns = appGridColumns(available);
    return GridView.builder(
      key: ValueKey('tab_$_tabIndex'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
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
    final guestLocked = GuestMode.active && entry.requiresLogin;
    return GestureDetector(
      onTap: () {
        if (guestLocked) {
          showGuestLoginDialog(context, featureName: entry.name);
          return;
        }
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
                      color: guestLocked
                          ? Colors.grey.withValues(alpha: 0.08)
                          : _accentBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry.icon,
                        color: guestLocked ? Colors.grey : _accentBlue, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: guestLocked ? Colors.grey : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (guestLocked)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
              ),
            )
          else if (entry.badge != null)
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
