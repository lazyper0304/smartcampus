import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/responsive.dart';
import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../core/guest_mode.dart';
import '../core/guest_guard.dart';
import '../core/ios_kit.dart';
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
  _RailTabDef(CupertinoIcons.house_fill, '首页'),
  _RailTabDef(CupertinoIcons.square_grid_2x2_fill, '应用'),
  _RailTabDef(CupertinoIcons.settings, '设置'),
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
    final isWide = isWideScreen(context);

    return GlassScaffold(
      // 页面玻璃参数统一在此层设置（grouped 子 widget 继承，避免
      // per-widget settings 被忽略的警告）；quality 全局 standard。
      // 与底部导航栏参数一致（用户要求应用按钮同款）。
      settings: const LiquidGlassSettings(
        thickness: 30,
        blur: 5,
        glowIntensity: 1.2,
        refractiveIndex: 2.6,
        specularSharpness: GlassSpecularSharpness.sharp,
        standardOpacityMultiplier: 0.8,
      ),
      // ⚠️ 自定义背景已提升到全局 builder（main.dart）统一应用（含二级页），
      // 此处背景透明，让全局背景（图片或液态玻璃）透出。
      background: const SizedBox.shrink(),
      statusBarStyle: GlassStatusBarStyle.auto,
      contentAwareBrightness: true,
      // ⚠️ 0.26.0+ GlassScaffold 内部是 CupertinoPageScaffold，不提供
      // Material 的 DefaultTextStyle/主题字体——无子 Scaffold 的页面
      //（应用页）Text 会回退到 14px 纯黑默认样式（字体异常）。
      // 包一层透明 Material 恢复主题字体继承 + Material 祖先。
  body: Material(
    type: MaterialType.transparency,
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSideRail(context),
                  Expanded(child: _buildPagesStack()),
                ],
              )
            : _buildPagesStack(),
      ),
      bottomBar: isWide ? null : _buildBottomTabBar(),
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

  /// 主界面 tab 切换动画容器：Stack 常驻三个页面（保留各自滚动/加载状态），
  /// 非活跃页透明度 0 + 忽略触摸 + 暂停动画（TickerMode），切换时 250ms
  /// iOS 风格淡入；替代无动画的 IndexedStack。
  Widget _buildPagesStack() {
    final pages = _buildPages();
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < pages.length; i++)
          IgnorePointer(
            ignoring: i != _currentIndex,
            child: AnimatedOpacity(
              opacity: i == _currentIndex ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: TickerMode(
                enabled: i == _currentIndex,
                child: pages[i],
              ),
            ),
          ),
      ],
    );
  }

  /// 紧凑布局（手机竖屏）下的浮动玻璃底部导航栏。
  Widget _buildBottomTabBar() => Material(
        type: MaterialType.transparency,
        // ⚠️ 解耦修复：GlassBottomBar 的 label 不指定颜色（依赖
        // DefaultTextStyle）→ 无 Material 祖先时回退纯黑（深色模式看不见）。
        // 包透明 Material 恢复主题字体 + 显式 textStyle 双保险。
        child: Theme(
          data: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _accentBlue,
              primary: _accentBlue,
            ),
          ),
          child: GlassTabBar.bottom(
            // 显式 premium：折射（refraction）+ 色散（chromatic aberration）
            // 只有完整 shader 管线才有；standard 是轻量 shader 无折射。
            quality: GlassQuality.premium,
            // 透出型液态玻璃：极低模糊让下方滚动文字清晰透出，保留折射边缘
            settings: const LiquidGlassSettings(
              thickness: 30,
              blur: 5,
              glowIntensity: 1.2,
              refractiveIndex: 2.6,
              specularSharpness: GlassSpecularSharpness.sharp,
              standardOpacityMultiplier: 0.8,
            ),
            textStyle: TextStyle(
              fontSize: 11,
              color: _isDark(context)
                  ? const Color(0xFF9E9EB0)
                  : const Color(0xFF6E6E80),
            ),
            selectedIndex: _currentIndex,
            onTabSelected: (i) => setState(() => _currentIndex = i),
            tabs: [
              GlassTab(
                icon: const Icon(CupertinoIcons.house),
                activeIcon: Icon(CupertinoIcons.house_fill, color: _accentBlue),
                label: '首页',
              ),
              GlassTab(
                icon: const Icon(CupertinoIcons.square_grid_2x2),
                activeIcon:
                    Icon(CupertinoIcons.square_grid_2x2_fill, color: _accentBlue),
                label: '应用',
              ),
              GlassTab(
                icon: const Icon(CupertinoIcons.settings),
                activeIcon:
                    Icon(CupertinoIcons.settings, color: _accentBlue),
                label: '设置',
              ),
            ],
          ),
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
    final bottomPad = bottomBarSafePadding(context);

    // 与首页/设置页一致：GlassScaffold 不自动 SafeArea，顶部需自行
    // 避开状态栏留白（否则标题顶到状态栏，上方无空白）；
    // 底部由 bottomBarSafePadding 统一避让浮动玻璃导航栏。
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            kIosPageHPadding, 10, kIosPageHPadding, bottomPad),
        child: MaxWidthContent(
          maxWidth: kGridMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IosLargeTitle(title: '应用'),
              const SizedBox(height: 16),
              // 搜索框（玻璃质感）
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
              const SizedBox(height: 16),
              // 分类宫格卡片
              _buildTabBar(),
              // 卡片四周留白等边：上下/左右均 16
              const SizedBox(height: 16),
              // 应用网格（分类切换左右滑动：新内容从右侧滑入 + 淡入；
              // ⚠️ 性能：reverseDuration: zero 让旧网格立即移除——否则新旧
              // 两个网格（各 30+ 卡片）同时渲染 220ms，双倍负载导致掉帧；
              // layoutBuilder 顶部对齐防垂直跳动；搜索不换 key 不动画）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                // 旧网格不播放退出动画，立即移除（只渲染新网格，减半负载）
                reverseDuration: Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                ),
                child: _buildContent(apps),
              ),
            ],
          ),
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
    // 与首页「常用功能」宫格一致：固定 4 列，上下 14 / 左右 8，比例 0.82
    return GridView.builder(
      key: ValueKey('tab_$_tabIndex'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: apps.length,
      // RepaintBoundary：隔离每张卡片（含玻璃组件）的绘制，切换/滚动时
      // 只重绘变化的项，减少整片网格重绘导致的掉帧
      itemBuilder: (context, index) =>
          RepaintBoundary(child: _buildAppCard(apps[index])),
    );
  }

  /// 搜索栏：静态玻璃样式（与内容卡片同款——半透明渐变 + 白色高光描边，
  /// 无 BackdropFilter/shader 依赖，滚动与 overscroll 稳定）
  Widget _buildSearchBar() {
    final isDark = _isDark(context);
    final baseColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kIosTileRadius),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          // 顶部略亮模拟玻璃反光，主体半透明透出背景
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              baseColor.withValues(alpha: isDark ? 0.55 : 0.45),
              baseColor.withValues(alpha: isDark ? 0.48 : 0.38),
            ],
            stops: const [0.0, 0.45],
          ),
          borderRadius: BorderRadius.circular(kIosTileRadius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索应用名称…',
              hintStyle: TextStyle(fontSize: 14, color: textHint(context)),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: textHint(context)),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          size: 18, color: textHint(context)),
                      onPressed: _searchCtrl.clear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
    );
  }

  /// 分类选择：统一宫格卡片 + 内部分割线（iOS 分组风格，替代分段控件）
  /// IntrinsicHeight + stretch：分割线与选中背景自动拉伸至内容全高，
  /// 高度随文字行高动态适配，与选中状态天然契合
  Widget _buildTabBar() {
    final accent = _accentBlue;
    final lineColor =
        (_isDark(context) ? Colors.white : Colors.black).withValues(alpha: 0.08);
    return IosCard(
      // 卡片内边距四周等边（上下左右 8）
      padding: const EdgeInsets.all(8),
      margin: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          // stretch：分割线与选中背景均撑满内容高度（IntrinsicHeight 提供）
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _tabLabels.length; i++) ...[
              if (i > 0)
                // 内部分割线：0.5 细线，与 IosListGroup 分隔线同规格，
                // 高度自动等于选中背景
                Container(
                  width: 0.5,
                  color: lineColor,
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tabIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == _tabIndex
                          ? accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabIcons[i],
                          size: 20,
                          color: i == _tabIndex
                              ? accent
                              : textSecondary(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tabLabels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == _tabIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == _tabIndex
                                ? accent
                                : textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(AppEntry entry) {
    final guestLocked = GuestMode.active && entry.requiresLogin;
    final accent = _accentBlue;
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 静态玻璃方块（与内容卡片同款；不用 GlassButton——
              // shader 组件 GLES 不渲染且网格 30+ 个同时渲染掉帧/耗电）
              appTileGlass(
                context: context,
                icon: entry.icon,
                iconColor: guestLocked ? Colors.grey : accent,
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
          if (guestLocked)
            Positioned(
              top: 4,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
              ),
            )
          else if (entry.badge != null)
            Positioned(
              top: 4,
              right: 6,
              child: entry.badge!,
            ),
        ],
      ),
    );
  }
}
