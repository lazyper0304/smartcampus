import 'package:flutter/material.dart';
import 'package:cue/cue.dart';

/// Standard transition duration.
const Duration _duration = Duration(milliseconds: 350);

/// Shared axis slide + fade acts for forward page push.
const List<Act> _pushActs = [Act.fadeIn(), Act.slideX(from: 0.25)];

/// Build a cue-driven PageRoute.
PageRouteBuilder _cueRoute(Widget page, {List<Act> acts = _pushActs}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return Cue.onProgress(
        listenable: animation,
        progress: () => animation.value,
        acts: acts,
        child: page,
      );
    },
    transitionDuration: _duration,
    reverseTransitionDuration: const Duration(milliseconds: 300),
  );
}

/// Push a new page with a slide + fade transition.
void pushPage(BuildContext context, Widget page) {
  Navigator.push(context, _cueRoute(page));
}

/// Replace the current page (splash → main/login).
void replacePage(BuildContext context, Widget page, {List<Act>? acts}) {
  Navigator.pushReplacement(
    context,
    _cueRoute(page, acts: acts ?? _pushActs),
  );
}

/// Push and remove all previous routes (logout).
void pushAndClear(BuildContext context, Widget page) {
  Navigator.pushAndRemoveUntil(
    context,
    _cueRoute(page, acts: const [Act.fadeIn()]),
    (route) => false,
  );
}
