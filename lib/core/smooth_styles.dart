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

/// 获取主题对应的 SmoothSelect 高亮
SmoothHighlight smoothHighlight(BuildContext context) {
  final dark = isDark(context);
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
