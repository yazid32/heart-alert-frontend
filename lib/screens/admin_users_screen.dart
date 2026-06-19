// lib/screens/admin_users_screen.dart
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'admin_doctor_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _doctors = [];
  List<dynamic> _assistants = [];
  List<dynamic> _pendingDoctors = [];
  bool _isLoading = true;
  String? _error;
  String _userTypeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final doctors = await ApiService.getAdminDoctors(token);
        final assistants = await ApiService.getAllAssistants(token);
        final pendingDoctors = await ApiService.getPendingDoctors(token);
        setState(() {
          _doctors = doctors;
          _assistants = assistants;
          _pendingDoctors = pendingDoctors;
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
    await _fetchUsers();
  }

  List<dynamic> get _filteredUsers {
    switch (_userTypeFilter) {
      case 'doctors':
        return _doctors;
      case 'assistants':
        return _assistants;
      case 'pending':
        return _pendingDoctors;
      default:
        return [..._doctors, ..._assistants];
    }
  }

  Future<void> _removeAssistant(int assistantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Assistant'),
        content: const Text('Are you sure? This assistant will need to be re-approved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await TokenService.getToken();
        if (token != null) {
          await ApiService.removeAssistant(token: token, assistantId: assistantId);
          _fetchUsers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Assistant removed successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
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
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(r.hp, r.sp(16), r.hp, r.sp(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Users',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: r.fs(28),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _userTypeFilter == 'all',
                        onTap: () => setState(() => _userTypeFilter = 'all'),
                        r: r,
                      ),
                      SizedBox(width: r.sp(8)),
                      _FilterChip(
                        label: 'Doctors',
                        selected: _userTypeFilter == 'doctors',
                        onTap: () => setState(() => _userTypeFilter = 'doctors'),
                        r: r,
                        color: AppColors.sageGreen,
                      ),
                      SizedBox(width: r.sp(8)),
                      _FilterChip(
                        label: 'Assistants',
                        selected: _userTypeFilter == 'assistants',
                        onTap: () => setState(() => _userTypeFilter = 'assistants'),
                        r: r,
                        color: Colors.blue,
                      ),
                      SizedBox(width: r.sp(8)),
                      _FilterChip(
                        label: 'Pending Doctors',
                        selected: _userTypeFilter == 'pending',
                        onTap: () => setState(() => _userTypeFilter = 'pending'),
                        r: r,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Text(_error!)),
              )
            else if (_filteredUsers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _userTypeFilter == 'pending'
                            ? Icons.pending_actions_rounded
                            : Icons.people_outline,
                        size: r.sp(64),
                        color: t.textMuted,
                      ),
                      SizedBox(height: r.sp(16)),
                      Text(
                        _userTypeFilter == 'pending'
                            ? 'No pending doctors'
                            : 'No users found',
                        style: TextStyle(color: t.textMuted, fontSize: r.fs(16)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.all(r.hp),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = _filteredUsers[index];
                      final isDoctor = user['specialty'] != null || user['license_number'] != null;
                      final isPending = _userTypeFilter == 'pending' || 
                         (user['status'] == 'pending' && isDoctor);
                      
                      return _UserCard(
                        user: user,
                        isDoctor: isDoctor,
                        isPending: isPending,
                        onRemove: (!isDoctor && _userTypeFilter != 'pending') 
                            ? () => _removeAssistant(user['id']) 
                            : null,
                        r: r,
                        t: t,
                      );
                    },
                    childCount: _filteredUsers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.r,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? (color ?? AppColors.sageGreen) : Colors.transparent;
    final textColor = selected ? Colors.white : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(r.sp(20)),
          border: Border.all(
            color: selected ? bgColor : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: r.fs(12),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDoctor;
  final bool isPending;
  final VoidCallback? onRemove;
  final Responsive r;
  final AppThemeTokens t;

  const _UserCard({
    required this.user,
    required this.isDoctor,
    required this.isPending,
    this.onRemove,
    required this.r,
    required this.t,
  });

  Future<void> _viewDoctorDetails(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDoctorDetailScreen(doctor: user),
      ),
    );
    if (result == true) {
      if (context.mounted) {
        final state = context.findAncestorStateOfType<_AdminUsersScreenState>();
        state?._fetchUsers();
      }
    }
  }

  String _getPlanDisplay() {
    final plan = user['subscription_plan'] ?? 'freemium';
    switch (plan) {
      case 'pro':
        return 'PRO';
      case 'hospital':
      case 'hospital_pro':
        return 'HOSPITAL';
      default:
        return 'FREE';
    }
  }

  Color _getPlanColor() {
    final plan = user['subscription_plan'] ?? 'freemium';
    switch (plan) {
      case 'pro':
        return Colors.green;
      case 'hospital':
      case 'hospital_pro':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _viewDoctorDetails(context),
      child: Container(
        margin: EdgeInsets.only(bottom: r.sp(12)),
        padding: EdgeInsets.all(r.sp(16)),
        decoration: BoxDecoration(
          color: t.card.withOpacity(t.isDark ? 1.0 : 0.62),
          borderRadius: BorderRadius.circular(r.sp(20)),
          border: Border.all(
            color: isPending ? Colors.orange.withOpacity(0.3) : t.border,
            width: isPending ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: r.wp(50),
                  height: r.wp(50),
                  decoration: BoxDecoration(
                    color: (isDoctor ? AppColors.sageGreen : Colors.blue).withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDoctor ? Icons.medical_services_rounded : Icons.person_outline_rounded,
                    color: isDoctor ? AppColors.sageGreen : Colors.blue,
                    size: r.wp(24),
                  ),
                ),
                SizedBox(width: r.wp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isDoctor
                                  ? 'Dr. ${user['first_name']} ${user['last_name']}'
                                  : '${user['first_name']} ${user['last_name']}',
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: r.fs(16),
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: r.sp(8)),
                          // Subscription Badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: r.sp(6), vertical: r.sp(2)),
                            decoration: BoxDecoration(
                              color: _getPlanColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(r.sp(4)),
                              border: Border.all(color: _getPlanColor().withOpacity(0.3)),
                            ),
                            child: Text(
                              _getPlanDisplay(),
                              style: TextStyle(
                                color: _getPlanColor(),
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        user['email'],
                        style: TextStyle(
                          color: t.textMuted,
                          fontSize: r.fs(11),
                        ),
                      ),
                      if (isPending)
                        Padding(
                          padding: EdgeInsets.only(top: r.sp(4)),
                          child: Row(
                            children: [
                              Icon(
                                user['email_verified'] == true 
                                    ? Icons.verified_rounded 
                                    : Icons.warning_amber_rounded,
                                size: r.sp(12),
                                color: user['email_verified'] == true 
                                    ? Colors.green 
                                    : Colors.orange,
                              ),
                              SizedBox(width: r.sp(4)),
                              Text(
                                user['email_verified'] == true 
                                    ? 'Email Verified ✓' 
                                    : 'Email Not Verified',
                                style: TextStyle(
                                  color: user['email_verified'] == true 
                                      ? Colors.green 
                                      : Colors.orange,
                                  fontSize: r.fs(10),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isPending)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.sp(8), vertical: r.sp(4)),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(r.sp(8)),
                    ),
                    child: Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: r.fs(10),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (!isDoctor && onRemove != null && !isPending)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: onRemove,
                    tooltip: 'Remove Assistant',
                  ),
              ],
            ),
            if (isDoctor && user['specialty'] != null)
              Padding(
                padding: EdgeInsets.only(top: r.sp(8)),
                child: Text(
                  'Specialty: ${user['specialty']}',
                  style: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                ),
              ),
            if (isDoctor && user['hospital'] != null)
              Padding(
                padding: EdgeInsets.only(top: r.sp(4)),
                child: Text(
                  '🏥 ${user['hospital']}',
                  style: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                ),
              ),
            if (!isDoctor && user['assigned_doctor_name'] != null)
              Padding(
                padding: EdgeInsets.only(top: r.sp(8)),
                child: Container(
                  padding: EdgeInsets.all(r.sp(8)),
                  decoration: BoxDecoration(
                    color: t.bg.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(r.sp(8)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.medical_services, size: r.sp(14), color: AppColors.sageGreen),
                      SizedBox(width: r.sp(6)),
                      Expanded(
                        child: Text(
                          'Assigned to: Dr. ${user['assigned_doctor_name']}',
                          style: TextStyle(color: t.textMuted, fontSize: r.fs(11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward_ios,
                size: r.sp(14),
                color: t.textMuted.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}