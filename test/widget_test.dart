import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/main.dart';

void main() {
  testWidgets('App boot smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCampusApp());

    // SplashPage 启动过渡：品牌名 + 会话校验提示（登录页文案已更新为
    // '宜院宾果'，旧断言 '宜宾学院'/'智慧校园登录' 已过时）。
    expect(find.text('宜院宾果'), findsOneWidget);
    expect(find.text('验证 Cookie 中…'), findsOneWidget);

    // 推进时间结算 SplashPage 的 800ms 延迟 + 页面过渡动画：测试环境
    // 无本地凭据 → autoRelogin 立即返回 false → 进入登录页，
    // 避免测试结束时残留 pending Timer（flutter_test 强制校验）。
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
