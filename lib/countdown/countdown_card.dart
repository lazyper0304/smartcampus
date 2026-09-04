/// 首页「倒计时」卡片：展示自定义倒计时目标（纯展示，编辑入口在 设置 → 倒计时）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/live_countdown.dart';
import '../core/theme_utils.dart';
import '../main.dart' show accentColorNotifier;
import '../widget/widget_service.dart';
import 'countdown_service.dart';

class CountdownCard extends StatefulWidget {
  const CountdownCard({super.key});

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  List<CustomTarget> _targets = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // 增删改/置顶后即时重载（管理页保存时触发变更信号）
    CountdownService.changed.addListener(_load);
    // 每分钟刷新一次，保证"天数"随时间自动更新（跨天）。
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    final list = await CountdownService.getTargets();
    if (mounted) setState(() => _targets = list);
    // 同步倒计时桌面组件数据（非 Android 平台静默降级）
    unawaited(WidgetService
        .saveCountdownData(await WidgetService.buildCountdownData()));
  }

  @override
  void dispose() {
    CountdownService.changed.removeListener(_load);
    _timer?.cancel();
    super.dispose();
  }

  List<CountdownItem> get _items =>
      CountdownService.buildItems(DateTime.now(), _targets);

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final nearest = items.where((e) => !e.isPast).toList();

    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _headerIcon(context),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('倒计时',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (nearest.isNotEmpty) ...[
            _buildHighlight(context, nearest.first),
            const SizedBox(height: 12),
            ...nearest.skip(1).map((e) => _buildRow(context, e)),
            if (items.any((e) => e.isPast)) ...[
              const SizedBox(height: 10),
              Divider(height: 1, thickness: 0.5, color: dividerColor(context)),
              const SizedBox(height: 6),
              ...items.where((e) => e.isPast).map((e) => _buildRow(context, e)),
            ],
          ] else ...[
            Row(
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 15, color: textHint(context)),
                const SizedBox(width: 8),
                Text('点击添加自己的倒计时目标',
                    style: TextStyle(fontSize: 13, color: textHint(context))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerIcon(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(Icons.flag_rounded,
          color: accentColorNotifier.value, size: 21),
    );
  }

  Widget _buildHighlight(BuildContext context, CountdownItem e) {
    final accent = e.target.colorValue == null
        ? accentColorNotifier.value
        : Color(e.target.colorValue!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kIosTileRadius),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          if (e.target.emoji != null)
            Text(e.target.emoji!, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('距『${e.target.name}』',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                LiveCountdown(
                  target: e.target.targetDate,
                  showSeconds: true,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, CountdownItem e) {
    final accent = e.target.colorValue == null
        ? accentColorNotifier.value
        : Color(e.target.colorValue!);
    final date = '${e.target.targetDate.year}-'
        '${e.target.targetDate.month.toString().padLeft(2, '0')}-'
        '${e.target.targetDate.day.toString().padLeft(2, '0')}';
    final baseWeight =
        e.target.pinned ? FontWeight.w600 : FontWeight.normal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (e.target.emoji != null)
            Text(e.target.emoji!, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  color: textPrimary(context),
                  fontWeight: baseWeight,
                ),
                children: [
                  TextSpan(text: '距『${e.target.name}』'),
                  if (e.isPast)
                    TextSpan(
                      text: e.daysLabel,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else ...[
                    TextSpan(text: '还有'),
                    TextSpan(
                      text: '${e.daysLeft}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: '天'),
                  ],
                ],
              ),
            ),
          ),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: textHint(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (e.target.pinned) ...[
            const SizedBox(width: 4),
            Icon(Icons.push_pin, size: 13, color: accent),
          ],
        ],
      ),
    );
  }
}
