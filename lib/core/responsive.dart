import 'package:flutter/material.dart';

/// 宽屏断点：宽度 ≥ 600 视为平板 / 桌面 / 横屏手机，导航切换为侧边 Rail。
/// 与 Material Design 3 的「compact → expanded」断点一致。
const double kWideBreakpoint = 600.0;

/// 侧边导航栏宽度（宽屏模式）。
const double kRailWidth = 88.0;

/// 列表页（首页、设置等）在宽屏下的最大内容宽度，避免拉伸过宽。
const double kContentMaxWidth = 760.0;

/// 列表 / 详情 / 表单类二级页在宽屏下的内容限宽（SimplePage.contentMaxWidth
/// 推荐值）。与 [kContentMaxWidth] 同值，语义上区分「主界面内容」与「二级页」。
const double kListMaxWidth = kContentMaxWidth;

/// 数据密集页（课表 / 校历 / 成绩 / 空闲教室 / 全校查询等）在宽屏下的内容限宽，
/// 允许比普通列表页更宽以容纳更多信息列。
const double kDenseMaxWidth = 1080.0;

/// 应用网格页在宽屏下的最大内容宽度（允许比列表页更宽以容纳更多列）。
const double kGridMaxWidth = 1200.0;

/// 窄屏下浮动玻璃底部导航栏（`GlassTabBar.bottom`）需要的滚动内容底部留白。
///
/// 该导航栏是**浮层**，不占据布局空间，会直接盖住滚动内容的尾部。
/// 因此所有可滚动的主页面（首页 / 应用 / 设置）都必须预留这段底部 padding，
/// 否则最后一张卡片会被遮挡且无法滑出。
const double kBottomBarSafePadding = 120.0;

/// 宽屏（侧边 Rail）下不存在底部浮动栏，仅保留常规呼吸空间。
const double kBottomSafePaddingWide = 32.0;

/// 是否为宽屏（横屏 / 平板 / 桌面）。
bool isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= kWideBreakpoint;

/// 主页面滚动内容应使用的底部留白：窄屏避让浮动导航栏，宽屏用常规间距。
double bottomBarSafePadding(BuildContext context) =>
    isWideScreen(context) ? kBottomSafePaddingWide : kBottomBarSafePadding;

/// 根据「可用宽度」计算应用网格列数，自适应横屏与桌面宽屏。
/// 档位与首页「常用功能」宫格对齐（3 → 4 → 6 → 8），
/// 调用方须传入**实际渲染宽度**（LayoutBuilder 约束），而非屏幕总宽，
/// 否则在 MaxWidthContent 限宽内会出现列数虚高、卡片被挤压。
int appGridColumns(double availableWidth) {
  if (availableWidth >= 1080) return 8;
  if (availableWidth >= 760) return 6;
  // 手机一律一排四列（用户明确要求）：可用宽度 ≥ 260 即 4 列——
  // 覆盖所有屏宽 ≥ 292 的手机（含 320 老机型，扣除 32 padding 后
  // 可用 288 仍落入 4 列档）；3 列仅留给极端窄屏（< 260，分屏/小窗）。
  if (availableWidth >= 260) return 4;
  return 3;
}

/// 宫格卡片文字自适应字号：随卡片**实际宽度**缩放（与图标方块 45% 同链路，
/// 大屏卡片大字号大、窄屏小卡片小字号），clamp 到 [10, 14] 保证可读性。
/// 窄屏 3 列卡片（~119px）≈ 10.5，大屏 8 列（~152px）≈ 13。
double adaptiveTileFontSize(double cardWidth) =>
    (cardWidth * 0.085).clamp(10.0, 14.0);

/// 列表卡片（分组卡 / 信息卡）内部元素缩放系数：随卡片**实际宽度**自适应，
/// 避免大屏宽卡片"大卡小内容"。以 520px 为基准（scale=1.0），
/// clamp 到 [1.0, 1.2]；窄屏卡片 < 520 时为 1.0，行为与固定尺寸完全一致。
/// 用法：`IosListTile(..., scale: adaptiveCardScale(cardWidth))`。
double adaptiveCardScale(double cardWidth) =>
    (cardWidth / 520).clamp(1.0, 1.2);

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
    // 用 LayoutBuilder + SizedBox 强制给子项 tight 宽度（min(父最大, maxWidth)），
    // 避免 Center 把父约束变 loose 导致 Column(stretch) 失效（卡片宽度不一）。
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.clamp(0.0, maxWidth);
        return Align(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          child: SizedBox(width: w, child: padded),
        );
      },
    );
  }
}
