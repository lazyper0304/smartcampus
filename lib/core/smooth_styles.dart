import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';
import 'theme_utils.dart';

/// 品牌色 yibinBlue
const Color _yibinBlue = Color(0xFF191999);

/// 基于 yibinBlue 的浅色调色板——与 App 浅色主题兼容
const SmoothPalette yibinBluePalette = SmoothPalette(
  accent: _yibinBlue,
  accentBright: Color(0xFF3B3BAD),
  accentDeep: Color(0xFF0F0F7A),
  fillTop: Color(0xFFFFFFFF),
  fillBottom: Color(0xFFF5F5FF),
);

/// 深色调色板
const SmoothPalette yibinBlueDarkPalette = SmoothPalette(
  accent: _yibinBlue,
  accentBright: Color(0xFF5C5CFF),
  accentDeep: Color(0xFF0F0F7A),
  fillTop: Color(0xFF2A2A3E),
  fillBottom: Color(0xFF1E1E32),
);

/// 获取主题对应的 SmoothStyle
SmoothStyle smoothStyle(BuildContext context) {
  final dark = isDark(context);
  return SmoothStyle(
    palette: dark ? yibinBlueDarkPalette : yibinBluePalette,
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
    highlightColor: _yibinBlue.withValues(alpha: dark ? 0.25 : 0.12),
    showSheen: false,
    showRipple: false,
    showGlow: false,
    showSquash: false,
    showCrest: false,
    revealContent: true,
    leadingGlow: false,
  );
}

/// 获取主题对应的 SmoothSelect 高亮
SmoothHighlight smoothHighlight(BuildContext context) {
  final dark = isDark(context);
  return SmoothHighlight(
    color: _yibinBlue.withValues(alpha: dark ? 0.30 : 0.10),
    borderRadius: BorderRadius.circular(10),
    insets: const EdgeInsets.all(3),
    shadows: [
      BoxShadow(
        color: _yibinBlue.withValues(alpha: dark ? 0.20 : 0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
    checkColor: dark ? const Color(0xFF8C8CFF) : _yibinBlue,
  );
}
