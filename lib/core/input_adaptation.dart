import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 多输入适配（触控 / 鼠标 / 键盘）集中模块。
///
/// - [adaptiveVisualDensity]：按可用宽度切换组件密度
///   （触控 comfortable 宽松 / 桌面 compact 紧凑）
/// - [Clickable]：可点击元素统一接入鼠标手型光标 + 键盘 Enter/空格
///   激活 + 悬停/焦点高亮（触控无 hover/focus，行为与 GestureDetector 一致）
/// - [AppShortcuts]：全局快捷键（Esc 返回上一页，桌面习惯）

/// 触控（窄屏）用 comfortable：触控目标间距更大、更易点按；
/// 桌面 / 平板横屏（宽屏 ≥760）用 compact：信息更密集、接近桌面应用观感。
VisualDensity adaptiveVisualDensity(double width) =>
    width >= kInputDensityBreakpoint
        ? VisualDensity.compact
        : VisualDensity.comfortable;

/// 密度切换断点（与分栏断点一致）。
const double kInputDensityBreakpoint = 760.0;

/// 可点击包装：鼠标 click 光标 + 键盘 Enter/空格 激活 + 悬停/焦点高亮。
///
/// 内部组合 [FocusableActionDetector]（光标 + 键盘 Actions + 焦点管理）与
/// [GestureDetector]（触控/鼠标点按）。触控设备上 hover/focus 均不触发，
/// 表现与普通 GestureDetector 完全一致，零回归。
class Clickable extends StatefulWidget {
  /// 内容（与 [builder] 二选一；提供 builder 时忽略）。
  final Widget? child;
  final VoidCallback? onTap;

  /// 交互时的鼠标光标（默认手型）。
  final MouseCursor cursor;

  /// 高亮层的圆角（与卡片圆角对齐）。
  final double borderRadius;

  /// 悬停/焦点高亮颜色（默认主题 primary）。
  final Color? focusColor;

  /// 自定义内容构建器：接收当前 hover/focus 状态，返回内容 widget。
  /// 提供后 [child] 被忽略，且**不再叠加默认整卡高亮层**——调用方可
  /// 自行实现"以图标为中心"的光效（如宫格卡片的图标光晕）。
  final Widget Function(BuildContext context, bool hovered, bool focused)?
      builder;

  const Clickable({
    super.key,
    this.child,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
    this.borderRadius = 12,
    this.focusColor,
    this.builder,
  });

  @override
  State<Clickable> createState() => _ClickableState();
}

class _ClickableState extends State<Clickable> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final focusColor =
        widget.focusColor ?? Theme.of(context).colorScheme.primary;
    // 自定义 builder 时由调用方负责渲染高亮/光效，不再叠默认整卡高亮
    final hasCustomBuilder = widget.builder != null;
    final content = hasCustomBuilder
        ? widget.builder!(context, _hovered, _focused)
        : (widget.child ?? const SizedBox.shrink());
    return FocusableActionDetector(
      // 键盘 Enter / 空格 触发点击（ActivateIntent）
      actions: {
        if (interactive)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap!(),
          ),
      },
      // 悬停/聚焦时显示手型光标
      mouseCursor: interactive ? widget.cursor : SystemMouseCursors.basic,
      onShowHoverHighlight:
          interactive ? (v) => setState(() => _hovered = v) : null,
      onShowFocusHighlight:
          interactive ? (v) => setState(() => _focused = v) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        // ⚠️ 约束处理两个坑（勿改）：
        // ① fit 保持默认 loose + alignment: center——Stack 默认 topStart 会把
        // loose 约束下收缩的内容（宫格 Column）顶到左上 → "图标偏左"（适配后
        // Clickable 引入的回归）；
        // ② 禁 StackFit.expand：expand 用 constraints.biggest 生成 tight，
        // 在高度无界容器（ListView 内 Column(stretch) 的卡片）里把 ∞ 高度
        // tight 化 → 布局爆炸、"课表卡片消失"。
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.loose,
          children: [
            content,
            // 默认悬停/焦点高亮层（桌面键盘导航可见焦点位置；
            // 覆盖整卡矩形，仅未提供自定义 builder 时使用）
            if (!hasCustomBuilder && (_hovered || _focused))
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: focusColor
                          .withValues(alpha: _focused ? 0.14 : 0.06),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 全局快捷键包装：Esc 返回上一页（桌面习惯）。
///
/// [onEscape] 由调用方注入（通过 MaterialApp.navigatorKey 触达 Navigator，
/// 因为本组件位于 Navigator 之上、无法直接 Navigator.of 查找到）。
/// 内部 [Focus] autofocus 让快捷键立即可用。
class AppShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEscape;

  const AppShortcuts({
    super.key,
    required this.child,
    this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (onEscape != null)
          const SingleActivator(LogicalKeyboardKey.escape): () => onEscape!(),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
