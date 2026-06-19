import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/scaled_viewport.dart';
import '../models/user.dart';
import 'waiting_approval_screen.dart';
import 'home_screen.dart';
import 'hospital_dashboard_screen.dart';
import 'admin_home_screen.dart';
import 'assistant_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _keepSaved = false;
  bool _obscure = true;
  bool _isLoading = false;
  String? _loginError;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Wide/web layout switches to a split brand + form screen. Below this,
  // the original single-column mobile layout is used unchanged.
  static const double _wideBreakpoint = 900;
  // Reference width the form column is designed at; used to keep the
  // Responsive scaling sane once the form sits inside a fixed-width card
  // on wide screens instead of stretching across the whole browser.
  static const double _formReferenceWidth = 420;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }


void _login() async {
  setState(() => _loginError = null);

  if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
    setState(() => _loginError = 'Please enter email and password');
    return;
  }

  setState(() => _isLoading = true);

  try {
    final response = await ApiService.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberMe: _keepSaved,
    );

    await TokenService.saveTokens(
      response['access_token'],
      response['refresh_token'],
      _keepSaved,
    );

    final user = User.fromJson(response);
      print('🔍 User from response - subscriptionPlan: ${user.subscriptionPlan}');
  print('🔍 User from response - plan: ${user.plan}');
  print('🔍 User from response - isHospitalAdmin: ${user.isHospitalAdmin}');

    await TokenService.saveUser(user);
  // Test retrieve
  final savedUser = await TokenService.getUser();
  print('🔍 Retrieved user - subscriptionPlan: ${savedUser?.subscriptionPlan}');
  print('🔍 Retrieved user - isHospitalAdmin: ${savedUser?.isHospitalAdmin}');
    if (mounted) {
      // CHECK IF USER IS PENDING
      if (user.status == 'pending') {
        // Go to waiting approval screen with email
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingApprovalScreen(
              email: user.email,  // PASS THE EMAIL
            ),
          ),
        );
      } else {
        // Navigate directly based on role — avoids AuthWrapper FutureBuilder cache issue
        Widget destination;
        switch (user.role.toLowerCase()) {
          case 'admin':
            destination = const AdminHomeScreen();
            break;
          case 'hospital_admin':
            destination = const HospitalDashboardScreen();
            break;
          case 'assistant':
            destination = const AssistantHomeScreen();
            break;
          case 'doctor':
            final plan = (user.subscriptionPlan ?? user.plan ?? 'freemium').toLowerCase();
            if (plan == 'hospital' || plan == 'hospital_pro' || plan == 'hospital_plan') {
              destination = const HospitalDashboardScreen();
            } else {
              destination = const HomeScreen();
            }
            break;
          default:
            destination = const HomeScreen();
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
      }
    }
  } catch (e) {
    if (mounted) setState(() => _loginError = 'Invalid email or password');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _signUp() => Navigator.pushNamed(context, '/signup');

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: isWide ? Colors.white : AppColors.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: isWide
            ? _buildWideLayout(context)
            : _buildNarrowLayout(context, r, size),
      ),
    );
  }

  // ───────────────────────── Mobile / narrow layout ─────────────────────────
  Widget _buildNarrowLayout(BuildContext context, Responsive r, Size size) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.hp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: r.sp(52)),
                  _BrandMark(r: r),
                  SizedBox(height: r.sp(44)),
                  ..._formFields(r),
                  SizedBox(height: r.sp(32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── Wide / web layout ───────────────────────────
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 5, child: _LoginBrandPanel()),
        Expanded(
          flex: 6,
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        vertical: 56, horizontal: 40),
                    child: ScaledViewport(
                      width: _formReferenceWidth,
                      child: Builder(
                        builder: (innerContext) {
                          final innerR = Responsive.of(innerContext);
                          return ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: _formReferenceWidth),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _formFields(innerR),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Shared form content used by both layouts so behaviour/logic stays
  // identical — only the surrounding chrome differs.
  List<Widget> _formFields(Responsive r) {
    return [
      // Heading
      Text(
        'Welcome\nback.',
        style: TextStyle(
          color: AppColors.black,
          fontSize: r.fs(38),
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.5,
        ),
      ),

      SizedBox(height: r.sp(8)),

      Text(
        'Sign in to continue',
        style: TextStyle(
          color: AppColors.black.withOpacity(0.4),
          fontSize: r.fs(15),
          fontWeight: FontWeight.w400,
        ),
      ),

      SizedBox(height: r.sp(40)),

      // Email
      _Label('Email or username', r),
      SizedBox(height: r.sp(8)),
      _InputField(
        controller: _emailCtrl,
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        prefixIcon: Icons.mail_outline_rounded,
        r: r,
      ),

      SizedBox(height: r.sp(20)),

      // Password
      _Label('Password', r),
      SizedBox(height: r.sp(8)),
      _InputField(
        controller: _passwordCtrl,
        hint: '••••••••',
        obscure: _obscure,
        prefixIcon: Icons.lock_outline_rounded,
        r: r,
        suffix: GestureDetector(
          onTap: () => setState(() => _obscure = !_obscure),
          child: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: AppColors.black.withOpacity(0.35),
          ),
        ),
      ),

      if (_loginError != null)
        Padding(
          padding: EdgeInsets.only(top: r.sp(10), left: 4),
          child: Row(
            children: [
              Icon(Icons.error_outline,
                  size: 14, color: Colors.red.shade400),
              SizedBox(width: r.wp(5)),
              Expanded(
                child: Text(
                  _loginError!,
                  style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: r.fs(13)),
                ),
              ),
            ],
          ),
        ),

      SizedBox(height: r.sp(16)),

      // Remember me + Forgot
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => setState(() => _keepSaved = !_keepSaved),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: r.wp(20),
                  height: r.wp(20),
                  decoration: BoxDecoration(
                    color: _keepSaved
                        ? AppColors.sageGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _keepSaved
                          ? AppColors.sageGreen
                          : AppColors.black.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: _keepSaved
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 13)
                      : null,
                ),
                SizedBox(width: r.wp(8)),
                Text(
                  'Keep me signed in',
                  style: TextStyle(
                    color: AppColors.black.withOpacity(0.55),
                    fontSize: r.fs(13),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/forgot-password'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppColors.sageGreen,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),

      SizedBox(height: r.sp(32)),

      // Login button
      SizedBox(
        width: double.infinity,
        height: r.btnH,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: AppColors.sageGreen.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(r.cardRadius),
              ),
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.pressed) ? 0 : 2,
              ),
              shadowColor: WidgetStateProperty.all(
                  AppColors.sageGreen.withOpacity(0.35)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),

      SizedBox(height: r.sp(36)),

      // Divider
      Row(
        children: [
          Expanded(
              child: Divider(
                  color: AppColors.black.withOpacity(0.10),
                  thickness: 1)),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: r.wp(14)),
            child: Text(
              'or',
              style: TextStyle(
                  color: AppColors.black.withOpacity(0.30),
                  fontSize: r.fs(12)),
            ),
          ),
          Expanded(
              child: Divider(
                  color: AppColors.black.withOpacity(0.10),
                  thickness: 1)),
        ],
      ),

      SizedBox(height: r.sp(28)),

      // Sign up link
      Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _signUp,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: AppColors.black.withOpacity(0.45),
                  fontSize: r.fs(14),
                ),
                children: const [
                  TextSpan(text: "Don't have an account?  "),
                  TextSpan(
                    text: 'Sign up',
                    style: TextStyle(
                      color: AppColors.sageGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

// Small logo + wordmark lockup, used at the top of the mobile layout.
class _BrandMark extends StatelessWidget {
  final Responsive r;
  const _BrandMark({required this.r});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: r.wp(44),
          height: r.wp(44),
          decoration: BoxDecoration(
            color: AppColors.sageGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.sageGreen.withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            errorBuilder: (_, __, ___) => const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        SizedBox(width: r.wp(12)),
        Text(
          'HEART ALERT',
          style: TextStyle(
            color: AppColors.black,
            fontSize: r.fs(13),
            fontWeight: FontWeight.w800,
            letterSpacing: 2.8,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Wide-layout brand panel ─────────────────────────
// Decorative left panel shown on web/desktop widths. Purely visual — no
// state, no navigation, no logic.
class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  static const _features = [
    (Icons.monitor_heart_rounded, 'Real-time cardiac risk scoring'),
    (Icons.medical_information_rounded, 'Built around clinical workflow'),
    (Icons.shield_outlined, 'Secure, audit-ready patient records'),
  ];

  @override
  Widget build(BuildContext context) {
    final darkGreen = Color.lerp(AppColors.sageGreen, Colors.black, 0.35)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sageGreen, darkGreen],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _PulseLinePainter()),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.emergency,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'HEART ALERT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  const Text(
                    'Spot cardiac risk\nbefore it becomes\nan emergency.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Heart Alert helps clinicians flag at-risk patients early, '
                    'with explainable predictions built for the bedside.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ..._features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(f.$1, color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              f.$2,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A quiet heartbeat-line motif, drawn once as a background flourish.
class _PulseLinePainter extends CustomPainter {
  const _PulseLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final baseline = size.height * 0.62;
    final path = Path()..moveTo(0, baseline);
    final segment = size.width / 5;

    path.lineTo(segment * 0.9, baseline);
    path.lineTo(segment * 1.05, baseline - 18);
    path.lineTo(segment * 1.2, baseline + 46);
    path.lineTo(segment * 1.4, baseline - 8);
    path.lineTo(segment * 1.7, baseline);
    path.lineTo(segment * 2.9, baseline);
    path.lineTo(segment * 3.05, baseline - 18);
    path.lineTo(segment * 3.2, baseline + 46);
    path.lineTo(segment * 3.4, baseline - 8);
    path.lineTo(segment * 3.7, baseline);
    path.lineTo(size.width, baseline);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Field label
class _Label extends StatelessWidget {
  final String text;
  final Responsive r;
  const _Label(this.text, this.r);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: AppColors.black.withOpacity(0.6),
          fontSize: r.fs(12),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}

// Input field
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Responsive r;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.r,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.black, fontSize: r.fs(15)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.black.withOpacity(0.3), fontSize: r.fs(14)),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                size: 18, color: AppColors.black.withOpacity(0.3))
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.black.withOpacity(0.04),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 18, vertical: r.inputVPad),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide:
              BorderSide(color: AppColors.black.withOpacity(0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide:
              const BorderSide(color: AppColors.sageGreen, width: 1.5),
        ),
      ),
    );
  }
}