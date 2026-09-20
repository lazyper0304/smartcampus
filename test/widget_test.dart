import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/auth/login_page.dart';
import 'package:smartcampus/core/http_client.dart';
import 'package:smartcampus/main.dart';
import 'package:smartcampus/splash/startup_flow.dart';
import 'package:smartcampus/welcome/welcome_gate.dart';
import 'package:smartcampus/welcome/welcome_page.dart';

/// 结算欢迎页入场动画（_exitAnim 420ms）+ 交接后的若干帧
Future<void> _settleEntry(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('启动进入欢迎首屏（轮播 + 图文 + 向上拉取入场）',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCampusApp());

    // 2026-09-20：入口为 WelcomeGate，**每次启动都先展示欢迎首屏**
    expect(find.byType(WelcomeGate), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WelcomePage), findsOneWidget);

    // 第 1 页文案 + 主按钮 + 分页容器
    expect(find.text('百川归海\n一处相逢'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    // 左右手动滑动不异常（自动滚动为 4s 周期，此处仅验证手势路径）
    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pump(const Duration(milliseconds: 900));

    // 向上拉取入场：欢迎页整屏上滑出屏后**就地交接**（无页面跳转），
    // 且不出现旧的「验证 Cookie 中…」过渡页。
    await tester.drag(find.byType(WelcomePage), const Offset(0, -400));
    await _settleEntry(tester);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.text('验证 Cookie 中…'), findsNothing);
  });

  testWidgets('点击开始使用就地进入目标页（无独立过渡/登录中间屏）',
      (WidgetTester tester) async {
    // 注入立即返回的假分流：测试环境本地文件 IO 在 fake-async 下不会完成，
    // 无法等出真实分流结果（真实分流见 lib/splash/startup_flow.dart）。
    await tester.pumpWidget(MaterialApp(
      home: WelcomeGate(
        resolver: () async => StartupTarget(
          page: const LoginPage(),
          client: SharedHttpClient(),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WelcomePage), findsOneWidget);

    await tester.tap(find.text('开始使用'));
    await _settleEntry(tester);

    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('验证 Cookie 中…'), findsNothing);
  });
}
