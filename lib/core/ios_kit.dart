import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../home/app_data.dart';
import '../main.dart';
import 'guest_guard.dart';
import 'guest_mode.dart';
import 'http_client.dart';
import 'input_adaptation.dart';
import 'local_storage.dart';
import 'navigation.dart';
import 'responsive.dart';
import 'theme_utils.dart';

/// ============================================================================
/// iOS 风格 UI 组件库（基于 liquid_glass_widgets 渲染层）
///
/// 设计原则（对齐 iOS 26 Liquid Glass 官方指南）：
/// - 导航 / 控制层（导航栏、底部栏、宫格入口）→ 玻璃质感
/// - 内容区（列表、卡片）→ 半透明玻璃卡片，保证可读性
/// - 大标题 + 分组列表是 iOS 信息架构的核心
/// ============================================================================

/// 品牌强调色（跟随外观设置动态变化）
Color accentOf(BuildContext context) => accentColorNotifier.value;

/// 分组列表背景色（iOS systemGroupedBackground）
Color iosGroupedBackgroundOf(BuildContext context) =>
    adaptColor(context, const Color(0xFFF2F2F7), const Color(0xFF000000));

/// 卡片表面色（iOS secondarySystemGroupedBackground）
Color iosCardBackgroundOf(BuildContext context) =>
    adaptColor(context, const Color(0xFFFFFFFF), const Color(0xFF1C1C1E));

/// 分组卡片圆角（iOS 分组列表默认）
const double kIosCardRadius = 16.0;

/// 宫格 / 小控件圆角
const double kIosTileRadius = 12.0;

/// 页面统一水平内边距
const double kIosPageHPadding = 16.0;

/// ⚠️ 玻璃参数设计约束（0.29.1）：
/// - 页面玻璃参数统一由 `GlassScaffold.settings` / `GlassThemeSettings`
///   （main.dart）提供；grouped 模式下子 widget 的 `settings` 会被忽略，
///   并打印 "settings provided without useOwnLayer" 警告。
/// - 不要给 GlassCard / GlassButton 传 per-widget settings（除非 useOwnLayer）。
/// - quality 全局用 standard（premium 在 ListView 内 Impeller 渲染错误）。

/// 内容卡片毛玻璃容器（BackdropFilter 实现，IosCard / IosListGroup 共用）：
/// - ⚠️ 不用 GlassCard：其 shader 玻璃在无 Impeller/Vulkan（GLES）设备上
///   `ImageFilter.isShaderFilterSupported == false` → 不渲染玻璃、直接透出
///   背景（浅色 LiquidBackground 下看起来就是白色卡片）。
/// - BackdropFilter 用 Flutter 内置 blur，全设备有效；
///   半透明白（浅色）/ 半透明深灰（深色）+ 26 模糊 + 细描边 → iOS 毛玻璃。
Widget contentCardGlass({
  required BuildContext context,
  required Widget child,
  required BorderRadiusGeometry borderRadius,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  EdgeInsetsGeometry? margin,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // 静态玻璃（无 BackdropFilter）：半透明渐变填充 + 顶部高光 + 白色描边
  // 模拟 iOS 液态玻璃。⚠️ 不用 BackdropFilter——其与 ListView overscroll
  // （橡皮筋位移+裁剪）组合会导致采样破坏、卡片变透（平台级限制）。
  final baseColor =
      isDark ? const Color(0xFF1C1C1E) : Colors.white;
  final card = ClipRRect(
    borderRadius: borderRadius,
    child: Container(
      // 撑满父宽（loose 约束下不收缩，如设置页 Column(start)）
      width: double.infinity,
      decoration: BoxDecoration(
        // 顶部略亮模拟玻璃反光，主体半透明透出背景渐变
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withValues(alpha: isDark ? 0.55 : 0.45),
            baseColor.withValues(alpha: isDark ? 0.48 : 0.38),
          ],
          stops: const [0.0, 0.45],
        ),
        borderRadius: borderRadius,
        // 玻璃边缘高光：白色细描边
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        // 透明 Material：提供主题字体/DefaultTextStyle 继承
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
  if (margin == null) return card;
  return Padding(padding: margin, child: card);
}

/// iOS 超椭圆圆角（squircle）
LiquidRoundedSuperellipse iosSquircle([double radius = kIosCardRadius]) =>
    LiquidRoundedSuperellipse(borderRadius: radius);

/// 宫格入口静态玻璃方块（应用网格 / 首页常用功能共用）：
/// ⚠️ 替代 GlassButton——shader 组件在 GLES 设备不渲染，且网格 30+ 个
/// 同时渲染会掉帧/耗电；圆角矩形 + 半透明渐变 + 白描边，与内容卡片同款。
Widget appTileGlass({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  double size = 58,
  double radius = 16,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final base = isDark ? const Color(0xFF1C1C1E) : Colors.white;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      // 圆角矩形
      borderRadius: BorderRadius.circular(radius),
      // 顶部略亮模拟玻璃反光，主体半透明透出背景
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          base.withValues(alpha: isDark ? 0.55 : 0.45),
          base.withValues(alpha: isDark ? 0.48 : 0.38),
        ],
        stops: const [0.0, 0.45],
      ),
      // 玻璃边缘高光：白色细描边
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.45),
      ),
    ),
    child: Icon(icon, size: size * 0.42, color: iconColor),
  );
}

/// 磨砂玻璃弹窗内容容器（Dialog 用透明底 + 此容器）：
/// BackdropFilter 模糊 20 + 半透明渐变 + 白描边，所有弹窗统一。
/// 用法：`Dialog(backgroundColor: Colors.transparent, child: glassDialog(context: ctx, child: ...))`
Widget glassDialog({
  required BuildContext context,
  required Widget child,
  double radius = 20,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final base = isDark ? const Color(0xFF1C1C1E) : Colors.white;
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          // 顶部略亮模拟玻璃反光，主体半透明透出模糊背景
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              base.withValues(alpha: isDark ? 0.55 : 0.45),
              base.withValues(alpha: isDark ? 0.48 : 0.38),
            ],
            stops: const [0.0, 0.45],
          ),
          borderRadius: BorderRadius.circular(radius),
          // 玻璃边缘高光：白色细描边
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// 磨砂玻璃加载弹窗（所有页面统一 loading 样式）：
/// BackdropFilter 模糊 20 + 半透明渐变 + 转圈 + 文案；
/// Dialog 固定不位移，采样稳定，无卡片 overscroll 变透问题。
Future<void> showGlassLoadingDialog(
  BuildContext context, {
  String message = '正在加载…',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => _GlassLoadingDialog(message: message),
  );
}

class _GlassLoadingDialog extends StatelessWidget {
  final String message;
  const _GlassLoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              // 顶部略亮模拟玻璃反光，主体半透明透出模糊背景
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: isDark ? 0.55 : 0.45),
                  base.withValues(alpha: isDark ? 0.48 : 0.38),
                ],
                stops: const [0.0, 0.45],
              ),
              borderRadius: BorderRadius.circular(20),
              // 玻璃边缘高光：白色细描边
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 2.5),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// iOS 大标题（页面顶部：日期小字 + 大标题 + 可选右侧操作）
/// ---------------------------------------------------------------------------
class IosLargeTitle extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;

  const IosLargeTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      eyebrow!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: accentOf(context),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// iOS 分组标题（小号灰色大写感标题）
/// ---------------------------------------------------------------------------
class IosSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const IosSectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary(context),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 玻璃卡片（首页 / 内容区通用）
/// ---------------------------------------------------------------------------
class IosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  const IosCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = kIosCardRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // iOS 毛玻璃卡片：BackdropFilter 半透明白 + 模糊 26（全设备有效，
    // GlassCard shader 在 GLES 设备不渲染）；内部透明 Material 提供主题继承。
    final card = contentCardGlass(
      context: context,
      borderRadius: BorderRadius.circular(radius),
      padding: padding,
      margin: margin,
      child: child,
    );
    if (onTap == null) return card;
    // 多输入适配：鼠标手型光标 + 键盘 Enter/空格 激活 + 焦点高亮
    return Clickable(
      onTap: onTap,
      borderRadius: radius,
      child: card,
    );
  }
}

/// ---------------------------------------------------------------------------
/// 分组列表（设置页 / 列表页）—— iOS 分组卡片样式：实色底 + 自动分隔线
/// ---------------------------------------------------------------------------
class IosListGroup extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  final EdgeInsetsGeometry margin;

  const IosListGroup({
    super.key,
    required this.children,
    this.header,
    // 页面 ListView 已提供水平 padding，默认不再自带 margin（防宽度不一致）
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    // 分组卡液态玻璃（与 IosCard 同参数）；子项间自动注入分隔线
    final tiles = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor(context),
            indent: 52,
          ),
        children[i],
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) IosSectionHeader(header!),
        contentCardGlass(
          context: context,
          borderRadius: BorderRadius.circular(kIosCardRadius),
          margin: margin,
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// 分组内条目（iOS 风格 ListTile）
/// ---------------------------------------------------------------------------
class IosListTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 卡片内部元素整体缩放系数（大屏卡片自适应）：图标容器 / 图标 / 标题 /
  /// 副标题按比例放大，避免大屏宽卡片"大卡小内容"；默认 1.0 行为不变。
  final double scale;

  const IosListTile({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBackground,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? accentOf(context);
    final tile = GlassListTile(
      leading: icon != null
          ? Container(
              width: 30 * scale,
              height: 30 * scale,
              decoration: BoxDecoration(
                color: iconBackground ?? color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Icon(icon, color: color, size: 17 * scale),
            )
          : null,
      title: Text(title,
          style: TextStyle(
              fontSize: 15 * scale, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 12 * scale, color: textSecondary(context)))
          : null,
      trailing: trailing ?? (onTap != null ? GlassListTile.chevron : null),
      onTap: onTap,
    );
    if (onTap == null) return tile;
    // 多输入适配：鼠标手型光标 + 键盘 Enter/空格 激活 + 焦点高亮
    return Clickable(
      onTap: onTap,
      borderRadius: 14,
      child: tile,
    );
  }
}
/// ---------------------------------------------------------------------------
/// iOS 分段控件（GlassSegmentedControl 封装）
/// ---------------------------------------------------------------------------
class IosSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const IosSegmentedControl({
    super.key,
    required this.labels,
    this.icons,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSegmentedControl(
      segments: [
        for (var i = 0; i < labels.length; i++)
          GlassSegment(
            label: labels[i],
            // 尺寸由内部 IconTheme 统一为 16，无需在此指定
            icon: icons != null ? Icon(icons![i]) : null,
          ),
      ],
      selectedIndex: selectedIndex,
      onSegmentSelected: onChanged,
      // 竖排布局（图标16 + 间距2 + 文字13）在 36 高度下过挤 → 44 舒适触控
      height: 44,
      borderRadius: kIosTileRadius,
      // 指示器与容器之间留 3px 呼吸感（默认 2）
      padding: const EdgeInsets.all(3),
      indicatorColor: accentOf(context),
      // 显式文字样式：选中加粗主色 / 未选中次要色（避免依赖 CupertinoTheme
      // 回退导致的 60% 透明度文字偏淡）
      selectedTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
      ),
      unselectedTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary(context),
      ),
      // iOS 26 按压辉光跟随强调色（默认软白 12% 在浅色下不可见）
      glowColor: accentOf(context).withValues(alpha: 0.18),
      glowRadius: 1.2,
    );
  }
}

/// ---------------------------------------------------------------------------
/// 常用功能数据层（配置持久化到 LocalStorage `home_quick_apps`）
/// ---------------------------------------------------------------------------
class QuickAppsStore {
  QuickAppsStore._();

  static const String storageKey = 'home_quick_apps';
  static const int maxCount = 12;
  static const List<String> defaults = [
    '课程表', '成绩查询', '校历服务', '校园新闻',
    '临港电费', '校车时间', '网络服务', 'VR地图',
  ];

  /// 读取配置并映射为 AppEntry（过滤已下架条目，配置损坏时回退默认）
  static Future<List<AppEntry>> load() async {
    List<String> names = defaults;
    try {
      final raw = await LocalStorage.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        names = (jsonDecode(raw) as List).cast<String>();
      }
    } catch (_) {/* 配置损坏时回退默认 */}
    return names
        .map((n) => allApps.where((a) => a.name == n).firstOrNull)
        .whereType<AppEntry>()
        .toList();
  }

  /// 保存（名称数组）
  static Future<void> save(List<AppEntry> items) => LocalStorage.setString(
        storageKey,
        jsonEncode(items.map((e) => e.name).toList()),
      );
}

/// 常用功能配置变更通知（设置页修改后自增，首页监听自动刷新）
final ValueNotifier<int> quickAppsChangedNotifier = ValueNotifier(0);

/// ---------------------------------------------------------------------------
/// 首页「常用功能」宫格（只读展示；自定义管理在 设置 → 常用功能）
/// ---------------------------------------------------------------------------
class QuickAppsSection extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const QuickAppsSection({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<QuickAppsSection> createState() => _QuickAppsSectionState();
}

class _QuickAppsSectionState extends State<QuickAppsSection> {
  List<AppEntry> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    quickAppsChangedNotifier.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    quickAppsChangedNotifier.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() => _load();

  Future<void> _load() async {
    final items = await QuickAppsStore.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
    });
  }

  void _openApp(AppEntry entry) {
    final ctx = context;
    if (GuestMode.active && entry.requiresLogin) {
      showGuestLoginDialog(ctx, featureName: entry.name);
      return;
    }
    final page = entry.pageBuilder(ctx, widget.client, widget.userId);
    pushPage(ctx, page);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IosSectionHeader('常用功能', padding: EdgeInsets.fromLTRB(4, 8, 4, 10)),
        // ⚠️ 列数按实际渲染宽度（LayoutBuilder 约束）计算，勿用
        // MediaQuery 全宽——外层 MaxWidthContent(760) 限宽时列数会虚高。
        LayoutBuilder(
          builder: (context, c) {
            final cols = appGridColumns(c.maxWidth);
            return GridView.builder(
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
              itemCount: _items.length,
              itemBuilder: (context, i) => _QuickAppTile(
                entry: _items[i],
                onTap: () => _openApp(_items[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 宫格方块：玻璃质感图标 + 名称；点击跳转
class _QuickAppTile extends StatelessWidget {
  final AppEntry entry;
  final VoidCallback? onTap;

  const _QuickAppTile({
    required this.entry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentOf(context);
    return Clickable(
      onTap: onTap,
      borderRadius: 14,
      // 自定义 builder：光效以图标为中心（图标光晕），替代默认整卡
      // 矩形高亮（矩形中心在卡片中心，与偏上的图标错位）
      builder: (context, hovered, focused) {
        final active = hovered || focused;
        return LayoutBuilder(
          builder: (context, c) {
            // 玻璃方块随卡片宽度自适应（约 45%）：大屏卡片更大时图标同步
            // 放大，窄屏小卡片同步缩小，避免固定 56 导致的"大卡片小图标"。
            final tileSize = c.maxWidth * 0.45;
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
                              color: color.withValues(
                                  alpha: focused ? 0.55 : 0.32),
                              blurRadius: tileSize * 0.34,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  // 静态玻璃方块（同应用网格；不用 GlassButton——shader 组件
                  // GLES 不渲染且格子多时掉帧/耗电）
                  child: appTileGlass(
                    context: context,
                    icon: entry.icon,
                    iconColor: color,
                    size: tileSize,
                  ),
                ),
                // 图标与文字间距收紧（8 → 5），卡片更紧凑
                const SizedBox(height: 5),
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // 字号随卡片宽度自适应（与图标方块同链路）
                    fontSize: adaptiveTileFontSize(c.maxWidth),
                    fontWeight: FontWeight.w600,
                    color: textPrimary(context),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// 「添加常用功能」底部选择弹窗（iOS 风格毛玻璃 Sheet）
/// ---------------------------------------------------------------------------
Future<AppEntry?> showQuickAppPicker(
  BuildContext context, {
  required Set<String> exclude,
  int maxCount = 12,
}) {
  return showModalBottomSheet<AppEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _QuickAppPickerSheet(exclude: exclude, maxCount: maxCount),
  );
}

class _QuickAppPickerSheet extends StatefulWidget {
  final Set<String> exclude;
  final int maxCount;

  const _QuickAppPickerSheet({required this.exclude, required this.maxCount});

  @override
  State<_QuickAppPickerSheet> createState() => _QuickAppPickerSheetState();
}

class _QuickAppPickerSheetState extends State<_QuickAppPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppEntry> get _candidates {
    return allApps.where((a) {
      if (widget.exclude.contains(a.name)) return false;
      if (_query.isEmpty) return true;
      return a.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.72;
    // 磨砂玻璃底部弹窗：BackdropFilter 模糊 + 半透明渐变（弹窗是固定容器，
    // 内部 ListView 滚动不位移弹窗，采样稳定——不会出现卡片在列表
    // overscroll 时的变透问题）
    // ⚠️ 顶部 40 留白必须放在最外层 Padding——若放 Container margin，
    // BackdropFilter 会覆盖整片（含留白区），弹窗上方出现多余模糊带
    final sheetIsDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBase =
        sheetIsDark ? const Color(0xFF1C1C1E) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: height,
            decoration: BoxDecoration(
            // 顶部略亮模拟玻璃反光，主体半透明透出模糊背景
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                sheetBase.withValues(alpha: sheetIsDark ? 0.55 : 0.45),
                sheetBase.withValues(alpha: sheetIsDark ? 0.48 : 0.38),
              ],
              stops: const [0.0, 0.45],
            ),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22)),
            border: Border(
              top: BorderSide(
                color: sheetIsDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Column(
            children: [
          // 拖拽把手
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: textHint(context).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('添加常用功能',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // 搜索
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: textHint(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '搜索应用…',
                  hintStyle: TextStyle(fontSize: 14, color: textHint(context)),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: textHint(context)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              size: 18, color: textHint(context)),
                          onPressed: _searchCtrl.clear,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _candidates.isEmpty
                ? Center(
                    child: Text('没有可添加的应用',
                        style: TextStyle(color: textHint(context))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: _candidates.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: dividerColor(context),
                      indent: 52,
                    ),
                    itemBuilder: (context, i) {
                      final entry = _candidates[i];
                      return GlassListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accentOf(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(entry.icon,
                              color: accentOf(context), size: 18),
                        ),
                        title: Text(entry.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                        trailing: Icon(Icons.add_circle_outline_rounded,
                            color: accentOf(context), size: 22),
                        onTap: () => Navigator.of(context).pop(entry),
                      );
                    },
                  ),
          ),
          if (bottomInset > 0) SizedBox(height: bottomInset),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
