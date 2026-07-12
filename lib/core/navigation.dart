import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

const Duration _duration = Duration(milliseconds: 350);

PageTransitionType _transitionType = PageTransitionType.fade;

PageTransition _buildRoute(Widget page) {
  final type = _transitionType;
  return PageTransition(
    type: type,
    child: page,
    duration: _duration,
    reverseDuration: const Duration(milliseconds: 300),
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
