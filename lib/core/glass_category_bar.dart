import 'package:flutter/material.dart';

import '../main.dart' show accentColorNotifier;
import 'ios_kit.dart';
import 'theme_utils.dart';

/// 玻璃分类栏通用组件
///
/// 统一「分类/分段选择」的玻璃样式（项目规范：不用 Material SegmentedControl /
/// SegmentedButton）：
/// - 玻璃卡容器（[contentCardGlass] 静态玻璃，全设备稳定）
/// - 项间 0.5px 竖分割线（黑/白 8%，与 IosListGroup 分隔线同规格）
/// - 选中项 accent 12% 圆角背景 + accent 文字/图标，带 200ms 切换动画
/// - `IntrinsicHeight + Row(stretch)` 保证分割线与选中背景等高
///
/// 用法：
/// ```dart
/// GlassCategoryBar(
///   items: const [
///     GlassCategoryItem(label: '近7天', icon: Icons.today),
///     GlassCategoryItem(label: '近30天', icon: Icons.date_range),
///   ],
///   selectedIndex: _viewMode,
///   onSelected: (i) => setState(() => _viewMode = i),
/// )
/// ```
class GlassCategoryItem {
  final String label;
  final IconData? icon;

  const GlassCategoryItem({required this.label, this.icon});
}

class GlassCategoryBar extends StatelessWidget {
  final List<GlassCategoryItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 图标在文字上方（主界面应用页 tab 样式）还是左侧（二级页分段样式）
  final bool vertical;

  /// 容器卡片圆角 / 内边距 / 选中项背景圆角
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry padding;
  final double itemRadius;

  /// 文字字号（vertical 模式图标 20 / 文字 [labelFontSize]；横排模式图标 16）
  final double labelFontSize;

  const GlassCategoryBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.vertical = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.all(4),
    this.itemRadius = 10,
    this.labelFontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColorNotifier.value;
    final lineColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return contentCardGlass(
      context: context,
      borderRadius: borderRadius,
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          // stretch：分割线与选中背景均撑满内容高度（IntrinsicHeight 提供）
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(width: 0.5, color: lineColor),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(itemRadius),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: _buildItemContent(context, i, accent),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemContent(BuildContext context, int i, Color accent) {
    final selected = i == selectedIndex;
    final color = selected ? accent : textSecondary(context);
    final label = Text(
      items[i].label,
      style: TextStyle(
        fontSize: labelFontSize,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: color,
      ),
    );
    final icon = items[i].icon;
    if (icon == null) return label;

    // 图标选中动画：选中时放大 1.18（Transform.scale 不占布局空间，
    // 避免 IntrinsicHeight/分割线高度跳动）+ 颜色 200ms 平滑过渡。
    // 未选中恢复 1.0，切换时隐式动画自动播放（应用页分类 tab 与
    // 二级页分段共用，视觉统一）。
    Widget animatedIcon(IconData data, double size) {
      return AnimatedScale(
        scale: selected ? 1.18 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: color),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (context, c, _) =>
              Icon(data, size: size, color: c ?? color),
        ),
      );
    }

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          animatedIcon(icon, 20),
          const SizedBox(height: 4),
          label,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        animatedIcon(icon, 16),
        const SizedBox(width: 4),
        label,
      ],
    );
  }
}
