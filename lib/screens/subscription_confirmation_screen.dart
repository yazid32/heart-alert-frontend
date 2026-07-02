// lib/screens/subscription_confirmation_screen.dart
//
// Shown right after the user is deep-linked back into the app from Stripe
// Checkout (heartalert://payment-success?plan=...). Stripe's webhook updates
// the subscription asynchronously, so this screen polls /my-subscription for
// a few seconds until the plan actually reflects the upgrade, rather than
// assuming success the instant the deep link fires.

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'pricing_screen.dart';

class SubscriptionConfirmationScreen extends StatefulWidget {
  final String expectedPlan;

  const SubscriptionConfirmationScreen({super.key, required this.expectedPlan});

  @override
  State<SubscriptionConfirmationScreen> createState() => _SubscriptionConfirmationScreenState();
}

enum _ConfirmState { checking, confirmed, timedOut }

class _SubscriptionConfirmationScreenState extends State<SubscriptionConfirmationScreen> {
  _ConfirmState _state = _ConfirmState.checking;

  static const int _maxAttempts = 6; // ~ 6 * 2s = 12s of polling
  static const Duration _pollInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _pollSubscription();
  }

  Future<void> _pollSubscription() async {
    final token = await TokenService.getToken();
    if (token == null) {
      if (mounted) setState(() => _state = _ConfirmState.timedOut);
      return;
    }

    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final sub = await ApiService.getMySubscription(token);
        final currentPlan = sub['plan'];
        if (currentPlan == widget.expectedPlan) {
          if (mounted) setState(() => _state = _ConfirmState.confirmed);
          return;
        }
      } catch (_) {
        // ignore and retry
      }
      await Future.delayed(_pollInterval);
    }

    if (mounted) setState(() => _state = _ConfirmState.timedOut);
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _backToPricing() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PricingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_state == _ConfirmState.checking) ...[
                  const CircularProgressIndicator(color: AppColors.sageGreen),
                  const SizedBox(height: 24),
                  const Text(
                    'Confirming your subscription…',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This usually only takes a few seconds.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_state == _ConfirmState.confirmed) ...[
                  const Icon(Icons.check_circle_rounded, color: AppColors.sageGreen, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    'You\'re on ${widget.expectedPlan.toUpperCase()} now!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _goHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue', style: TextStyle(color: Colors.white)),
                  ),
                ] else ...[
                  const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Still processing your payment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your payment may have succeeded — it can take a moment to reflect. '
                    'Check back shortly, or contact support if this persists.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _backToPricing,
                        child: const Text('Back to Pricing'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _state = _ConfirmState.checking);
                          _pollSubscription();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.sageGreen),
                        child: const Text('Check Again', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}