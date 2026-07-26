import 'package:flutter/material.dart';

/// 宽屏断点：宽度 ≥ 600 视为平板 / 桌面 / 横屏手机，导航切换为侧边 Rail。
/// 与 Material Design 3 的「compact → expanded」断点一致。
const double kWideBreakpoint = 600.0;

/// 侧边导航栏宽度（宽屏模式）。
const double kRailWidth = 88.0;

/// 列表页（首页、设置等）在宽屏下的最大内容宽度，避免拉伸过宽。
const double kContentMaxWidth = 760.0;

/// 应用网格页在宽屏下的最大内容宽度（允许比列表页更宽以容纳更多列）。
const double kGridMaxWidth = 1200.0;

/// 是否为宽屏（横屏 / 平板 / 桌面）。
bool isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= kWideBreakpoint;

/// 根据「可用宽度」计算应用网格列数，自适应横屏与桌面宽屏。
int appGridColumns(double availableWidth) {
  if (availableWidth >= 1000) return 6;
  if (availableWidth >= 760) return 5;
  if (availableWidth >= 520) return 4;
  return 3;
}

/// 将内容居中并限制最大宽度，避免宽屏下拉伸过宽。
///
/// 在窄屏（可用宽度 < [maxWidth]）时不产生副作用：内容仍占满宽度。
class MaxWidthContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool center;

  const MaxWidthContent({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding = EdgeInsets.zero,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    final padded =
        padding == EdgeInsets.zero ? child : Padding(padding: padding, child: child);
    final constrained = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: padded,
    );
    return center ? Center(child: constrained) : constrained;
  }
}
