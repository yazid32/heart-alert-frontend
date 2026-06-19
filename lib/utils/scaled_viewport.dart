// lib/utils/scaled_viewport.dart
//
// Small presentation-only helper — no business logic.
//
// Several screens use a width-based `Responsive` helper (r.wp/r.fs/r.sp/...)
// that scales spacing and font sizes off MediaQuery's screen width. That
// works well for a phone, but once the same widget tree is dropped into a
// fixed-width card or column on a wide/web layout, scaling against the full
// browser width makes everything render too large for the space it's
// actually given.
//
// Wrapping that subtree in `ScaledViewport(width: cardWidth, child: ...)`
// overrides the MediaQuery size seen by its descendants so `Responsive.of
// (context)` (and anything else reading MediaQuery) scales against the
// actual column width instead of the full viewport. Purely visual — it does
// not touch any state, navigation, or API logic.
import 'package:flutter/material.dart';

class ScaledViewport extends StatelessWidget {
  final double width;
  final Widget child;

  const ScaledViewport({super.key, required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(size: Size(width, mq.size.height)),
      child: child,
    );
  }
}
