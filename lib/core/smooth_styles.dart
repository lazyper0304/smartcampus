import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';
import 'theme_utils.dart';

import '../main.dart';

/// 获取主题对应的 SmoothStyle
SmoothStyle smoothStyle(BuildContext context) {
  final dark = isDark(context);
  final accent = accentColorNotifier.value;
  final palette = SmoothPalette(
    accent: accent,
    accentBright: Color.lerp(accent, Colors.white, 0.3)!,
    accentDeep: Color.lerp(accent, Colors.black, 0.2)!,
    fillTop: dark
        ? Color.lerp(accent, const Color(0xFF2A2A3E), 0.6)!
        : Color.lerp(accent, Colors.white, 0.85)!,
    fillBottom: dark
        ? Color.lerp(accent, const Color(0xFF1E1E32), 0.7)!
        : Color.lerp(accent, Colors.white, 0.92)!,
  );
  return SmoothStyle(
    palette: palette,
    radius: 14,
    headerPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
    optionPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    titleTextStyle: TextStyle(
      color: textPrimary(context),
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    contentTextStyle: TextStyle(
      color: textSecondary(context),
      fontSize: 13,
      height: 1.5,
    ),
    highlightColor: accentColorNotifier.value.withValues(alpha: dark ? 0.25 : 0.12),
    showSheen: false,
    showRipple: false,
    showGlow: false,
    showSquash: false,
    showCrest: false,
    revealContent: true,
    leadingGlow: false,
  );
}

/// 获取主题对应的 Smooth 组件「玻璃版」样式（背景同色系填充）
///
/// smooth_dropdown 1.0.0 的卡片 painter（smooth_card_painter.dart）把填充
/// alpha 写死 0.90/0.92，半透明 palette 会被强制覆盖（真半透明不可行）。
/// 改为填充用 LiquidBackground 背景渐变同色系 → 卡片/下拉面板与背景
/// 融为一体，视觉即玻璃面板；accent 描边/顶部高光由 painter 绘制。
///
/// 用于 SmoothExpansionTile（成绩学期详情 / 教材订购 / 毕业要求）与
/// SmoothSelect（课程表学期 / 空闲教室条件）等所有 smooth 组件。
SmoothStyle smoothGlassStyle(BuildContext context) {
  final dark = isDark(context);
  final accent = accentColorNotifier.value;
  final top = dark
      ? Color.lerp(accent, const Color(0xFF1A1A2E), 0.82)!
      : Color.lerp(accent, Colors.white, 0.88)!;
  final bottom = dark
      ? Color.lerp(accent, const Color(0xFF000000), 0.88)!
      : Color.lerp(accent, const Color(0xFFF2F5FF), 0.93)!;
  final palette = SmoothPalette(
    accent: accent,
    accentBright: Color.lerp(accent, Colors.white, 0.3)!,
    accentDeep: Color.lerp(accent, Colors.black, 0.2)!,
    fillTop: top,
    fillBottom: bottom,
  );
  return smoothStyle(context).copyWith(palette: palette);
}

/// 获取主题对应的 SmoothSelect 高亮
SmoothHighlight smoothHighlight(BuildContext context) {  final dark = isDark(context);
  return SmoothHighlight(
    color: accentColorNotifier.value.withValues(alpha: dark ? 0.30 : 0.10),
    borderRadius: BorderRadius.circular(10),
    insets: const EdgeInsets.all(3),
    shadows: [
      BoxShadow(
        color: accentColorNotifier.value.withValues(alpha: dark ? 0.20 : 0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
    checkColor: dark ? const Color(0xFF8C8CFF) : accentColorNotifier.value,
  );
}
