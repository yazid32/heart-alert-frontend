// lib/screens/admin_requests_screen.dart
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final requests = await ApiService.getAssistantRequests(token);
        setState(() {
          _requests = requests;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchData();
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final response = await ApiService.approveRequest(
          token: token,
          requestId: request['id'],
        );
        _fetchData();
        if (mounted) {
          String message = response['is_new'] == true
              ? 'Assistant created with temp password: ${response['temp_password']}'
              : 'Assistant assigned successfully';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.sageGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade400),
        );
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        final t = AppThemeTokens.of(context);
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Reject Request', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to reject this request?', style: TextStyle(color: t.textMuted)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: t.textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        final token = await TokenService.getToken();
        if (token != null) {
          await ApiService.rejectRequest(token: token, requestId: request['id']);
          _fetchData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Request rejected successfully', style: TextStyle(fontWeight: FontWeight.w600)),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade400),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: RefreshIndicator(
        color: AppColors.sageGreen,
        backgroundColor: t.surface,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.wp(16), r.sp(20), r.wp(16), r.sp(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistant Requests',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: r.fs(22),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: r.sp(4)),
                    Text(
                      'Approve and dispatch assistants onto clinic rosters.',
                      style: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen))),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                  ),
                ),
              )
            else if (_requests.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, size: r.wp(44), color: t.textMuted.withOpacity(0.3)),
                      SizedBox(height: r.sp(10)),
                      Text('All caught up!', style: TextStyle(color: t.textPrimary, fontSize: r.fs(15), fontWeight: FontWeight.w700)),
                      Text('No pending operator assignments.', style: TextStyle(color: t.textMuted, fontSize: r.fs(12))),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(r.wp(16), 0, r.wp(16), r.sp(100)),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final request = _requests[index];
                      
                      // Get data directly from request fields (not nested objects)
                      final assistantName = request['assistant_name'] ?? 'Unknown Assistant';
                      final assistantEmail = request['assistant_email'] ?? 'No email';
                      final assistantPhone = request['assistant_phone'] ?? 'No phone';
                      final doctorName = request['doctor_name'] ?? 'Unknown Doctor';
                      final doctorEmail = request['doctor_email'] ?? 'No email';
                      final notes = request['notes'];
                      final createdAt = request['created_at'];

                      return Container(
                        margin: EdgeInsets.only(bottom: r.sp(14)),
                        padding: EdgeInsets.all(r.sp(16)),
                        decoration: BoxDecoration(
                          color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
                          borderRadius: BorderRadius.circular(r.sp(18)),
                          border: Border.all(color: t.border.withOpacity(0.7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: r.wp(18),
                                  backgroundColor: AppColors.sageGreen.withOpacity(0.12),
                                  child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.sageGreen, size: r.wp(18)),
                                ),
                                SizedBox(width: r.wp(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        assistantName,
                                        style: TextStyle(color: t.textPrimary, fontSize: r.fs(15), fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: r.sp(3)),
                                      Text(
                                        assistantEmail,
                                        style: TextStyle(color: t.textMuted, fontSize: r.fs(11)),
                                      ),
                                      if (assistantPhone != 'No phone' && assistantPhone != null)
                                        Text(
                                          assistantPhone,
                                          style: TextStyle(color: t.textMuted, fontSize: r.fs(11)),
                                        ),
                                      SizedBox(height: r.sp(6)),
                                      Row(
                                        children: [
                                          Icon(Icons.arrow_right_alt_rounded, size: r.sp(14), color: t.textMuted),
                                          SizedBox(width: r.wp(4)),
                                          Expanded(
                                            child: Text(
                                              'Requested by: $doctorName',
                                              style: TextStyle(color: t.textMuted, fontSize: r.fs(12), fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (doctorEmail.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(left: r.wp(18)),
                                          child: Text(
                                            doctorEmail,
                                            style: TextStyle(color: t.textMuted.withOpacity(0.7), fontSize: r.fs(10)),
                                          ),
                                        ),
                                      if (notes != null && notes.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: r.sp(8)),
                                          child: Container(
                                            padding: EdgeInsets.all(r.sp(8)),
                                            decoration: BoxDecoration(
                                              color: t.border.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(r.sp(8)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Notes:',
                                                  style: TextStyle(color: t.textMuted, fontSize: r.fs(10), fontWeight: FontWeight.w600),
                                                ),
                                                Text(
                                                  notes,
                                                  style: TextStyle(color: t.textPrimary, fontSize: r.fs(11)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: r.sp(16)),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _rejectRequest(request),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade400,
                                      side: BorderSide(color: Colors.red.shade200.withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: EdgeInsets.symmetric(vertical: r.sp(12)),
                                    ),
                                    child: Text('Reject', style: TextStyle(fontSize: r.fs(13), fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                SizedBox(width: r.wp(12)),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _approveRequest(request),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.sageGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: EdgeInsets.symmetric(vertical: r.sp(12)),
                                    ),
                                    child: Text('Approve & Assign', style: TextStyle(fontSize: r.fs(13), fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _requests.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}