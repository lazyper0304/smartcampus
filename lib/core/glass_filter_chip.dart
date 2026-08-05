import 'package:flutter/material.dart';

import '../main.dart' show accentColorNotifier;
import 'theme_utils.dart';

/// 玻璃筛选按钮（chips 形态）——多值横滚筛选按钮（如全校课表学院筛选）用。
///
/// 保持独立按钮形态；等分分段栏请用 [GlassCategoryBar]（glass_category_bar.dart）。
/// ⚠️ 命名避开 liquid_glass_widgets 的 `GlassChip`，故取名 GlassFilterChip。
/// - 半透明渐变 + 白色高光描边（与内容卡 contentCardGlass 同款参数）
/// - 选中态：accent 玻璃渐变 + accent 描边 + accent 文字加粗
/// - 200ms 切换动画
class GlassFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 圆角 / 字号 / 内边距
  final double radius;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.radius = 16,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColorNotifier.value;
    final base = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [
                    accent.withValues(alpha: 0.30),
                    accent.withValues(alpha: 0.22),
                  ]
                : [
                    base.withValues(alpha: isDark ? 0.55 : 0.45),
                    base.withValues(alpha: isDark ? 0.48 : 0.38),
                  ],
            stops: const [0.0, 0.45],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.45)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : textPrimary(context),
          ),
        ),
      ),
    );
  }
}
