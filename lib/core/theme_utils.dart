import 'package:flutter/material.dart';

/// 品牌色
const Color yibinBlue = Color(0xFF191999);

/// 是否为深色模式
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
