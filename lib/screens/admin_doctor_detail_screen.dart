// lib/screens/admin_doctor_detail_screen.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';

class AdminDoctorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const AdminDoctorDetailScreen({
    super.key,
    required this.doctor,
  });

  @override
  State<AdminDoctorDetailScreen> createState() => _AdminDoctorDetailScreenState();
}

class _AdminDoctorDetailScreenState extends State<AdminDoctorDetailScreen> {
  Map<String, dynamic>? _doctorDetails;
  bool _isLoading = true;
  bool _isActing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails();
  }

  Future<void> _fetchDoctorDetails() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final details = await ApiService.getDoctorDetails(
          token: token,
          doctorId: widget.doctor['id'],
        );
        
        setState(() {
          _doctorDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _viewDocument(String? path, String title) async {
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not available')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
        ),
      ),
    );

    try {
      if (path.startsWith('data:')) {
        final parts = path.split(',');
        if (parts.length == 2) {
          final mimeType = parts[0].split(':')[1].split(';')[0];
          final base64Str = parts[1];
          final bytes = base64Decode(base64Str);

          if (mounted) Navigator.pop(context);

          if (mimeType.startsWith('image/')) {
            _viewImage(bytes, title);
            return;
          } else if (mimeType == 'application/pdf') {
            if (kIsWeb) {
              await launchUrl(Uri.parse(path), webOnlyWindowName: '_blank');
            } else {
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.pdf');
              await file.writeAsBytes(bytes);
              await OpenFile.open(file.path);
            }
            return;
          }
        }
      }

      String cleanPath = path.replaceAll('\\', '/');
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      if (cleanPath.startsWith('uploads/uploads/')) {
        cleanPath = cleanPath.replaceFirst('uploads/', '');
      }
      final fullUrl = '${AppConfig.baseUrl}/$cleanPath';

      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        String extension = '.pdf';
        if (fullUrl.toLowerCase().contains('.png')) {
          extension = '.png';
        } else if (fullUrl.toLowerCase().contains('.jpg') || fullUrl.toLowerCase().contains('.jpeg')) {
          extension = '.jpg';
        }

        if (extension == '.png' || extension == '.jpg') {
          _viewImage(response.bodyBytes, title);
          return;
        }

        if (kIsWeb) {
          await launchUrl(Uri.parse(fullUrl), webOnlyWindowName: '_blank');
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/${title}_${DateTime.now().millisecondsSinceEpoch}$extension');
          await file.writeAsBytes(response.bodyBytes);
          await OpenFile.open(file.path);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewImage(List<int> imageBytes, String title) async {
    if (!mounted) return;
    final Uint8List uint8List = Uint8List.fromList(imageBytes);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(20),
              child: Image.memory(uint8List, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approveDoctor() async {
    if (_doctorDetails!['email_verified'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot approve: Doctor has not verified their email.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      title: 'Approve Doctor',
      message: 'Approve Dr. ${_doctorDetails!['first_name']} ${_doctorDetails!['last_name']}?\n\nThey will be able to log in and use the app.',
      confirmLabel: 'Approve',
      confirmColor: AppColors.sageGreen,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.approveDoctor(token: token, doctorId: _doctorDetails!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor approved successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade400),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _rejectDoctor() async {
    final confirm = await _showConfirmDialog(
      title: 'Reject Doctor',
      message: 'Reject the registration of Dr. ${_doctorDetails!['first_name']} ${_doctorDetails!['last_name']}?\n\nTheir account will be suspended.',
      confirmLabel: 'Reject',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.rejectDoctor(token: token, doctorId: _doctorDetails!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor rejected'), backgroundColor: Colors.orange),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade400),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(height: 1.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  String _getPlanDisplay(String plan) {
    final planLower = plan.toLowerCase();
    
    if (planLower == 'hospital' || 
        planLower == 'hospital_plan' || 
        planLower == 'hospital_pro' ||
        planLower == 'enterprise') {
      return 'Hospital Plan';
    }
    
    if (planLower == 'pro' || 
        planLower == 'pro_plan' || 
        planLower == 'professional' ||
        planLower == 'doctor_pro') {
      return 'Doctor Pro';
    }
    
    return 'Freemium';
  }

  Color _getPlanColor(String plan) {
    final planLower = plan.toLowerCase();
    
    if (planLower == 'hospital' || 
        planLower == 'hospital_plan' || 
        planLower == 'hospital_pro' ||
        planLower == 'enterprise') {
      return Colors.blue;
    }
    
    if (planLower == 'pro' || 
        planLower == 'pro_plan' || 
        planLower == 'professional' ||
        planLower == 'doctor_pro') {
      return Colors.green;
    }
    
    return Colors.grey;
  }

  String _getSubscriptionPlan() {
    if (_doctorDetails == null) return 'freemium';
    return (_doctorDetails!['subscription_plan'] ?? 'freemium').toString();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    final isPending = _doctorDetails?['status'] == 'pending' ||
        _doctorDetails?['role'] == 'pending';
    
    final subscriptionPlan = _getSubscriptionPlan();
    final planDisplay = _getPlanDisplay(subscriptionPlan);
    final planColor = _getPlanColor(subscriptionPlan);
    
    // Desktop layout detector
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Doctor Profile Verification',
          style: TextStyle(fontSize: r.fs(18), fontWeight: FontWeight.w800, color: t.textPrimary, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.border.withOpacity(0.5)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(r.hp),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: r.wp(48), color: Colors.red.shade400),
                        SizedBox(height: r.sp(16)),
                        Text(_error!, style: TextStyle(color: Colors.red.shade400), textAlign: TextAlign.center),
                        SizedBox(height: r.sp(20)),
                        ElevatedButton.icon(
                          onPressed: _fetchDoctorDetails,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.sageGreen, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : _doctorDetails == null
                  ? const Center(child: Text('No data found'))
                  : isDesktop
                      ? _buildDesktopView(r, t, isPending, planColor, planDisplay, subscriptionPlan)
                      : _buildMobileView(r, t, isPending, planColor, planDisplay, subscriptionPlan),
    );
  }

  // --- DESKTOP VIEW LAYOUT ---
  Widget _buildDesktopView(Responsive r, AppThemeTokens t, bool isPending, Color planColor, String planDisplay, String subscriptionPlan) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: EdgeInsets.all(r.sp(32)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Panel: Identity, Subscription & Global Actions
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(r.sp(24)),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.border.withOpacity(0.8)),
                          boxShadow: [BoxShadow(color: t.textPrimary.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen.withOpacity(0.10),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.sageGreen.withOpacity(0.25), width: 2),
                              ),
                              child: const Icon(Icons.healing_rounded, color: AppColors.sageGreen, size: 44),
                            ),
                            SizedBox(height: r.sp(16)),
                            Text(
                              'Dr. ${_doctorDetails!['first_name'] ?? ''} ${_doctorDetails!['last_name'] ?? ''}',
                              style: TextStyle(color: t.textPrimary, fontSize: r.fs(22), fontWeight: FontWeight.w800, letterSpacing: -0.3),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: r.sp(8)),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.sageGreen.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _doctorDetails!['specialty'] ?? 'General Practitioner',
                                    style: TextStyle(color: AppColors.sageGreen, fontSize: r.fs(12), fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _StatusBadge(status: _doctorDetails!['status'] ?? 'pending', r: r),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.sp(24)),
                      _SectionTitle('Subscription Overview', r: r, t: t),
                      SizedBox(height: r.sp(12)),
                      _buildSubscriptionCard(r, t, planColor, planDisplay, subscriptionPlan),
                      if (isPending) ...[
                        SizedBox(height: r.sp(32)),
                        _buildActionRow(r, t),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: r.sp(32)),
              // Right Panel: Core Info Rows & Documents Layout
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Personal Details', r: r, t: t),
                      SizedBox(height: r.sp(12)),
                      _buildPersonalCard(r, t),
                      SizedBox(height: r.sp(24)),
                      _SectionTitle('Professional Credentials', r: r, t: t),
                      SizedBox(height: r.sp(12)),
                      _buildProfessionalCard(r, t),
                      SizedBox(height: r.sp(24)),
                      _SectionTitle('Verification Documents', r: r, t: t),
                      SizedBox(height: r.sp(12)),
                      _buildDocumentsContainer(r, t),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOBILE VIEW LAYOUT ---
  Widget _buildMobileView(Responsive r, AppThemeTokens t, bool isPending, Color planColor, String planDisplay, String subscriptionPlan) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r.hp, r.sp(20), r.hp, r.sp(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: r.wp(80),
                        height: r.wp(80),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreen.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.sageGreen.withOpacity(0.25), width: 2),
                          boxShadow: [BoxShadow(color: AppColors.sageGreen.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 6))],
                        ),
                        child: Icon(Icons.healing_rounded, color: AppColors.sageGreen, size: r.wp(36)),
                      ),
                      SizedBox(height: r.sp(14)),
                      Text(
                        'Dr. ${_doctorDetails!['first_name'] ?? ''} ${_doctorDetails!['last_name'] ?? ''}',
                        style: TextStyle(color: t.textPrimary, fontSize: r.fs(20), fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      SizedBox(height: r.sp(6)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: r.wp(10), vertical: r.sp(4)),
                            decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(r.sp(8))),
                            child: Text(
                              _doctorDetails!['specialty'] ?? 'General Practitioner',
                              style: TextStyle(color: AppColors.sageGreen, fontSize: r.fs(11), fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(width: r.wp(8)),
                          _StatusBadge(status: _doctorDetails!['status'] ?? 'pending', r: r),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.sp(28)),
                _SectionTitle('Subscription Information', r: r, t: t),
                SizedBox(height: r.sp(10)),
                _buildSubscriptionCard(r, t, planColor, planDisplay, subscriptionPlan),
                SizedBox(height: r.sp(22)),
                _SectionTitle('Personal Information', r: r, t: t),
                SizedBox(height: r.sp(10)),
                _buildPersonalCard(r, t),
                SizedBox(height: r.sp(22)),
                _SectionTitle('Professional Information', r: r, t: t),
                SizedBox(height: r.sp(10)),
                _buildProfessionalCard(r, t),
                SizedBox(height: r.sp(22)),
                _SectionTitle('Verification Documents', r: r, t: t),
                SizedBox(height: r.sp(10)),
                _buildDocumentsContainer(r, t),
              ],
            ),
          ),
        ),
        if (isPending)
          Container(
            padding: EdgeInsets.fromLTRB(r.hp, r.sp(14), r.hp, r.sp(24)),
            decoration: BoxDecoration(
              color: t.bg,
              border: Border(top: BorderSide(color: t.border.withOpacity(0.5))),
              boxShadow: [BoxShadow(color: t.textPrimary.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: SafeArea(top: false, child: _buildActionRow(r, t)),
          ),
      ],
    );
  }

  // --- REUSABLE UI BLOCK BUILDERS ---

  Widget _buildSubscriptionCard(Responsive r, AppThemeTokens t, Color planColor, String planDisplay, String subscriptionPlan) {
    return _InfoCard(children: [
      Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.star_rounded, color: AppColors.sageGreen, size: r.sp(15)),
          ),
          SizedBox(width: r.wp(12)),
          SizedBox(width: r.wp(100), child: Text('Plan', style: TextStyle(color: t.textMuted, fontSize: r.fs(12), fontWeight: FontWeight.w600))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: planColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: planColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(subscriptionPlan.toLowerCase().contains('hospital') ? Icons.local_hospital_rounded : Icons.star_rounded, size: r.sp(14), color: planColor),
                  SizedBox(width: r.wp(6)),
                  Text(planDisplay, style: TextStyle(color: planColor, fontSize: r.fs(12), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: r.sp(12)),
      Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.verified_rounded, color: AppColors.sageGreen, size: r.sp(15)),
          ),
          SizedBox(width: r.wp(12)),
          SizedBox(width: r.wp(100), child: Text('Status', style: TextStyle(color: t.textMuted, fontSize: r.fs(12), fontWeight: FontWeight.w600))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (_doctorDetails!['subscription_status'] == 'active' ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: (_doctorDetails!['subscription_status'] == 'active' ? Colors.green : Colors.orange).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: _doctorDetails!['subscription_status'] == 'active' ? Colors.green : Colors.orange, shape: BoxShape.circle)),
                  SizedBox(width: r.wp(5)),
                  Text(_doctorDetails!['subscription_status'] ?? 'active', style: TextStyle(color: _doctorDetails!['subscription_status'] == 'active' ? Colors.green : Colors.orange, fontSize: r.fs(11), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
      if (_doctorDetails!['subscription_expires_at'] != null) ...[
        SizedBox(height: r.sp(12)),
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.calendar_today_rounded, color: AppColors.sageGreen, size: r.sp(15)),
            ),
            SizedBox(width: r.wp(12)),
            SizedBox(width: r.wp(100), child: Text('Expires', style: TextStyle(color: t.textMuted, fontSize: r.fs(12), fontWeight: FontWeight.w600))),
            Expanded(child: Text(_formatDate(_doctorDetails!['subscription_expires_at']), style: TextStyle(color: t.textPrimary, fontSize: r.fs(12), fontWeight: FontWeight.w500))),
          ],
        ),
      ],
    ]);
  }

  Widget _buildPersonalCard(Responsive r, AppThemeTokens t) {
    return _InfoCard(children: [
      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: _doctorDetails!['email'] ?? 'N/A', t: t, r: r),
      _Divider(t: t),
      _InfoRow(icon: Icons.verified_outlined, label: 'Email Status', value: _doctorDetails!['email_verified'] == true ? '✓ Verified' : '✗ Not Verified', t: t, r: r, valueColor: _doctorDetails!['email_verified'] == true ? Colors.green : Colors.orange),
      _Divider(t: t),
      _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: _doctorDetails!['phone'] ?? 'N/A', t: t, r: r),
      _Divider(t: t),
      _InfoRow(icon: Icons.flag_outlined, label: 'Country', value: _doctorDetails!['country'] ?? 'N/A', t: t, r: r),
    ]);
  }

  Widget _buildProfessionalCard(Responsive r, AppThemeTokens t) {
    return _InfoCard(children: [
      _InfoRow(icon: Icons.badge_outlined, label: 'License No.', value: _doctorDetails!['license_number'] ?? 'N/A', t: t, r: r),
      _Divider(t: t),
      _InfoRow(icon: Icons.local_hospital_outlined, label: 'Hospital', value: _doctorDetails!['hospital'] ?? _doctorDetails!['hospital_name'] ?? 'N/A', t: t, r: r),
      _Divider(t: t),
      _InfoRow(icon: Icons.medical_services_outlined, label: 'Specialty', value: _doctorDetails!['specialty'] ?? 'N/A', t: t, r: r),
    ]);
  }

  Widget _buildDocumentsContainer(Responsive r, AppThemeTokens t) {
    final noDocs = (_doctorDetails!['medical_license_path'] == null || _doctorDetails!['medical_license_path'].toString().isEmpty) &&
                   (_doctorDetails!['government_id_path'] == null || _doctorDetails!['government_id_path'].toString().isEmpty);
    return Column(
      children: [
        if (noDocs)
          Container(
            margin: EdgeInsets.only(bottom: r.sp(12)),
            padding: EdgeInsets.all(r.sp(14)),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.withOpacity(0.25))),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: r.wp(20)),
                SizedBox(width: r.wp(10)),
                Expanded(child: Text('This doctor did not upload any verification documents.', style: TextStyle(color: Colors.orange.shade700, fontSize: r.fs(12), height: 1.4))),
              ],
            ),
          ),
        _DocumentTile(
          title: 'Medical License Document',
          hasDocument: _doctorDetails!['medical_license_path'] != null && _doctorDetails!['medical_license_path'].toString().isNotEmpty,
          documentPath: _doctorDetails!['medical_license_path'],
          onView: () => _viewDocument(_doctorDetails!['medical_license_path'], 'Medical_License'),
          r: r,
          t: t,
        ),
        _DocumentTile(
          title: 'Government Issued ID',
          hasDocument: _doctorDetails!['government_id_path'] != null && _doctorDetails!['government_id_path'].toString().isNotEmpty,
          documentPath: _doctorDetails!['government_id_path'],
          onView: () => _viewDocument(_doctorDetails!['government_id_path'], 'Government_ID'),
          r: r,
          t: t,
        ),
        SizedBox(height: r.sp(16)),
        _InfoCard(children: [
          _InfoRow(icon: Icons.access_time_rounded, label: 'Registered On', value: _doctorDetails!['created_at'] != null ? DateTime.parse(_doctorDetails!['created_at']).toString().split('.')[0] : 'N/A', t: t, r: r),
        ]),
      ],
    );
  }

  Widget _buildActionRow(Responsive r, AppThemeTokens t) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isActing ? null : _rejectDoctor,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade500,
              side: BorderSide(color: Colors.red.shade300),
              padding: EdgeInsets.symmetric(vertical: r.sp(16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        SizedBox(width: r.wp(16)),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isActing ? null : _approveDoctor,
            icon: _isActing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(_isActing ? 'Processing…' : 'Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: r.sp(16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ).copyWith(
              shadowColor: WidgetStateProperty.all(AppColors.sageGreen.withOpacity(0.2)),
              elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) ? 0 : 2),
            ),
          ),
        ),
      ],
    );
  }
}

// --- SUB COMPONENTS ---

class _SectionTitle extends StatelessWidget {
  final String text;
  final Responsive r;
  final AppThemeTokens t;

  const _SectionTitle(this.text, {required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.sageGreen, borderRadius: BorderRadius.circular(2))),
        SizedBox(width: r.wp(8)),
        Text(text, style: TextStyle(color: t.textPrimary, fontSize: r.fs(14), fontWeight: FontWeight.w800, letterSpacing: -0.1)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Responsive r;

  const _StatusBadge({required this.status, required this.r});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'suspended':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending Verification';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: r.wp(6)),
          Text(label, style: TextStyle(color: color, fontSize: r.fs(11), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final r = Responsive.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.sp(16)),
      decoration: BoxDecoration(
        color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: t.textPrimary.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppThemeTokens t;
  final Responsive r;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
    required this.r,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.sp(10)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.sageGreen, size: r.sp(15)),
          ),
          SizedBox(width: r.wp(12)),
          SizedBox(width: r.wp(110), child: Text(label, style: TextStyle(color: t.textMuted, fontSize: r.fs(12), fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor ?? t.textPrimary, fontSize: r.fs(12), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppThemeTokens t;
  const _Divider({required this.t});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: t.border.withOpacity(0.4));
  }
}

class _DocumentTile extends StatelessWidget {
  final String title;
  final bool hasDocument;
  final String? documentPath;
  final VoidCallback onView;
  final Responsive r;
  final AppThemeTokens t;

  const _DocumentTile({
    required this.title,
    required this.hasDocument,
    required this.documentPath,
    required this.onView,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: r.sp(12)),
      padding: EdgeInsets.all(r.sp(16)),
      decoration: BoxDecoration(
        color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasDocument ? t.border.withOpacity(0.6) : Colors.orange.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: t.textPrimary.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (hasDocument ? Colors.red.shade600 : Colors.orange).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(hasDocument ? Icons.picture_as_pdf_rounded : Icons.warning_amber_rounded, color: hasDocument ? Colors.red.shade600 : Colors.orange.shade500, size: 22),
          ),
          SizedBox(width: r.wp(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: r.fs(13), fontWeight: FontWeight.w700, color: t.textPrimary)),
                SizedBox(height: r.sp(4)),
                Text(hasDocument ? 'Document available — view files' : 'No submission provided', style: TextStyle(fontSize: r.fs(11), color: hasDocument ? t.textMuted : Colors.orange.shade500, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (hasDocument)
            ElevatedButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.visibility_rounded, size: 14),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: TextStyle(fontSize: r.fs(12), fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }
}