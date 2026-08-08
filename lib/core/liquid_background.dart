import 'package:flutter/material.dart';
import 'package:fluid_background/fluid_background.dart';

import '../main.dart';

/// 页面级液态玻璃背景挂载计数：页面级背景（SimplePage / 页面自用）挂载时
/// 递增、卸载递减。全局垫底层（isGlobal: true）据此判断自己是否被覆盖：
/// 被覆盖时暂停气泡动画（省电），回到主界面（无页面级背景覆盖）自动恢复。
/// 用 TickerMode 暂停而非移除组件 → 气泡位置冻结、恢复无跳变。
final ValueNotifier<int> pageBgCount = ValueNotifier(0);

/// 液态玻璃背景：主题渐变底色 + 动态流体气泡（fluid_background 包）。
///
/// 首页 / 全局路由底层 / 登录页等所有界面统一使用。
/// 液态玻璃模糊的是「背景内容」——纯色背景模糊后仍是纯色，玻璃会显得
/// 平坦；动态气泡被底部导航栏/玻璃卡片模糊折射后才有真实玻璃质感。
///
/// 模块化说明：所有页面背景必须使用本组件，禁止手写纯色背景。
///
/// 功耗设计（2026-08-05 深度优化，不改样式）：
/// - [isGlobal] 垫底层：被页面级背景覆盖时气泡自动暂停（TickerMode）；
///   页面层（SimplePage 等）继续动画 → 每屏只跑一层气泡动画。
/// - 后台/锁屏：监听生命周期，整个子树 ticker 暂停（含页面内容动画），
///   前台恢复继续，零视觉变化。
class LiquidBackground extends StatefulWidget {
  /// 覆盖在背景之上的内容（可选，全局路由底层使用）
  final Widget? child;

  /// 气泡是否以正常速度漂移（默认 true；false 时接近静止）
  final bool animated;

  /// 自定义颜色：同时用于渐变底色与气泡颜色（默认跟随主题：
  /// 浅色 accent 掺白渐变 + 清新气泡；深色暗黑渐变 + 霓虹气泡）
  final List<Color>? colors;

  /// 全局垫底层标记（main.dart builder 使用）：不参与页面层计数，
  /// 被页面层覆盖时自动暂停气泡动画省电。
  final bool isGlobal;

  const LiquidBackground({
    super.key,
    this.child,
    this.animated = true,
    this.colors,
    this.isGlobal = false,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// 页面级背景计数是否已递增（postFrame 延后递增，dispose 用此标志
  /// 配对递减，避免"挂载后一帧内卸载"导致计数错乱）
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.isGlobal) {
      // ⚠️ 不能同步递增：initState 执行时全局垫底层（main.dart builder）
      // 的 ValueListenableBuilder<int>(pageBgCount) 可能正处于 build 阶段，
      // 同步通知会触发 "setState() called during build"（widget_test
      // SplashPage 挂载即暴露）。延迟到首帧后递增，语义不变（首帧气泡
      // 暂停逻辑照常生效），避免 build 期间通知监听者。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_counted) {
          _counted = true;
          pageBgCount.value++;
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!widget.isGlobal && _counted) {
      pageBgCount.value--;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state != _lifecycle) {
      setState(() => _lifecycle = state);
    }
  }

  /// 主题渐变（浅色 accent 掺白系 / 深色暗黑系）
  List<Color> _themeGradient() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColorNotifier.value;
    return isDark
        ? [
            Color.lerp(accent, const Color(0xFF1A1A2E), 0.82)!,
            Color.lerp(accent, const Color(0xFF000000), 0.88)!,
          ]
        : [
            Color.lerp(accent, Colors.white, 0.88)!,
            Color.lerp(accent, const Color(0xFFF2F5FF), 0.93)!,
          ];
  }

  /// 主题气泡色（浅色清新 / 深色霓虹，4 色）
  List<Color> _themeBubbles() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColorNotifier.value;
    return isDark
        ? [
            accent,
            const Color(0xFF5C5CFF),
            const Color(0xFF9A4DFF),
            const Color(0xFF2EC4B6),
          ]
        : [
            accent,
            const Color(0xFF7C8CFF),
            const Color(0xFFFF9E5E),
            const Color(0xFF4FC8C0),
          ];
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 外观设置自定义背景已提升到全局（main.dart builder）统一应用：
    // 有自定义背景图时不渲染本组件（其不透明渐变会盖住背景图），
    // 直接透出全局背景图；无自定义背景时正常渲染液态玻璃背景。
    return ValueListenableBuilder<String?>(
      valueListenable: backgroundNotifier,
      builder: (context, customBg, _) {
        if (customBg != null && customBg.isNotEmpty) {
          return widget.child ?? const SizedBox.shrink();
        }
        return _buildDefault();
      },
    );
  }

  Widget _buildDefault() {
    final gradientColors = widget.colors ?? _themeGradient();
    final bubbleColors = widget.colors ?? _themeBubbles();

    // 后台/锁屏：暂停整个子树 ticker（含页面内容动画），前台恢复继续
    final backgroundPaused = _lifecycle != AppLifecycleState.resumed;

    return TickerMode(
      enabled: !backgroundPaused,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 渐变底色（保证任何模式下页面整体观感）
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),
          // 动态流体气泡层
          // ⚠️ 性能：velocity 28 / 形变周期 6s（持续动画是功耗主源）。
          // 全局垫底层被页面级背景覆盖时暂停气泡（TickerMode，不重建组件
          // → 恢复无跳变），每屏只保留一层气泡动画。
          ValueListenableBuilder<int>(
            valueListenable: pageBgCount,
            builder: (context, count, _) {
              final overlaid = widget.isGlobal && count > 0;
              return TickerMode(
                enabled: widget.animated && !overlaid,
                child: FluidBackground(
                  initialPositions:
                      InitialOffsets.random(bubbleColors.length),
                  initialColors: InitialColors.custom(bubbleColors),
                  velocity: widget.animated ? 28 : 10,
                  bubblesSize: 100,
                  sizeChangingRange: const [80, 150],
                  bubbleMutationDuration: const Duration(seconds: 6),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
          ?widget.child,
        ],
      ),
    );
  }
}
