import 'package:flutter/material.dart';

/// 大屏分栏断点：可用宽度 ≥ 此值时左右两栏并排，否则上下堆叠。
///
/// 取 760（与列表页限宽一致）：保证分栏后每栏仍有合理阅读宽度；
/// 手机竖屏 / 横屏（内容区 < 760）自动回落单列，零回归。
const double kSplitBreakpoint = 760.0;

/// 自适应分栏布局：宽屏（平板 / Windows 桌面）左右两栏并排，
/// 窄屏上下堆叠（等价于普通 Column，行为不变）。
///
/// 纯屏幕宽度驱动——平板与 Windows 共用同一套宽屏布局，无平台分支。
/// 用于首页 / 设置等主界面页在大屏下的信息重组（如
/// 「常用功能 + 今日课程」左栏、「校园新闻」右栏）。
///
/// ⚠️ 调用方须把本组件放在内容限宽（MaxWidthContent）**内部**，
/// 用 LayoutBuilder 的**实际渲染宽度**判断（勿用 MediaQuery 全宽，
/// 否则侧栏占位会导致列数/断点判断虚高）。
class AdaptiveSplitView extends StatelessWidget {
  /// 窄屏在下（宽屏在右）的组件。
  final Widget left;

  /// 窄屏在下（宽屏在右）的组件。
  final Widget right;

  /// 分栏断点，默认 [kSplitBreakpoint]。
  final double breakpoint;

  /// 宽屏时左栏弹性权重。
  final int leftFlex;

  /// 宽屏时右栏弹性权重。
  final int rightFlex;

  /// 两栏间距（宽屏为水平、窄屏为垂直）。
  final double gap;

  /// 宽屏两栏的交叉轴对齐（窄屏始终 stretch 保证同宽）。
  final CrossAxisAlignment crossAxisAlignment;

  const AdaptiveSplitView({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = kSplitBreakpoint,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.gap = 16,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= breakpoint) {
          // 宽屏：左右两栏并排
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(flex: leftFlex, child: left),
              SizedBox(width: gap),
              Expanded(flex: rightFlex, child: right),
            ],
          );
        }
        // 窄屏：上下堆叠（stretch 保证与原有单列布局宽度一致）
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            left,
            SizedBox(height: gap),
            right,
          ],
        );
      },
    );
  }
}
