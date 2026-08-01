import 'package:flutter/material.dart';

import '../main.dart' show accentColorNotifier;
import 'theme_utils.dart';

/// 药丸胶囊式分段切换栏
///
/// 整体为一个圆角胶囊轨道（主题色浅底），内部选中块是实心主题色胶囊滑块，
/// 用 `AnimatedAlign` 在胶囊内平滑滑动切换；选中文字白色加粗、未选中弱化。
/// 与 [TabController] 配合：点击 / 外部 TabBarView 手势滑动均能驱动滑块同步。
class PillTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const PillTabBar({
    super.key,
    required this.controller,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    assert(labels.length >= 2, 'PillTabBar 至少需要 2 个标签');
    final accent = accentColorNotifier.value;
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark(context) ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 滑动滑块：选中块在胶囊内平滑移动（覆盖当前 tab 所在分区）
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: _alignmentFor(controller.index, labels.length),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 文字层
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                _pillItem(context, i, labels[i], accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillItem(BuildContext context, int index, String label, Color accent) {
    final selected = controller.index == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.animateTo(index),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : textHint(context),
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }

  /// 滑块对齐位置：n 个 tab 均匀分布，index 0 → -1（最左）、最后 → 1（最右）
  Alignment _alignmentFor(int index, int n) {
    if (n <= 1) return Alignment.center;
    return Alignment(-1 + 2 * index / (n - 1), 0);
  }
}
