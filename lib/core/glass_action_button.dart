import 'package:flutter/material.dart';

import '../main.dart' show accentColorNotifier;
import 'theme_utils.dart';

/// 玻璃操作按钮（查询 / 生成订单 / 重试等大按钮）
///
/// 与 [GlassFilterChip]（glass_filter_chip.dart）同款玻璃语言：
/// - primary（默认）：主题色玻璃渐变（30%→22%）+ 主题色描边 + 主题色文字加粗
/// - secondary：中性玻璃（白/深灰 45%→38%）+ 白描边 + 主题文字（次要操作）
/// - 支持 icon / loading（转圈替换图标）/ disabled（弱化）/ 自定义主题色（如安全页红色）
/// - Material + InkWell 提供水波纹反馈
///
/// ⚠️ 命名避开 liquid_glass_widgets 的 `GlassButton`。
class GlassActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  /// 主题色（默认全局 accent；安全页传红等特殊色）
  final Color? color;

  /// true = 中性玻璃（次要按钮）；false = 主题色玻璃（主操作）
  final bool secondary;

  final double height;
  final double borderRadius;
  final bool fullWidth;
  final double fontSize;

  const GlassActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.color,
    this.secondary = false,
    this.height = 48,
    this.borderRadius = 12,
    this.fullWidth = true,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? accentColorNotifier.value;
    final base = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final enabled = onPressed != null && !loading;

    // 纯色填充（2026-09-20 去渐变）：次要=中性浅底，主要=墨色浅底
    final bgColor = secondary
        ? base.withValues(alpha: isDark ? 0.52 : 0.42)
        : accent.withValues(alpha: enabled ? 0.26 : 0.14);
    final fg = secondary
        ? (enabled ? textPrimary(context) : textHint(context))
        : (enabled ? accent : textHint(context));
    final borderColor = !enabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.25))
        : secondary
            ? (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.45))
            : accent.withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
          ),
          child: SizedBox(
            height: height,
            width: fullWidth ? double.infinity : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: fullWidth ? 0 : 20),
              child: Row(
                mainAxisSize:
                    fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  else if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
