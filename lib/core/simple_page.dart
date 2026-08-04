import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show GlassStatusBarStyle;

import 'liquid_background.dart';

/// GlassPage 的替代方案 — 无玻璃遮罩，内容全屏显示。
///
/// 保持与 GlassPage 相同的 API 签名（statusBarStyle、edgeToEdge），
/// 但移除 AdaptiveLiquidGlassLayer 带来的毛玻璃遮罩层，让背景直接透出。
///
/// [background] 为 true 时自动内置主界面同款液态玻璃背景
/// （LiquidBackground，渐变 + 动态气泡），独立二级页面默认开启；
/// 主界面 tab 页（MainScreen 已提供 GlassScaffold 背景）传 false 避免叠加。
class SimplePage extends StatefulWidget {
  final Widget child;
  final GlassStatusBarStyle statusBarStyle;
  final bool edgeToEdge;
  final bool background;

  const SimplePage({
    super.key,
    required this.child,
    this.statusBarStyle = GlassStatusBarStyle.auto,
    this.edgeToEdge = false,
    this.background = true,
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

    return content;
  }
}
