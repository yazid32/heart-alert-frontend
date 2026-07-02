import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      imagePath: 'assets/images/onboarding_1.png',
      title: 'Enter Patient\nClinical Data',
      description:
          'Input key medical parameters such as age, blood pressure, cholesterol, and ECG results.',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_2.png',
      title: 'AI Clinical\nDecision Support',
      description:
          'Our machine learning model analyzes patient data to support heart disease risk assessment.',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_3.png',
      title: 'Instant Risk\nEstimation',
      description:
          'Receive an immediate risk percentage to assist medical decision-making.',
    ),
  ];

  void _goToPage(int page) => _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

  void _skip() => _goToPage(_pages.length - 1);
  void _prev() { if (_currentPage > 0) _goToPage(_currentPage - 1); }
  void _next() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _getStarted();
    }
  }

  Future<void> _getStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r      = Responsive.of(context);
    final isFirst = _currentPage == 0;
    final isLast  = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed illustrations
          PageView.builder(
            controller:    _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount:     _pages.length,
            itemBuilder:   (context, i) => Image.asset(
              _pages[i].imagePath,
              fit:          BoxFit.cover,
              width:        double.infinity,
              height:       double.infinity,
              errorBuilder: (_, __, ___) => _Placeholder(index: i),
            ),
          ),

          // Soft gradient so the illustration eases into the cream panel
          // instead of cutting off abruptly.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.cream.withOpacity(0.0),
                      AppColors.cream.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // UI overlay
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.hp, vertical: r.sp(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.wp(12), vertical: r.sp(6)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${_currentPage + 1}',
                                style: TextStyle(
                                  color:      AppColors.black,
                                  fontSize:   r.fs(14),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '/${_pages.length}',
                                style: TextStyle(
                                  color:      AppColors.black.withOpacity(0.4),
                                  fontSize:   r.fs(14),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        GestureDetector(
                          onTap: _skip,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.wp(14), vertical: r.sp(6)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color:      AppColors.black,
                                fontSize:   r.fs(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom panel
                Container(
                  decoration: BoxDecoration(
                    color:        AppColors.cream,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(r.sp(26))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                      r.hp, r.sp(22), r.hp, r.sp(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _pages[_currentPage].title,
                          key: ValueKey(_currentPage),
                          style: TextStyle(
                            color:      AppColors.black,
                            fontSize:   r.fs(26),
                            fontWeight: FontWeight.w800,
                            height:     1.2,
                          ),
                        ),
                      ),

                      SizedBox(height: r.sp(10)),

                      // Description
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _pages[_currentPage].description,
                          key: ValueKey('d$_currentPage'),
                          style: TextStyle(
                            color:    AppColors.black.withOpacity(0.55),
                            fontSize: r.fs(14),
                            height:   1.6,
                          ),
                        ),
                      ),

                      SizedBox(height: r.sp(24)),

                      // Nav row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _NavButton(
                            label:   'Prev',
                            visible: !isFirst,
                            filled:  false,
                            onTap:   _prev,
                            r: r,
                          ),

                          // Dot indicators
                          Row(
                            children: List.generate(_pages.length, (i) {
                              final active = i == _currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin:  const EdgeInsets.symmetric(horizontal: 3),
                                width:   active ? r.wp(22) : r.wp(7),
                                height:  r.wp(7),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.sageGreen
                                      : AppColors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),

                          _NavButton(
                            label:   isLast ? 'Get Started' : 'Next',
                            visible: true,
                            filled:  isLast,
                            onTap:   _next,
                            r: r,
                          ),
                        ],
                      ),

                      SizedBox(height: r.sp(10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder ──────────────────────────────
class _Placeholder extends StatelessWidget {
  final int index;
  const _Placeholder({required this.index});

  static const _icons = [
    Icons.medical_information_outlined,
    Icons.psychology_outlined,
    Icons.monitor_heart_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sageGreen.withOpacity(0.15),
      child: Center(
        child: Icon(_icons[index % 3],
            size: 80, color: AppColors.sageGreen.withOpacity(0.6)),
      ),
    );
  }
}

// ── Nav button ───────────────────────────────
class _NavButton extends StatelessWidget {
  final String     label;
  final bool       visible;
  final bool       filled;
  final VoidCallback onTap;
  final Responsive r;

  const _NavButton({
    required this.label,
    required this.visible,
    required this.filled,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return SizedBox(width: r.wp(88));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
            horizontal: r.wp(20), vertical: r.sp(10)),
        decoration: BoxDecoration(
          color:        filled ? AppColors.sageGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(r.sp(24)),
          border: filled
              ? null
              : Border.all(
                  color: AppColors.black.withOpacity(0.2), width: 1),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: AppColors.sageGreen.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      filled ? Colors.white : AppColors.black,
            fontSize:   r.fs(14),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────
class _OnboardingData {
  final String imagePath;
  final String title;
  final String description;
  const _OnboardingData({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}