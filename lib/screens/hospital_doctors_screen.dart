// lib/screens/hospital/hospital_doctors_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/token_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_utils.dart';

class HospitalDoctorsScreen extends StatefulWidget {
  const HospitalDoctorsScreen({super.key});

  @override
  State<HospitalDoctorsScreen> createState() => _HospitalDoctorsScreenState();
}

class _HospitalDoctorsScreenState extends State<HospitalDoctorsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _isLoading = true;
  bool _isInviting = false;
  String? _error;
  late TabController _tabController;

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final doctors = await ApiService.getHospitalDoctors(token);
        final invitations = await ApiService.getPendingInvitations(token);
        setState(() {
          _doctors = doctors;
          _pendingInvitations = invitations;
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

  Future<void> _inviteDoctor() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnack('Please enter doctor email', Colors.orange);
      return;
    }
    setState(() => _isInviting = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.inviteDoctorToHospital(
          token: token,
          email: _emailController.text.trim(),
        );
        if (mounted) {
          _showSnack('Invitation sent! The doctor will receive an email.', Colors.green);
          _emailController.clear();
          Navigator.pop(context);
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInviteDialog() {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.sp(24))),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: r.wp(440)),
          padding: EdgeInsets.all(r.sp(24)),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.sp(10)),
                      decoration: BoxDecoration(
                        color: AppColors.sageGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(r.sp(12)),
                      ),
                      child: Icon(Icons.person_add_rounded,
                          color: AppColors.sageGreen, size: r.sp(22)),
                    ),
                    SizedBox(width: r.sp(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite a Doctor',
                            style: TextStyle(
                              fontSize: r.fs(18),
                              fontWeight: FontWeight.w800,
                              color: t.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'They\'ll get Pro features for free',
                            style: TextStyle(
                                fontSize: r.fs(12), color: t.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: t.textMuted, size: r.sp(20)),
                      style: IconButton.styleFrom(
                        backgroundColor: t.border.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.sp(8))),
                        padding: EdgeInsets.all(r.sp(4)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.sp(20)),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Doctor\'s email',
                    hintText: 'doctor@hospital.com',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: AppColors.sageGreen, size: r.sp(20)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.sp(12)),
                      borderSide: BorderSide(color: t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.sp(12)),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.sp(12)),
                      borderSide: const BorderSide(
                          color: AppColors.sageGreen, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter email';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                SizedBox(height: r.sp(16)),

                // Pro perks callout
                Container(
                  padding: EdgeInsets.all(r.sp(14)),
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(r.sp(12)),
                    border: Border.all(
                        color: AppColors.sageGreen.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          color: AppColors.sageGreen, size: r.sp(20)),
                      SizedBox(width: r.sp(12)),
                      Expanded(
                        child: Text(
                          'Invited doctors get full Pro access at no extra cost under your hospital plan.',
                          style: TextStyle(
                            fontSize: r.fs(12),
                            color: t.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.sp(20)),

                // Send button
                SizedBox(
                  width: double.infinity,
                  height: r.sp(50),
                  child: ElevatedButton(
                    onPressed: _isInviting ? null : _inviteDoctor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.sp(12))),
                    ),
                    child: _isInviting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: r.sp(16)),
                              SizedBox(width: r.sp(8)),
                              Text(
                                'Send Invitation',
                                style: TextStyle(
                                  fontSize: r.fs(14),
                                  fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Future<void> _resendInvitation(Map<String, dynamic> invitation) async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.resendInvitation(
            token, invitation['id'].toString());
        if (mounted) {
          _showSnack('Invitation resent', Colors.green);
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _cancelInvitation(Map<String, dynamic> invitation) async {
    final t = AppThemeTokens.of(context);
    final r = Responsive.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel invitation?',
            style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.fs(16))),
        content: Text(
          'The invitation to ${invitation['email']} will be cancelled.',
          style: TextStyle(color: t.textMuted, fontSize: r.fs(13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep it',
                style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel invite',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.cancelInvitation(
            token, invitation['id'].toString());
        if (mounted) {
          _showSnack('Invitation cancelled', Colors.orange);
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Doctors',
          style: TextStyle(
            fontSize: r.fs(20),
            fontWeight: FontWeight.w800,
            color: t.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.wp(12)),
            child: ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: Icon(Icons.person_add_rounded, size: r.sp(16)),
              label: Text('Invite',
                  style: TextStyle(
                      fontSize: r.fs(13), fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                    horizontal: r.wp(14), vertical: r.sp(8)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.sp(10))),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(r.sp(50)),
          child: Column(
            children: [
              Divider(height: 1, color: t.border.withOpacity(0.4)),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.sageGreen,
                indicatorWeight: 2.5,
                labelColor: AppColors.sageGreen,
                unselectedLabelColor: t.textMuted,
                labelStyle: TextStyle(
                    fontSize: r.fs(13), fontWeight: FontWeight.w700),
                unselectedLabelStyle: TextStyle(
                    fontSize: r.fs(13), fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: 'Active (${_doctors.length})'),
                  Tab(text: 'Pending (${_pendingInvitations.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
                strokeWidth: 2.5,
              ),
            )
          : _error != null
              ? _ErrorState(
                  error: _error!,
                  onRetry: _loadData,
                  r: r,
                  t: t,
                )
              : Column(
                  children: [
                    // Hospital active banner
                    _HospitalActiveBanner(r: r),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Active doctors tab
                          RefreshIndicator(
                            color: AppColors.sageGreen,
                            onRefresh: _loadData,
                            child: _doctors.isEmpty
                                ? _EmptyState(
                                    icon: Icons.people_outline_rounded,
                                    title: 'No doctors yet',
                                    message:
                                        'Invite your first doctor.\nThey\'ll get Pro for free.',
                                    onAction: _showInviteDialog,
                                    actionLabel: 'Invite a Doctor',
                                    r: r,
                                    t: t,
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                        r.wp(16), r.sp(16), r.wp(16), r.sp(32)),
                                    itemCount: _doctors.length,
                                    itemBuilder: (context, index) {
                                      return _DoctorCard(
                                        doctor: _doctors[index],
                                        r: r,
                                        t: t,
                                        onRefresh: _loadData,
                                      );
                                    },
                                  ),
                          ),
                          // Pending invitations tab
                          RefreshIndicator(
                            color: AppColors.sageGreen,
                            onRefresh: _loadData,
                            child: _pendingInvitations.isEmpty
                                ? _EmptyState(
                                    icon: Icons.mark_email_read_outlined,
                                    title: 'No pending invitations',
                                    message: 'All sent invitations have been accepted.',
                                    r: r,
                                    t: t,
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                        r.wp(16), r.sp(16), r.wp(16), r.sp(32)),
                                    itemCount: _pendingInvitations.length,
                                    itemBuilder: (context, index) {
                                      final inv = _pendingInvitations[index];
                                      return _PendingInvitationCard(
                                        invitation: inv,
                                        r: r,
                                        t: t,
                                        onResend: () => _resendInvitation(inv),
                                        onCancel: () => _cancelInvitation(inv),
                                      );
                                    },
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

// ── Hospital Active Banner ────────────────────────────────────────────────────
class _HospitalActiveBanner extends StatelessWidget {
  final Responsive r;
  const _HospitalActiveBanner({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(r.wp(16), r.sp(14), r.wp(16), 0),
      padding: EdgeInsets.symmetric(
          horizontal: r.wp(16), vertical: r.sp(12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sageGreen, const Color(0xFF2D7D5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.sp(14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.sageGreen.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(r.sp(8)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(r.sp(10)),
            ),
            child: Icon(Icons.verified_rounded,
                color: Colors.white, size: r.sp(18)),
          ),
          SizedBox(width: r.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hospital Plan Active',
                  style: TextStyle(
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Invited doctors get Pro features at no extra cost.',
                  style: TextStyle(
                    fontSize: r.fs(11),
                    color: Colors.white.withOpacity(0.8),
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

// ── Doctor Card ───────────────────────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final Responsive r;
  final AppThemeTokens t;
  final VoidCallback onRefresh;

  const _DoctorCard({
    required this.doctor,
    required this.r,
    required this.t,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final status = doctor['status'] ?? 'active';
    final isActive = status == 'active';
    final name = doctor['name'] ??
        'Dr. ${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'.trim();
    final specialty = doctor['specialty'] ?? 'General Practitioner';

    return Container(
      margin: EdgeInsets.only(bottom: r.sp(12)),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(r.sp(16)),
        border: Border.all(color: t.border.withOpacity(0.6)),
      ),
      child: Padding(
        padding: EdgeInsets.all(r.sp(16)),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar with initials
                Container(
                  width: r.wp(46),
                  height: r.wp(46),
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.sageGreen.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty
                          ? name.substring(0, 1).toUpperCase()
                          : 'D',
                      style: TextStyle(
                        fontSize: r.fs(18),
                        fontWeight: FontWeight.w800,
                        color: AppColors.sageGreen,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.sp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: r.fs(14),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(height: r.sp(2)),
                      Text(
                        specialty,
                        style: TextStyle(
                            fontSize: r.fs(12), color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                // Status + Pro badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SmallBadge(
                      label: isActive ? 'Active' : 'Inactive',
                      color: isActive ? Colors.green : Colors.orange,
                      withDot: true,
                    ),
                    SizedBox(height: r.sp(4)),
                    _SmallBadge(
                      label: 'Pro Free',
                      color: AppColors.sageGreen,
                      icon: Icons.star_rounded,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: r.sp(12)),
            // Email row
            Row(
              children: [
                Icon(Icons.email_outlined,
                    size: r.sp(13), color: t.textMuted),
                SizedBox(width: r.wp(6)),
                Expanded(
                  child: Text(
                    doctor['email'] ?? 'N/A',
                    style:
                        TextStyle(fontSize: r.fs(12), color: t.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: r.sp(12)),
            // Remove button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRemoveDialog(context),
                icon: Icon(Icons.person_remove_rounded,
                    size: r.sp(14), color: Colors.red.shade400),
                label: Text(
                  'Remove from hospital',
                  style: TextStyle(
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding:
                      EdgeInsets.symmetric(vertical: r.sp(10)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.sp(10))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.sp(20))),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade400, size: r.sp(22)),
            SizedBox(width: r.sp(10)),
            Text(
              'Remove Doctor',
              style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: r.fs(16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove this doctor from your hospital?',
              style:
                  TextStyle(color: t.textPrimary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.sp(12)),
            Container(
              padding: EdgeInsets.all(r.sp(12)),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(r.sp(10)),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade700,
                      fontSize: r.fs(12),
                    ),
                  ),
                  SizedBox(height: r.sp(6)),
                  for (final line in [
                    'Remove the doctor from your hospital',
                    'Revert their plan to Freemium',
                    'They will lose Pro features',
                  ])
                    Padding(
                      padding: EdgeInsets.only(bottom: r.sp(2)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ',
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: r.fs(11))),
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                  fontSize: r.fs(11),
                                  color: t.textMuted,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: t.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              _removeDoctor(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.sp(10))),
            ),
            child: const Text('Remove',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeDoctor(BuildContext context) async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.removeHospitalDoctor(
          token: token,
          doctorId: doctor['id'],
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Doctor removed and reverted to Freemium'),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          onRefresh();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ── Pending Invitation Card ───────────────────────────────────────────────────
class _PendingInvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final Responsive r;
  final AppThemeTokens t;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  const _PendingInvitationCard({
    required this.invitation,
    required this.r,
    required this.t,
    required this.onResend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: r.sp(12)),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(r.sp(16)),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Padding(
        padding: EdgeInsets.all(r.sp(16)),
        child: Column(
          children: [
            Row(
              children: [
                // Pending avatar
                Container(
                  width: r.wp(46),
                  height: r.wp(46),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.pending_rounded,
                        color: Colors.orange, size: r.sp(22)),
                  ),
                ),
                SizedBox(width: r.sp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation['email'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: r.sp(2)),
                      Text(
                        invitation['specialty'] ?? 'Awaiting acceptance',
                        style: TextStyle(
                            fontSize: r.fs(12), color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                _SmallBadge(
                  label: 'Pending',
                  color: Colors.orange,
                  withDot: true,
                ),
              ],
            ),
            SizedBox(height: r.sp(14)),
            // Pro free note
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.wp(12), vertical: r.sp(8)),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(r.sp(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: r.sp(13), color: AppColors.sageGreen),
                  SizedBox(width: r.sp(6)),
                  Text(
                    'Will get Pro features free once accepted',
                    style: TextStyle(
                      fontSize: r.fs(11),
                      color: AppColors.sageGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.sp(12)),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onResend,
                    icon: Icon(Icons.send_rounded, size: r.sp(13)),
                    label: Text('Resend',
                        style: TextStyle(fontSize: r.fs(12))),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sageGreen,
                      side: BorderSide(
                          color: AppColors.sageGreen.withOpacity(0.4)),
                      padding: EdgeInsets.symmetric(vertical: r.sp(9)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.sp(8))),
                    ),
                  ),
                ),
                SizedBox(width: r.sp(8)),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: Icon(Icons.close_rounded, size: r.sp(13)),
                    label: Text('Cancel',
                        style: TextStyle(fontSize: r.fs(12))),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: EdgeInsets.symmetric(vertical: r.sp(9)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.sp(8))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small Badge ───────────────────────────────────────────────────────────────
class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool withDot;
  final IconData? icon;

  const _SmallBadge({
    required this.label,
    required this.color,
    this.withDot = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Responsive r;
  final AppThemeTokens t;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.wp(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(r.sp(22)),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: r.wp(36),
                  color: AppColors.sageGreen.withOpacity(0.5)),
            ),
            SizedBox(height: r.sp(20)),
            Text(
              title,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: r.sp(8)),
            Text(
              message,
              style: TextStyle(
                  color: t.textMuted, fontSize: r.fs(13), height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              SizedBox(height: r.sp(24)),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(Icons.person_add_rounded, size: r.sp(16)),
                label: Text(
                  actionLabel ?? 'Invite Doctor',
                  style: TextStyle(
                      fontSize: r.fs(13), fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.wp(20), vertical: r.sp(12)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.sp(12))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final Responsive r;
  final AppThemeTokens t;

  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.wp(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: r.wp(44), color: Colors.red.shade400),
            SizedBox(height: r.sp(16)),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.sp(8)),
            Text(
              error,
              style: TextStyle(
                  color: Colors.red.shade400, fontSize: r.fs(12)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.sp(20)),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: r.sp(16)),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.sp(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}