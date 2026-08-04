import 'package:flutter/cupertino.dart';

/// iOS 风格页面切换动画（CupertinoPageRoute）：
/// - 右滑推入 + 下层视差 + 上层轻微缩放（iOS 系统标准转场，400ms）
/// - 支持 iOS 边缘左滑返回手势（interactive pop）
CupertinoPageRoute _buildRoute(Widget page) {
  return CupertinoPageRoute(
    builder: (_) => page,
  );
}

/// Push a new page.
void pushPage(BuildContext context, Widget page) {
  Navigator.push(context, _buildRoute(page));
}

/// Replace the current page (splash → main/login).
void replacePage(BuildContext context, Widget page) {
  Navigator.pushReplacement(context, _buildRoute(page));
}

/// Push and remove all previous routes (logout).
void pushAndClear(BuildContext context, Widget page) {
  Navigator.pushAndRemoveUntil(
    context,
    _buildRoute(page),
    (route) => false,
  );
}
