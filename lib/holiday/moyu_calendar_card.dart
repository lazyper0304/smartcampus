/// 首页"摸鱼日历"卡片。
///
/// 展示内置节日倒计时（按剩余天数升序），高亮最近目标并实时秒级刷新；
/// 自定义倒计时已独立为「倒计时」卡片（lib/countdown/）。管理入口在「设置」。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/live_countdown.dart';
import '../core/theme_utils.dart';
import '../main.dart' show accentColorNotifier;
import '../widget/widget_service.dart';
import 'countdown_service.dart';

class MoyuCalendarCard extends StatefulWidget {
  const MoyuCalendarCard({super.key});

  @override
  State<MoyuCalendarCard> createState() => _MoyuCalendarCardState();
}

class _MoyuCalendarCardState extends State<MoyuCalendarCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 同步摸鱼桌面组件数据（非 Android 平台静默降级）
    _syncWidget();
    // 每分钟刷新一次，保证"天数"随时间自动更新（跨天/跨月）。
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _syncWidget() async {
    // 同步摸鱼桌面组件数据（非 Android 平台静默降级）
    unawaited(WidgetService.saveMoyuData(WidgetService.buildMoyuData()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<CountdownEntry> get _festivalEntries =>
      HolidayService.buildFestivalEntries(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final festival = _festivalEntries;
    final nearest = festival.isEmpty ? null : festival.first;

    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _headerIcon(context),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('摸鱼日历',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (nearest != null) _buildHighlight(context, nearest),
          if (nearest != null) const SizedBox(height: 12),
          ...festival.map((e) => _buildRow(context, e)),
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
      child: Icon(Icons.celebration_rounded,
          color: accentColorNotifier.value, size: 21),
    );
  }

  Widget _buildHighlight(BuildContext context, CountdownEntry e) {
    final accent = accentColorNotifier.value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kIosTileRadius),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('距『${e.name}』',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                LiveCountdown(
                  target: e.target,
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

  Widget _buildRow(BuildContext context, CountdownEntry e) {
    final accent = accentColorNotifier.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13.5, color: textPrimary(context)),
                children: [
                  TextSpan(text: '距『${e.name}』'),
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
            '${e.target.year}-${e.target.month.toString().padLeft(2, '0')}-${e.target.day.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 12, color: textHint(context), fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
