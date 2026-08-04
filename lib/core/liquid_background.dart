import 'package:flutter/material.dart';
import 'package:fluid_background/fluid_background.dart';

import '../main.dart';

/// 液态玻璃背景：主题渐变底色 + 动态流体气泡（fluid_background 包）。
///
/// 首页 / 全局路由底层 / 登录页等所有界面统一使用。
/// 液态玻璃模糊的是「背景内容」——纯色背景模糊后仍是纯色，玻璃会显得
/// 平坦；动态气泡被底部导航栏/玻璃卡片模糊折射后才有真实玻璃质感。
///
/// 模块化说明：所有页面背景必须使用本组件，禁止手写纯色背景。
class LiquidBackground extends StatelessWidget {
  /// 覆盖在背景之上的内容（可选，全局路由底层使用）
  final Widget? child;

  /// 气泡是否以正常速度漂移（默认 true；false 时接近静止）
  final bool animated;

  /// 自定义颜色：同时用于渐变底色与气泡颜色（默认跟随主题：
  /// 浅色 accent 掺白渐变 + 清新气泡；深色暗黑渐变 + 霓虹气泡）
  final List<Color>? colors;

  const LiquidBackground({
    super.key,
    this.child,
    this.animated = true,
    this.colors,
  });

  /// 主题渐变（浅色 accent 掺白系 / 深色暗黑系）
  List<Color> _themeGradient(BuildContext context) {
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
  List<Color> _themeBubbles(BuildContext context) {
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
    // ValueListenableBuilder 监听：设置/重置背景时立即刷新（Stateless
    // 直接读 value 不会响应变化）。
    return ValueListenableBuilder<String?>(
      valueListenable: backgroundNotifier,
      builder: (context, customBg, _) {
        if (customBg != null && customBg.isNotEmpty) {
          // ⚠️ 有自定义背景时透出全局背景图，但必须保留 child（页面内容）！
          return child ?? const SizedBox.shrink();
        }
        return _buildDefault(context);
      },
    );
  }

  Widget _buildDefault(BuildContext context) {
    final gradientColors = colors ?? _themeGradient(context);
    final bubbleColors = colors ?? _themeBubbles(context);

    // 动态流体气泡层（气泡彩色渐隐圆 + 内置 blur，缓慢漂移）
    // ⚠️ 性能：velocity 已从 55 降至 28（持续动画是功耗主源，所有页面
    // 背景都在跑）；形变周期 4s → 6s 进一步降低 GPU 负载。
    final bubbles = FluidBackground(
      initialPositions: InitialOffsets.random(bubbleColors.length),
      initialColors: InitialColors.custom(bubbleColors),
      velocity: animated ? 28 : 10,
      bubblesSize: 100,
      sizeChangingRange: const [80, 150],
      bubbleMutationDuration: const Duration(seconds: 6),
      child: const SizedBox.expand(),
    );

    return Stack(
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
        bubbles,
        ?child,
      ],
    );
  }
}
