import 'package:flutter/material.dart';

/// ============================================================================
/// 白底界面（2026-09-20 重构）：全项目不再使用「主题色」——主界面为白色，
/// 强调/选中/按钮等交互层统一用中性「墨色」（浅色近黑 / 深色近白），
/// 颜色只由各模块图标自身承载（见 home/app_data.dart 的 AppEntry.color）。
/// ============================================================================

/// 墨色（浅色模式）：按钮、选中态、强调文字的中性前景色
const Color kInkLight = Color(0xFF111114);

/// 墨色（深色模式）：深色下反向为近白
const Color kInkDark = Color(0xFFF5F4F2);

/// 主界面纯白底（浅色模式；卡片/导航玻璃均以白色为基）
const Color kSurfaceWhite = Color(0xFFFFFFFF);

/// 浅色模式页面底色（白色之上的极浅灰，用于分组背景）
const Color kGroupedLight = Color(0xFFF5F5F7);

/// 浅色模式毛玻璃基色（半透明白，用于卡片/宫格方块）
const Color kGlassBaseLight = Color(0xFFFFFFFF);

/// 是否深色模式
bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// 根据主题返回颜色：亮色模式用 [light], 深色模式用 [dark]
Color adaptColor(BuildContext context, Color light, Color dark) =>
    isDark(context) ? dark : light;

/// 深色模式下的卡片背景色
const Color darkCard = Color(0xFF2A2A3E);
/// 深色模式下的页面背景色
const Color darkBackground = Color(0xFF1A1A2E);
/// 深色模式下的表面色
const Color darkSurface = Color(0xFF121212);

/// 深色模式下的主文字色
const Color darkTextPrimary = Color(0xFFE8E8F0);
/// 深色模式下的次要文字色
const Color darkTextSecondary = Color(0xFF9E9EB0);
/// 深色模式下的弱化文字色
const Color darkTextHint = Color(0xFF6E6E80);

/// 浅色模式下的主文字色
const Color lightTextPrimary = Color(0xFF1A1A2E);
/// 浅色模式下的次要文字色
const Color lightTextSecondary = Color(0xFF6E6E80);
/// 浅色模式下的弱化文字色
const Color lightTextHint = Color(0xFF9E9EB0);

/// Windows 统一微软雅黑：不设置时系统默认 Segoe UI 与中文雅黑 fallback
/// 混排，中英文字重渲染不一致（"有粗有细"）；统一雅黑后全局一致。
/// 全项目 Windows 端字体唯一来源，禁止散落字面量。
const String kWindowsFontFamily = 'Microsoft YaHei';
/// Windows 字体回退链
const List<String> kWindowsFontFallback = ['Microsoft YaHei UI', 'SimHei'];

/// 获取主题对应的主文字色
Color textPrimary(BuildContext context) =>
    adaptColor(context, lightTextPrimary, darkTextPrimary);

/// 获取主题对应的次要文字色
Color textSecondary(BuildContext context) =>
    adaptColor(context, lightTextSecondary, darkTextSecondary);

/// 获取主题对应的弱化文字色
Color textHint(BuildContext context) =>
    adaptColor(context, lightTextHint, darkTextHint);

/// 获取主题对应的分割线颜色
Color dividerColor(BuildContext context) =>
    adaptColor(context, const Color(0xFFEEEEF4), const Color(0xFF3A3A4E));
