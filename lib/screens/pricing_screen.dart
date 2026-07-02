// lib/screens/pricing_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> with TickerProviderStateMixin {
  List<dynamic> _plans = [];
  bool _isLoading = true;
  bool _isSubscribing = false;
  bool _showInDZD = true;
  String? _currentPlan;
  Map<String, dynamic>? _subscriptionInfo;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadPlans();
    _getCurrentPlan();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await ApiService.getPricingPlans();
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading plans: $e');
    }
  }

  Future<void> _getCurrentPlan() async {
    final token = await TokenService.getToken();
    if (token != null) {
      try {
        final sub = await ApiService.getMySubscription(token);
        setState(() {
          _subscriptionInfo = sub;
          _currentPlan = sub['plan'] ?? 'freemium';
        });
      } catch (e) {
        setState(() {
          _subscriptionInfo = null;
          _currentPlan = 'freemium';
        });
      }
    } else {
      setState(() {
        _subscriptionInfo = null;
        _currentPlan = 'freemium';
      });
    }
  }

  String _formatPrice(int priceCents, String intervalType) {
    if (_showInDZD) {
      final dzd = (priceCents / 100) * 135;
      return '${dzd.toStringAsFixed(0)} DA';
    } else {
      final usd = priceCents / 100;
      return '\$${usd.toStringAsFixed(2)}';
    }
  }

  String _getIntervalText(String intervalType) {
    if (intervalType == 'month') return '/mo';
    if (intervalType == 'year') return '/yr';
    return '';
  }

  Future<void> _subscribe(String planName) async {
    if (_isSubscribing) return; // prevent double/triple taps firing multiple checkout sessions
    final token = await TokenService.getToken();
    if (token == null) {
      if (mounted) Navigator.pushNamed(context, '/login');
      return;
    }
    setState(() => _isSubscribing = true);
    try {
      String successUrl;
      String cancelUrl;
      if (kIsWeb) {
        successUrl = 'https://heartalert.netlify.app/';
        cancelUrl = 'https://heartalert.netlify.app/';
      } else {
        // Deep link back into the app instead of opening the website.
        // AndroidManifest.xml already has a catch-all intent-filter for the
        // heartalert:// scheme, so no manifest changes are needed.
        successUrl = 'heartalert://payment-success?plan=$planName';
        cancelUrl = 'heartalert://payment-cancel';
      }
      final session = await ApiService.createCheckoutSession(
        token: token,
        planName: planName,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
      final Uri url = Uri.parse(session['session_url']);
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Could not open the checkout page. Please try again.')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  // ✅ CANCEL SUBSCRIPTION METHOD
  Future<void> _cancelSubscription() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppThemeTokens.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel Subscription?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppThemeTokens.of(context).textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel your subscription?',
                style: TextStyle(
                  color: AppThemeTokens.of(context).textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ This will:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Lose access to Pro features immediately',
                      style: TextStyle(fontSize: 11, color: AppThemeTokens.of(context).textMuted),
                    ),
                    Text(
                      '• Revert to Freemium plan',
                      style: TextStyle(fontSize: 11, color: AppThemeTokens.of(context).textMuted),
                    ),
                    Text(
                      '• No refund for remaining time',
                      style: TextStyle(fontSize: 11, color: AppThemeTokens.of(context).textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Plan',
              style: TextStyle(color: AppThemeTokens.of(context).textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.cancelSubscription(token);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription cancelled successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh plans
          _loadPlans();
          _getCurrentPlan();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Plans & Pricing',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: r.fs(18),
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: t.bg,
        foregroundColor: t.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.border.withOpacity(0.5)),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.wp(12)),
            child: _CurrencyToggle(
              showInDZD: _showInDZD,
              onChanged: (val) => setState(() => _showInDZD = val),
              r: r,
              t: t,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _LoadingState(t: t)
          : FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        r.wp(16), r.sp(24), r.wp(16), r.sp(48)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: isWide ? 1080 : 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PricingHeader(r: r, t: t, centered: isWide),
                            if (_subscriptionInfo != null &&
                                ((_currentPlan != null && _currentPlan != 'freemium') ||
                                    _subscriptionInfo!['status'] == 'past_due' ||
                                    _subscriptionInfo!['is_hospital_linked'] == true)) ...[
                              SizedBox(height: r.sp(20)),
                              _SubscriptionSummaryBanner(info: _subscriptionInfo!, r: r, t: t),
                            ],
                            SizedBox(height: r.sp(32)),
                            if (isWide)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: r.wp(20),
                                runSpacing: 0,
                                children: _plans.asMap().entries.map((entry) {
                                  return SizedBox(
                                    width: 320,
                                    child: _PricingCard(
                                      plan: entry.value,
                                      index: entry.key,
                                      currentPlan: _currentPlan,
                                      showInDZD: _showInDZD,
                                      formatPrice: _formatPrice,
                                      getIntervalText: _getIntervalText,
                                      onSubscribe: _subscribe,
                                      onCancel: _cancelSubscription, // ✅ PASSED
                                      isSubscribing: _isSubscribing,
                                      r: r,
                                      t: t,
                                    ),
                                  );
                                }).toList(),
                              )
                            else
                              ..._plans.asMap().entries.map((entry) {
                                return _PricingCard(
                                  plan: entry.value,
                                  index: entry.key,
                                  currentPlan: _currentPlan,
                                  showInDZD: _showInDZD,
                                  formatPrice: _formatPrice,
                                  getIntervalText: _getIntervalText,
                                  onSubscribe: _subscribe,
                                  onCancel: _cancelSubscription, // ✅ PASSED
                                  isSubscribing: _isSubscribing,
                                  r: r,
                                  t: t,
                                );
                              }),
                            SizedBox(height: r.sp(16)),
                            _TrustFooter(r: r, t: t),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Currency Toggle ──────────────────────────────────────────────────────────
class _CurrencyToggle extends StatelessWidget {
  final bool showInDZD;
  final ValueChanged<bool> onChanged;
  final Responsive r;
  final AppThemeTokens t;

  const _CurrencyToggle({
    required this.showInDZD,
    required this.onChanged,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: r.sp(36),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(r.sp(10)),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(label: 'DA', selected: showInDZD, onTap: () => onChanged(true), r: r, t: t),
          _ToggleOption(label: '\$', selected: !showInDZD, onTap: () => onChanged(false), r: r, t: t),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: r.wp(14), vertical: r.sp(6)),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(r.sp(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: r.fs(13),
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : t.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Pricing Header ───────────────────────────────────────────────────────────
class _PricingHeader extends StatelessWidget {
  final Responsive r;
  final AppThemeTokens t;
  final bool centered;

  const _PricingHeader({required this.r, required this.t, this.centered = false});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.wp(10), vertical: r.sp(4)),
          decoration: BoxDecoration(
            color: AppColors.sageGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.sp(6)),
          ),
          child: Text(
            'SIMPLE PRICING',
            style: TextStyle(
              fontSize: r.fs(10),
              fontWeight: FontWeight.w800,
              color: AppColors.sageGreen,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(height: r.sp(12)),
        Text(
          centered
              ? 'Pick the plan that fits your practice.'
              : 'Pick the plan\nthat fits your practice.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: r.fs(centered ? 32 : 26),
            fontWeight: FontWeight.w800,
            color: t.textPrimary,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: r.sp(8)),
        Text(
          'Upgrade or cancel any time. No hidden fees.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: r.fs(13),
            color: t.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );

    if (!centered) return content;
    return SizedBox(width: double.infinity, child: content);
  }
}

// ── Subscription Summary Banner ──────────────────────────────────────────────
class _SubscriptionSummaryBanner extends StatelessWidget {
  final Map<String, dynamic> info;
  final Responsive r;
  final AppThemeTokens t;

  const _SubscriptionSummaryBanner({required this.info, required this.r, required this.t});

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? plan = info['plan'];
    final String? status = info['status'];
    final bool isHospitalLinked = info['is_hospital_linked'] == true;
    final String? hospitalAdmin = info['hospital_admin'];
    final DateTime? expiresAt = _parseDate(info['expires_at']);
    final int used = (info['monthly_predictions_used'] ?? 0) as int;
    final int limit = (info['prediction_limit'] ?? 0) as int;
    final bool isPastDue = status == 'past_due';
    final bool unlimited = limit <= 0;

    final Color accent = isPastDue
        ? Colors.orange.shade700
        : (isHospitalLinked ? Colors.blueGrey : AppColors.sageGreen);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.sp(16)),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(r.sp(14)),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPastDue ? Icons.warning_amber_rounded : Icons.verified_rounded,
                color: accent,
                size: r.sp(18),
              ),
              SizedBox(width: r.wp(8)),
              Expanded(
                child: Text(
                  isHospitalLinked
                      ? 'Hospital-provided access'
                      : '${(plan ?? 'freemium').toUpperCase()} plan',
                  style: TextStyle(
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
              ),
              if (status != null && !isHospitalLinked)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: r.wp(8), vertical: r.sp(3)),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(r.sp(20)),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.sp(8)),
          if (isHospitalLinked)
            Text(
              hospitalAdmin != null
                  ? 'Your Pro access is managed by $hospitalAdmin. Contact them to make changes.'
                  : 'Your Pro access is provided by your hospital administrator.',
              style: TextStyle(fontSize: r.fs(12.5), color: t.textMuted, height: 1.4),
            )
          else if (isPastDue)
            Text(
              'We couldn\'t process your last payment. Please update your payment method to keep your Pro access.',
              style: TextStyle(fontSize: r.fs(12.5), color: accent, height: 1.4, fontWeight: FontWeight.w600),
            )
          else if (expiresAt != null && plan != null && plan != 'freemium')
            Text(
              status == 'active'
                  ? 'Renews on ${DateFormat('MMM d, yyyy').format(expiresAt)}'
                  : 'Access ends on ${DateFormat('MMM d, yyyy').format(expiresAt)}',
              style: TextStyle(fontSize: r.fs(12.5), color: t.textMuted, height: 1.4),
            ),
          if (limit > 0 || unlimited) ...[
            SizedBox(height: r.sp(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Predictions this month',
                  style: TextStyle(fontSize: r.fs(11.5), color: t.textMuted, fontWeight: FontWeight.w600),
                ),
                Text(
                  unlimited ? '$used / Unlimited' : '$used / $limit',
                  style: TextStyle(fontSize: r.fs(11.5), color: t.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (!unlimited) ...[
              SizedBox(height: r.sp(6)),
              ClipRRect(
                borderRadius: BorderRadius.circular(r.sp(4)),
                child: LinearProgressIndicator(
                  value: (used / limit).clamp(0.0, 1.0),
                  minHeight: r.sp(6),
                  backgroundColor: accent.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    used >= limit ? Colors.red.shade400 : accent,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Pricing Card ─────────────────────────────────────────────────────────────
class _PricingCard extends StatelessWidget {
  final dynamic plan;
  final int index;
  final String? currentPlan;
  final bool showInDZD;
  final String Function(int, String) formatPrice;
  final String Function(String) getIntervalText;
  final Future<void> Function(String) onSubscribe;
  final Future<void> Function() onCancel; // ✅ ADDED
  final bool isSubscribing;
  final Responsive r;
  final AppThemeTokens t;

  const _PricingCard({
    required this.plan,
    required this.index,
    required this.currentPlan,
    required this.showInDZD,
    required this.formatPrice,
    required this.getIntervalText,
    required this.onSubscribe,
    required this.onCancel, // ✅ ADDED
    required this.isSubscribing,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = plan['name'] == 'pro';
    final isCurrentPlan = currentPlan == plan['name'];
    final isFree = plan['price_cents'] == 0;
    final isPaidPlan = !isFree && plan['price_cents'] > 0;
    final features = plan['features'] as Map<String, dynamic>?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: r.sp(16)),
      decoration: BoxDecoration(
        color: isPopular ? AppColors.sageGreen : t.card,
        borderRadius: BorderRadius.circular(r.sp(20)),
        border: isPopular
            ? null
            : Border.all(
                color: isCurrentPlan ? AppColors.sageGreen.withOpacity(0.5) : t.border,
                width: isCurrentPlan ? 1.5 : 1,
              ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: AppColors.sageGreen.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: t.textPrimary.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.all(r.sp(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular)
                        Padding(
                          padding: EdgeInsets.only(bottom: r.sp(8)),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: r.wp(10), vertical: r.sp(3)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(r.sp(6)),
                            ),
                            child: Text(
                              '★  MOST POPULAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        plan['display_name'],
                        style: TextStyle(
                          fontSize: r.fs(20),
                          fontWeight: FontWeight.w800,
                          color: isPopular ? Colors.white : t.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentPlan)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.wp(10), vertical: r.sp(4)),
                    decoration: BoxDecoration(
                      color: isPopular
                          ? Colors.white.withOpacity(0.15)
                          : AppColors.sageGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(r.sp(8)),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                        color: isPopular ? Colors.white : AppColors.sageGreen,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: r.sp(16)),

            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isFree ? 'Free' : formatPrice(plan['price_cents'], plan['interval_type']),
                  style: TextStyle(
                    fontSize: r.fs(34),
                    fontWeight: FontWeight.w900,
                    color: isPopular ? Colors.white : t.textPrimary,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                if (!isFree) ...[
                  SizedBox(width: r.wp(4)),
                  Padding(
                    padding: EdgeInsets.only(bottom: r.sp(4)),
                    child: Text(
                      getIntervalText(plan['interval_type']),
                      style: TextStyle(
                        fontSize: r.fs(13),
                        color: isPopular ? Colors.white.withOpacity(0.7) : t.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            SizedBox(height: r.sp(20)),

            // Divider
            Container(
              height: 1,
              color: isPopular
                  ? Colors.white.withOpacity(0.15)
                  : t.border.withOpacity(0.6),
            ),
            SizedBox(height: r.sp(18)),

            // Features
            if (features != null)
              ...features.entries.map((entry) => _FeatureRow(
                    text: '${entry.key}: ${entry.value}',
                    isPopular: isPopular,
                    r: r,
                    t: t,
                  )),

            if (plan['doctor_limit'] > 1)
              _FeatureRow(
                text: 'Up to ${plan['doctor_limit']} doctors',
                isPopular: isPopular,
                r: r,
                t: t,
              ),

            if (plan['assistant_limit'] > 0)
              _FeatureRow(
                text: '${plan['assistant_limit']} assistant per doctor',
                isPopular: isPopular,
                r: r,
                t: t,
              ),

            SizedBox(height: r.sp(22)),
            // ✅ Current Plan with Cancel button
if (isCurrentPlan && isPaidPlan)
  Column(
    children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: r.sp(14)),
        decoration: BoxDecoration(
          color: isPopular
              ? Colors.white.withOpacity(0.15)
              : t.surface,
          borderRadius: BorderRadius.circular(r.sp(12)),
          border: isPopular
              ? Border.all(color: Colors.white.withOpacity(0.3))
              : Border.all(color: t.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: r.sp(16),
              color: isPopular ? Colors.white : AppColors.sageGreen,
            ),
            SizedBox(width: r.wp(6)),
            Text(
              'Current Plan',
              style: TextStyle(
                fontSize: r.fs(14),
                fontWeight: FontWeight.w700,
                color: isPopular ? Colors.white : AppColors.sageGreen,
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: r.sp(8)),
      // ✅ Cancel Button - same size as Current Plan
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade500,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: r.sp(14)),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.sp(12)),
            ),
          ),
          child: Text(
            'Cancel Subscription',
            style: TextStyle(
              fontSize: r.fs(14),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  )
            else if (isCurrentPlan && isFree)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.sp(14)),
                decoration: BoxDecoration(
                  color: isPopular
                      ? Colors.white.withOpacity(0.15)
                      : t.surface,
                  borderRadius: BorderRadius.circular(r.sp(12)),
                  border: isPopular
                      ? Border.all(color: Colors.white.withOpacity(0.3))
                      : Border.all(color: t.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: r.sp(16),
                      color: isPopular ? Colors.white : AppColors.sageGreen,
                    ),
                    SizedBox(width: r.wp(6)),
                    Text(
                      'Current Plan',
                      style: TextStyle(
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700,
                        color: isPopular ? Colors.white : AppColors.sageGreen,
                      ),
                    ),
                  ],
                ),
              )
            else if (isFree)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.sp(14)),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(r.sp(12)),
                  border: Border.all(color: t.border),
                ),
                child: Center(
                  child: Text(
                    'Free — No card needed',
                    style: TextStyle(
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600,
                      color: t.textMuted,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubscribing ? null : () => onSubscribe(plan['name']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? Colors.white : AppColors.sageGreen,
                    foregroundColor: isPopular ? AppColors.sageGreen : Colors.white,
                    padding: EdgeInsets.symmetric(vertical: r.sp(15)),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.sp(12)),
                    ),
                  ),
                  child: isSubscribing
                      ? SizedBox(
                          height: r.fs(16),
                          width: r.fs(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isPopular ? AppColors.sageGreen : Colors.white,
                          ),
                        )
                      : Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final bool isPopular;
  final Responsive r;
  final AppThemeTokens t;

  const _FeatureRow({
    required this.text,
    required this.isPopular,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.sp(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: r.sp(2)),
            width: r.sp(16),
            height: r.sp(16),
            decoration: BoxDecoration(
              color: isPopular
                  ? Colors.white.withOpacity(0.25)
                  : AppColors.sageGreen.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: r.sp(10),
              color: isPopular ? Colors.white : AppColors.sageGreen,
            ),
          ),
          SizedBox(width: r.wp(10)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: r.fs(13),
                color: isPopular ? Colors.white.withOpacity(0.9) : t.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trust Footer ─────────────────────────────────────────────────────────────
class _TrustFooter extends StatelessWidget {
  final Responsive r;
  final AppThemeTokens t;

  const _TrustFooter({required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: t.border.withOpacity(0.5)),
        SizedBox(height: r.sp(16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrustBadge(icon: Icons.lock_outline_rounded, label: 'Secure checkout', r: r, t: t),
            SizedBox(width: r.wp(20)),
            _TrustBadge(icon: Icons.autorenew_rounded, label: 'Cancel anytime', r: r, t: t),
            SizedBox(width: r.wp(20)),
            _TrustBadge(icon: Icons.support_agent_rounded, label: '24/7 support', r: r, t: t),
          ],
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Responsive r;
  final AppThemeTokens t;

  const _TrustBadge({required this.icon, required this.label, required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: r.sp(18), color: AppColors.sageGreen),
        SizedBox(height: r.sp(4)),
        Text(
          label,
          style: TextStyle(fontSize: r.fs(10), color: t.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Loading State ────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  final AppThemeTokens t;

  const _LoadingState({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading plans…',
            style: TextStyle(color: t.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}