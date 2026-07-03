import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/main.dart';

void main() {
  testWidgets('Login page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCampusApp());

    expect(find.text('宜宾学院'), findsOneWidget);
    expect(find.text('智慧校园登录'), findsOneWidget);
    expect(find.text('学号/工号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登 录'), findsOneWidget);
  });
}
