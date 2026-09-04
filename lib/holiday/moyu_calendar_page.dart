/// 摸鱼日历二级页：内置节日倒计时总览。
///
/// 自定义倒计时已独立为「倒计时」功能（lib/countdown/countdown_page.dart）。
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassStatusBarStyle;

import '../core/ios_kit.dart';
import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../main.dart' show accentColorNotifier;
import 'countdown_service.dart';

class MoyuCalendarPage extends StatefulWidget {
  const MoyuCalendarPage({super.key});

  @override
  State<MoyuCalendarPage> createState() => _MoyuCalendarPageState();
}

class _MoyuCalendarPageState extends State<MoyuCalendarPage> {
  List<CountdownEntry> get _festivalEntries =>
      HolidayService.buildFestivalEntries(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final festival = _festivalEntries;
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('摸鱼日历'), centerTitle: true),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              kIosPageHPadding,
              8,
              kIosPageHPadding,
              bottomBarSafePadding(context),
            ),
            children: [
              IosSectionHeader('节日倒计时'),
              IosListGroup(
                children: [
                  for (var i = 0; i < festival.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          thickness: 0.5,
                          color: dividerColor(context)),
                    _festivalRow(context, festival[i]),
                  ],
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _festivalRow(BuildContext context, CountdownEntry e) {
    final accent = accentColorNotifier.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: textPrimary(context)),
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
          Text('${e.target.year}-${e.target.month.toString().padLeft(2, '0')}-${e.target.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 13, color: textHint(context), fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}
