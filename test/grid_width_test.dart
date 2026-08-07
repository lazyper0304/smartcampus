import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/core/input_adaptation.dart';

void main() {
  testWidgets('icon tile centered in grid card (Clickable alignment fix)',
      (tester) async {
    final logs = <String>[];
    final tileKey = GlobalKey();
    final iconKey = GlobalKey();

    Widget tile = Clickable(
      onTap: () {},
      borderRadius: 14,
      builder: (context, hovered, focused) {
        return LayoutBuilder(
          builder: (context, c) {
            final tileSize = c.maxWidth * 0.55;
            return Column(
              key: tileKey,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  key: iconKey,
                  width: tileSize,
                  height: tileSize,
                  color: const Color(0x2200FF00),
                  child: Icon(Icons.star,
                      size: (tileSize * 0.52).clamp(20.0, 32.0)),
                ),
                const SizedBox(height: 5),
                const Text('课程表'),
              ],
            );
          },
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 844,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemCount: 1,
              itemBuilder: (context, i) => tile,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final colRect = (tileKey.currentContext!.findRenderObject()! as RenderBox)
        .localToGlobal(Offset.zero) &
        (tileKey.currentContext!.findRenderObject()! as RenderBox).size;
    final iconBox =
        iconKey.currentContext!.findRenderObject()! as RenderBox;
    final iconCenter = iconBox.localToGlobal(Offset.zero) +
        iconBox.size.center(Offset.zero);
    final colCenter = colRect.center.dx;
    final off = (iconCenter.dx - colCenter).abs();
    logs.add('grid: colWidth=${colRect.width.toStringAsFixed(1)} '
        'iconCenter=${iconCenter.dx.toStringAsFixed(1)} '
        'colCenter=${colCenter.toStringAsFixed(1)} off=$off');
    expect(off, lessThan(0.5), reason: 'icon should be centered in card');
    for (final l in logs) {
      // ignore: avoid_print
      print('[GRIDFIX] $l');
    }
  });

  testWidgets('Clickable in unbounded-height Column(stretch) does not vanish',
      (tester) async {
    final cardKey = GlobalKey();
    // 模拟首页"今日课程"卡片容器：ListView 内 Column(stretch)，
    // 卡片收到 width tight、height loose(0..∞)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Clickable(
                    onTap: () {},
                    child: Container(
                      key: cardKey,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0x220000FF),
                      child: const Text('今日课程', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final box =
        cardKey.currentContext!.findRenderObject()! as RenderBox;
    final h = box.size.height;
    // ignore: avoid_print
    print('[CARD] height=$h');
    expect(h, greaterThan(0), reason: 'card must not vanish (height > 0)');
    expect(h.isFinite, true, reason: 'height must be finite (not infinity)');
    // 卡片内容（文字）应可见：高度至少容纳 padding 16*2 + 一行文字
    expect(h, greaterThanOrEqualTo(40));
  });
}
