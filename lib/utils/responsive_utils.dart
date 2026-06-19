/// responsive_utils.dart
/// Drop this file into lib/utils/ and import wherever needed.
///
/// Usage:
///   final r = Responsive.of(context);
///   SizedBox(height: r.sp(24))   // scales with screen height
///   Text('Hello', style: TextStyle(fontSize: r.fs(16)))
///   Padding(padding: EdgeInsets.symmetric(horizontal: r.hp))
///
library responsive_utils;

import 'package:flutter/material.dart';

class Responsive {
  final double screenW;
  final double screenH;
  final double pixelRatio;

  const Responsive._({
    required this.screenW,
    required this.screenH,
    required this.pixelRatio,
  });

  factory Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Responsive._(
      screenW: mq.size.width,
      screenH: mq.size.height,
      pixelRatio: mq.devicePixelRatio,
    );
  }

  // ── Breakpoints ─────────────────────────────
  bool get isSmall  => screenW < 360;   // e.g. small Android
  bool get isMedium => screenW >= 360 && screenW < 414;
  bool get isLarge  => screenW >= 414;  // e.g. Pro Max / tablets

  // ── Spacing helpers ──────────────────────────
  /// Scales a spacing value relative to screen height (baseline 812 = iPhone X)
  double sp(double value) => (value * screenH / 812).clamp(value * 0.75, value * 1.35);

  /// Scales a value relative to screen width (baseline 390 = iPhone 14)
  double wp(double value) => (value * screenW / 390).clamp(value * 0.80, value * 1.25);

  /// Font size — scales with width, tighter clamp for readability
  double fs(double size) => (size * screenW / 390).clamp(size * 0.85, size * 1.20);

  /// Horizontal page padding — adapts to screen width
  double get hp => isSmall ? 20.0 : isMedium ? 24.0 : 28.0;

  /// Vertical gap between major sections
  double get sectionGap => sp(24);

  /// Standard card border radius
  double get cardRadius => isSmall ? 16.0 : 20.0;

  /// Button height
  double get btnH => sp(52);

  /// Input field vertical padding
  double get inputVPad => sp(16);

  // ── Convenience EdgeInsets ───────────────────
  EdgeInsets get pagePadding =>
      EdgeInsets.symmetric(horizontal: hp, vertical: sp(18));

  EdgeInsets get hPad => EdgeInsets.symmetric(horizontal: hp);
}
