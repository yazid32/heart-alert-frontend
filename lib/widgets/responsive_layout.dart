// lib/widgets/responsive_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  
  const ResponsiveLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // For web, center the content with a reasonable max width
    if (kIsWeb) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      );
    }
    
    return child;
  }
}