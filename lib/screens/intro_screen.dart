import 'package:flutter/material.dart';

const Color kCream     = Color(0xFFF5F0E8);
const Color kSageGreen = Color(0xFF7A9E7E);

// ─────────────────────────────────────────────
// INTRO SCREEN
//
// Stage 1 (0–800ms)  : cream bg, green circle grows from center
// Stage 2 (800–1500ms): circle expands to fill screen
// Stage 3 (1500ms)   : bg photo crossfades in over green
// Stage 4 (2000ms)   : logo (left) + "HEART ALERT" (right) slide + fade in
// ─────────────────────────────────────────────
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {

  // Stage 1 – circle scale 0 → 1
  late final AnimationController _circleCtrl;
  late final Animation<double>   _circleScale;

  // Stage 2 – circle expands to fill screen
  late final AnimationController _fillCtrl;
  late final Animation<double>   _fillScale;

  // Stage 3 – background photo fades in
  late final AnimationController _bgCtrl;
  late final Animation<double>   _bgOpacity;

  // Stage 4 – logo + text
  late final AnimationController _contentCtrl;
  late final Animation<double>   _contentOpacity;
  late final Animation<Offset>   _contentSlide;

  @override
  void initState() {
    super.initState();

    _circleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _circleCtrl, curve: Curves.easeOut));

    _fillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fillScale = Tween<double>(begin: 1.0, end: 45.0).animate(
        CurvedAnimation(parent: _fillCtrl, curve: Curves.easeInOut));

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn));

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeIn));
    _contentSlide = Tween<Offset>(
      begin: const Offset(-0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 350));
    // 1. Circle grows
    await _circleCtrl.forward();
    // 2. Circle fills screen
    await _fillCtrl.forward();
    // 3. Background photo swaps in (overlaps end of fill)
    await _bgCtrl.forward();
    // 4. Logo + text appear
    await _contentCtrl.forward();

    // Navigate to onboarding after intro completes
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _circleCtrl.dispose();
    _fillCtrl.dispose();
    _bgCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final baseDiameter = size.width * 0.28;

    return Scaffold(
      backgroundColor: kCream,
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_circleCtrl, _fillCtrl, _bgCtrl, _contentCtrl]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [

              // ── Layer 0: cream background ─────
              Container(color: kCream),

              // ── Layer 1: expanding green circle ─
              Center(
                child: Transform.scale(
                  scale: _circleScale.value * _fillScale.value,
                  child: Container(
                    width: baseDiameter,
                    height: baseDiameter,
                    decoration: const BoxDecoration(
                      color: kSageGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              // ── Layer 2: background photo crossfade ─
              // Replace 'assets/images/bg.jpg' with your actual background image.
              // The image should be added to assets/images/ and declared in pubspec.yaml.
              Opacity(
                opacity: _bgOpacity.value,
                child: Image.asset(
                  'assets/images/bg.png',
                  fit: BoxFit.cover,
                  width: size.width,
                  height: size.height,
                  // Shows a green fallback if image not yet added:
                  errorBuilder: (_, __, ___) =>
                      Container(color: kSageGreen.withOpacity(0.85)),
                ),
              ),

              // ── Layer 3: dark scrim so text is readable ─
              Opacity(
                opacity: _bgOpacity.value * 0.35,
                child: Container(color: Colors.black),
              ),

              // ── Layer 4: logo (left) + title (right) ─
              Align(
                alignment: const Alignment(0, 0.05),
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [

                          // ── Logo ──────────────
                          // Once you have logo.png, replace the Icon below with:
                          // Image.asset('assets/images/logo.png', width: 56, height: 56)
                          Image.asset(
                            'assets/images/logo.png',
                            width: 142,
                            height: 142,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.emergency,
                              color: kSageGreen,
                              size: 138,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // ── App name ──────────
                          const Text(
                            'HEART ALERT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
