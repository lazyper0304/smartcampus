import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/responsive.dart';
import '../core/input_adaptation.dart';
import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../core/guest_mode.dart';
import '../core/guest_guard.dart';
import '../core/ios_kit.dart';
import '../core/glass_category_bar.dart';
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

  /// 宽屏 / 横屏 / 桌面下的液态玻璃风格侧边导航栏（替代底部栏）。
  ///
  /// ⚠️ 不用 GlassCard / GlassButton 等 shader 组件：GLES 设备（部分
  /// Android 平板）shader 玻璃不渲染，会导致平板白屏——与「平板和
  /// Windows 一致」冲突。此处用视觉液态玻璃：BackdropFilter 模糊 +
  /// 顶部高光渐变模拟折射 + 右侧边缘亮线 + 悬浮投影，全平台稳定渲染。
  Widget _buildSideRail(BuildContext context) {
    final isDark = _isDark(context);
    return SizedBox(
      width: kRailWidth,
      child: DecoratedBox(
        // 与内容区之间的悬浮投影（桌面端层次感）
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
              blurRadius: 14,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                // 液态玻璃渐变：顶部高光（反光）+ 主体半透明，模拟折射层次
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.white : Colors.white)
                        .withValues(alpha: isDark ? 0.14 : 0.55),
                    (isDark ? const Color(0xFF1A1A2E) : Colors.white)
                        .withValues(alpha: isDark ? 0.42 : 0.30),
                  ],
                  stops: const [0.0, 0.38],
                ),
                border: Border(
                  right: BorderSide(
                    color: (isDark ? Colors.white : _accentBlue)
                        .withValues(alpha: 0.14),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  _buildRailBrand(context),
                  const SizedBox(height: 12),
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
      ),
    );
  }

  /// 侧栏顶部品牌区：玻璃方块图标（液态玻璃质感小元素）。
  Widget _buildRailBrand(BuildContext context) {
    final isDark = _isDark(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentBlue.withValues(alpha: isDark ? 0.75 : 0.90),
            _accentBlue.withValues(alpha: isDark ? 0.55 : 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        // 高光描边模拟玻璃边缘
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
    );
  }

  /// 侧边栏单个标签项。
  /// 选中态：胶囊更饱满（垂直/水平 padding 增大）+ 图标平滑放大 +
  /// 文字加大加粗 + 左侧指示条，整体"长大"强化选中反馈。
  Widget _buildRailItem(BuildContext context, int i) {
    final selected = i == _currentIndex;
    final def = _railDefs[i];
    final isDark = _isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // 桌面悬停反馈（平板触屏无 hover 不干扰）
          hoverColor: _accentBlue.withValues(alpha: isDark ? 0.14 : 0.08),
          splashColor: _accentBlue.withValues(alpha: 0.10),
          // 桌面鼠标手型光标（键盘 Tab 聚焦 + Enter 激活由 InkWell 内置）
          mouseCursor: SystemMouseCursors.click,
          onTap: () => setState(() => _currentIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            // 选中态胶囊更饱满：水平 padding 增大让胶囊更宽，垂直同步加大
            padding: EdgeInsets.symmetric(
              vertical: selected ? 14 : 9,
              horizontal: selected ? 12 : 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              // 选中：玻璃胶囊（accent 渐变 + 白色高光描边，静态玻璃无 shader）
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _accentBlue.withValues(alpha: isDark ? 0.30 : 0.20),
                        _accentBlue.withValues(alpha: isDark ? 0.18 : 0.12),
                      ],
                    )
                  : null,
              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.40),
                    )
                  : null,
            ),
            child: Stack(
              // ⚠️ 指示条 left 为负会越界，Stack 默认 Clip.hardEdge 会裁掉，
              // 必须显式 Clip.none（此前指示条可能因此不可见）
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 图标选中平滑放大（基础 22，放大后约 26）
                    AnimatedScale(
                      scale: selected ? 1.18 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(def.icon,
                          size: 22,
                          color:
                              selected ? _accentBlue : textSecondary(context)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      def.label,
                      style: TextStyle(
                        fontSize: selected ? 12 : 11,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? _accentBlue : textSecondary(context),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  // 左侧指示条：贴胶囊左缘、垂直居中（Center 保证 22 高）
                  Positioned(
                    left: -12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _accentBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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

  // 最近使用列表（最多 16 个，存名称）
  static const int _recentLimit = 16;
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
      setState(() => _recents = list.take(_recentLimit).toList());
    }
  }

  void _recordUsage(String name) {
    _recents.remove(name);
    _recents.insert(0, name);
    if (_recents.length > _recentLimit) {
      _recents = _recents.sublist(0, _recentLimit);
    }
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
    // 与首页「常用功能」宫格一致：上下 14 / 左右 8，比例 0.82；
    // 列数按**实际渲染宽度**自适应（LayoutBuilder 约束，受外层
    // MaxWidthContent(1200) 限宽），大屏（平板/桌面）自动 3→4→6→8 列。
    return LayoutBuilder(
      builder: (context, c) {
        final cols = appGridColumns(c.maxWidth);
        return GridView.builder(
          key: ValueKey('tab_$_tabIndex'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 8,
            // 0.95（接近正方形）减少图标卡片内的上下留白；
            // 原 0.82 卡片偏高，图标居中后上下各 ~30px 留白过宽
            childAspectRatio: 0.95,
          ),
          itemCount: apps.length,
          // RepaintBoundary：隔离每张卡片（含玻璃组件）的绘制，切换/滚动时
          // 只重绘变化的项，减少整片网格重绘导致的掉帧
          itemBuilder: (context, index) =>
              RepaintBoundary(child: _buildAppCard(apps[index])),
        );
      },
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

  /// 分类选择：统一玻璃分类栏（GlassCategoryBar，替代原 IosCard 手写实现）
  /// 图标在文字上方（vertical），选中项 accent 背景 + 竖分割线
  Widget _buildTabBar() {
    return GlassCategoryBar(
      items: [
        for (var i = 0; i < _tabLabels.length; i++)
          GlassCategoryItem(label: _tabLabels[i], icon: _tabIcons[i]),
      ],
      selectedIndex: _tabIndex,
      onSelected: (i) => setState(() => _tabIndex = i),
      vertical: true,
      padding: const EdgeInsets.all(8),
    );
  }

  Widget _buildAppCard(AppEntry entry) {
    final guestLocked = GuestMode.active && entry.requiresLogin;
    final accent = _accentBlue;
    return Clickable(
      onTap: () {
        if (guestLocked) {
          showGuestLoginDialog(context, featureName: entry.name);
          return;
        }
        _recordUsage(entry.name);
        final page = entry.pageBuilder(context, widget.client, widget.userId);
        pushPage(context, page);
      },
      borderRadius: 14,
      // 自定义 builder：光效以图标为中心（图标光晕），替代默认整卡
      // 矩形高亮（矩形中心在卡片中心，与偏上的图标错位）
      builder: (context, hovered, focused) {
        final active = hovered || focused;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                // 玻璃方块随卡片宽度自适应（约 55%）：大屏 6/8 列大卡片
                // 图标同步放大，手机 4 列小卡片同步缩小但保底不显得太小
                final tileSize = c.maxWidth * 0.55;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 图标光晕：悬停/聚焦时图标方块外发光，光效中心=图标中心
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tileSize * 0.28),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: (guestLocked ? Colors.grey : accent)
                                      .withValues(
                                          alpha: focused ? 0.55 : 0.32),
                                  blurRadius: tileSize * 0.34,
                                  spreadRadius: 1,
                                ),
                              ]
                            : const [],
                      ),
                      // 静态玻璃方块（与内容卡片同款；不用 GlassButton——
                      // shader 组件 GLES 不渲染且网格 30+ 个同时渲染掉帧/耗电）
                      child: appTileGlass(
                        context: context,
                        icon: entry.icon,
                        iconColor: guestLocked ? Colors.grey : accent,
                        size: tileSize,
                      ),
                    ),
                    // 图标与文字间距收紧（8 → 5），卡片更紧凑
                    const SizedBox(height: 5),
                    Text(
                      entry.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        // 字号随卡片宽度自适应（与图标方块同链路）
                        fontSize: adaptiveTileFontSize(c.maxWidth),
                        fontWeight: FontWeight.w600,
                        color: guestLocked ? Colors.grey : null,
                      ),
                    ),
                  ],
                );
              },
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
                  child:
                      const Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                ),
              )
            else if (entry.badge != null)
              Positioned(
                top: 4,
                right: 6,
                child: entry.badge!,
              ),
          ],
        );
      },
    );
  }
}
