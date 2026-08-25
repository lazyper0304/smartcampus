/// 实时倒计时文本组件。
///
/// 用 [Timer.periodic] 每秒重算剩余时长并仅重建自身，避免父卡片整体重绘；
/// [dispose] 中取消定时器，无泄漏。用于首页高亮项与二级页详情。
library;

import 'dart:async';

import 'package:flutter/material.dart';

class LiveCountdown extends StatefulWidget {
  final DateTime target;
  final bool showSeconds;
  final TextStyle? style;
  final Color? accent;

  const LiveCountdown({
    super.key,
    required this.target,
    this.showSeconds = true,
    this.style,
    this.accent,
  });

  @override
  State<LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<LiveCountdown> {
  Duration _remaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final r = widget.target.difference(DateTime.now());
    if (_remaining != r) setState(() => _remaining = r);
  }

  @override
  void didUpdateWidget(covariant LiveCountdown old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _remaining;
    final base = widget.style ?? const TextStyle();
    if (r.isNegative) {
      return Text('已到来', style: widget.accent == null
          ? base
          : base.copyWith(color: widget.accent));
    }
    final d = r.inDays;
    final h = r.inHours % 24;
    final m = r.inMinutes % 60;
    final s = r.inSeconds % 60;
    final text = widget.showSeconds
        ? '$d天 $h时 $m分 $s秒'
        : '$d天 $h时 $m分';
    return Text(
      text,
      style: widget.accent == null ? base : base.copyWith(color: widget.accent),
    );
  }
}
