import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show GlassStatusBarStyle;

import 'liquid_background.dart';
import 'responsive.dart';

/// 转发大屏限宽常量（当前二级页面铺满全屏未启用，保留备用）。
export 'responsive.dart'
    show kListMaxWidth, kDenseMaxWidth, kGridMaxWidth;

/// GlassPage 的替代方案 — 无玻璃遮罩，内容全屏显示。
///
/// 保持与 GlassPage 相同的 API 签名（statusBarStyle、edgeToEdge），
/// 但移除 AdaptiveLiquidGlassLayer 带来的毛玻璃遮罩层，让背景直接透出。
///
/// [background] 为 true 时自动内置主界面同款液态玻璃背景
/// （LiquidBackground，渐变 + 动态气泡），独立二级页面默认开启；
/// 主界面 tab 页（MainScreen 已提供 GlassScaffold 背景）传 false 避免叠加。
///
/// [contentMaxWidth]（默认 0 = 不限宽）：> 0 时内容（含 AppBar）在大屏下
/// 居中限宽、两侧透出背景。⚠️ 当前产品决策：所有二级页面**铺满全屏**，
/// 全部页面使用默认值 0，不再传限宽参数；该参数与限宽逻辑保留备用。
class SimplePage extends StatefulWidget {
  final Widget child;
  final GlassStatusBarStyle statusBarStyle;
  final bool edgeToEdge;
  final bool background;
  final double contentMaxWidth;

  const SimplePage({
    super.key,
    required this.child,
    this.statusBarStyle = GlassStatusBarStyle.auto,
    this.edgeToEdge = false,
    this.background = true,
    this.contentMaxWidth = 0,
  });

  @override
  State<SimplePage> createState() => _SimplePageState();
}

class _SimplePageState extends State<SimplePage> {
  SystemUiOverlayStyle? _previousOverlayStyle;

  @override
  void initState() {
    super.initState();
    if (widget.edgeToEdge) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyStatusBarStyle();
  }

  @override
  void didUpdateWidget(SimplePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusBarStyle != widget.statusBarStyle) {
      _applyStatusBarStyle();
    }
  }

  @override
  void dispose() {
    if (_previousOverlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_previousOverlayStyle!);
    }
    super.dispose();
  }

  void _applyStatusBarStyle() {
    if (widget.statusBarStyle == GlassStatusBarStyle.none) return;

    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final bool isDark = brightness == Brightness.dark;

    final bool useLightIcons = switch (widget.statusBarStyle) {
      GlassStatusBarStyle.light => true,
      GlassStatusBarStyle.dark => false,
      GlassStatusBarStyle.auto => isDark,
      GlassStatusBarStyle.none => false,
    };

    final newStyle =
        useLightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    _previousOverlayStyle ??= SystemUiOverlayStyle.light;
    SystemChrome.setSystemUIOverlayStyle(newStyle);
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;

    if (widget.statusBarStyle != GlassStatusBarStyle.none) {
      final Brightness brightness = MediaQuery.platformBrightnessOf(context);
      final bool isDark = brightness == Brightness.dark;
      final bool useLightIcons = switch (widget.statusBarStyle) {
        GlassStatusBarStyle.light => true,
        GlassStatusBarStyle.dark => false,
        GlassStatusBarStyle.auto => isDark,
        GlassStatusBarStyle.none => false,
      };
      content = AnnotatedRegion<SystemUiOverlayStyle>(
        value: useLightIcons
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: content,
      );
    }

    // 独立二级页面默认自带主界面同款液态玻璃背景（模块化组件）；
    // ⚠️ LiquidBackground 内部监听自定义背景（backgroundNotifier）：
    // 外观设置选了背景图时不渲染渐变（避免盖住全局背景图）。
    if (widget.background) {
      content = LiquidBackground(child: content);
    }

    // 大屏限宽：内容（含 AppBar）居中、两侧透出背景（iPad 风格）。
    // 窄屏下父宽度 < contentMaxWidth，ConstrainedBox 不产生约束，行为不变。
    // ⚠️ 用 Align(topCenter) + ConstrainedBox 给 tight 上限：避免 Center 的
    // loose 约束让 Scaffold 宽度缩水（AppBar 与 body 宽度不一致）。
    if (widget.contentMaxWidth > 0) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.contentMaxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}
