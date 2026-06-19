// lib/widgets/email_verification_dialog.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EmailVerificationDialog extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;

  const EmailVerificationDialog({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  bool _isResending = false;
  String? _message;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final isVerified = await ApiService.isEmailVerified(widget.email);
    if (mounted && isVerified) {
      setState(() {
        _isVerified = true;
        _message = 'Email verified successfully!';
      });
      // Wait a moment then close and call onVerified
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          widget.onVerified();
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      final result = await ApiService.sendVerificationEmail(widget.email);
      if (result['already_verified'] == true) {
        setState(() {
          _message = 'Email already verified!';
          _isVerified = true;
        });
        widget.onVerified();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _message = 'Verification email sent! Please check your inbox.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to send email. Please try again.';
      });
    } finally {
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isVerified ? Icons.verified_outlined : Icons.email_outlined,
              size: 64,
              color: _isVerified ? Colors.green : AppColors.sageGreen,
            ),
            const SizedBox(height: 16),
            Text(
              _isVerified ? 'Email Verified!' : 'Verify Your Email',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isVerified 
                  ? 'Your email has been verified successfully.'
                  : 'We sent a verification link to:\n${widget.email}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _message!.contains('successfully') || _message!.contains('verified')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _message!.contains('successfully') || _message!.contains('verified')
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (!_isVerified) ...[
              ElevatedButton(
                onPressed: _isResending ? null : _resendVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isResending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Resend Verification Email',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 12),
            ],
            TextButton(
              onPressed: () {
                if (_isVerified) {
                  widget.onVerified();
                }
                Navigator.pop(context);
              },
              child: Text(
                _isVerified ? 'Continue' : 'Later',
                style: TextStyle(
                  color: AppColors.sageGreen,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the dialog
Future<void> showEmailVerificationDialog(
  BuildContext context, {
  required String email,
  required VoidCallback onVerified,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => EmailVerificationDialog(
      email: email,
      onVerified: onVerified,
    ),
  );
}