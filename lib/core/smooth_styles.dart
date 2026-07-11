import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

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

/// 全局统一 SmoothStyle（浅色主题）
const SmoothStyle yibinBlueStyle = SmoothStyle(
  palette: yibinBluePalette,
  radius: 14,
  headerPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
  optionPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
  titleTextStyle: TextStyle(
    color: Color(0xFF1A1A2E),
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  ),
  contentTextStyle: TextStyle(
    color: Color(0xFF4A4A6A),
    fontSize: 13,
    height: 1.5,
  ),
  highlightColor: Color(0x1F191999),
  showSheen: false,
  showRipple: false,
  showGlow: false,
  showSquash: false,
  showCrest: false,
  revealContent: true,
  leadingGlow: false,
);

/// SmoothSelect 的选项高亮——半透明蓝色底 + 蓝色选中勾
final SmoothHighlight yibinBlueHighlight = SmoothHighlight(
  color: const Color(0xFF191999).withOpacity(0.10),
  borderRadius: BorderRadius.circular(10),
  insets: const EdgeInsets.all(3),
  shadows: [
    BoxShadow(
      color: const Color(0xFF191999).withOpacity(0.08),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ],
  checkColor: const Color(0xFF191999),
);
