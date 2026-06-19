// lib/screens/assistant_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/responsive_utils.dart';
import '../config/app_config.dart';
import 'assistant_patients_screen.dart';
import 'assistant_history_screen.dart';
import 'profile_screen.dart';

class AssistantHomeScreen extends StatefulWidget {
  const AssistantHomeScreen({super.key});

  @override
  State<AssistantHomeScreen> createState() => _AssistantHomeScreenState();
}

class _AssistantHomeScreenState extends State<AssistantHomeScreen> {
  int _currentIndex = 0;
  User? _currentUser;
  Map<String, dynamic>? _assignedDoctor;
  String? _profilePicture;
  bool _isLoading = true;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await TokenService.getUser();
      final token = await TokenService.getToken();

      if (token != null && _currentUser != null) {
        try {
          final doctor = await ApiService.getAssignedDoctor(token);
          final userInfo = await ApiService.getMe(token);
          setState(() {
            _assignedDoctor = doctor;
            _profilePicture = userInfo['profile_picture'];
          });
        } catch (e) {
          print('Error loading assigned doctor: $e');
          setState(() {
            _assignedDoctor = {
              'first_name': 'Not',
              'last_name': 'Assigned',
              'specialty': 'No doctor assigned yet',
              'hospital': 'Contact your administrator',
            };
          });
        }
      }
      setState(() => _isLoading = false);
      _initPages();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        _assignedDoctor = {
          'first_name': 'Not',
          'last_name': 'Assigned',
          'specialty': 'No doctor assigned yet',
          'hospital': 'Contact your administrator',
        };
      });
      _initPages();
    }
  }

  void _initPages() {
    _pages.clear();
    _pages.addAll([
      _HomeTab(
        assistantName: _currentUser?.fullName ?? 'Assistant',
        doctorName: _assignedDoctor != null
            ? 'Dr. ${_assignedDoctor!['first_name']} ${_assignedDoctor!['last_name']}'
            : 'Not Assigned',
        doctorSpecialty: _assignedDoctor?['specialty'] ?? 'No doctor assigned',
        doctorHospital: _assignedDoctor?['hospital'] ?? 'Contact administrator',
        profilePicture: _profilePicture,
        onNavigate: setCurrentIndex,
      ),
      const AssistantPatientsScreen(),
      const AssistantHistoryScreen(),
    ]);
    setState(() {});
  }

  void _goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_isLoading || _pages.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
              ),
              SizedBox(height: r.sp(16)),
              Text(
                'Loading assistant dashboard...',
                style: TextStyle(
                  color: t.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth > 600;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.bg,
          border: Border(top: BorderSide(color: t.border.withOpacity(0.5))),
          boxShadow: [
            BoxShadow(
              color: t.textPrimary.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.wp(16), r.sp(10), r.wp(16), bottomPadding + r.sp(10)),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 600),
                height: r.sp(64),
                decoration: BoxDecoration(
                  color: t.surface.withOpacity(t.isDark ? 0.25 : 0.85),
                  borderRadius: BorderRadius.circular(r.sp(18)),
                  border: Border.all(color: t.border.withOpacity(0.8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      selected: _currentIndex == 0,
                      onTap: () => setState(() => _currentIndex = 0),
                      r: r,
                    ),
                    _NavItem(
                      icon: Icons.assignment_ind_rounded,
                      label: 'Patients',
                      selected: _currentIndex == 1,
                      onTap: () => setState(() => _currentIndex = 1),
                      r: r,
                    ),
                    _NavItem(
                      icon: Icons.history_toggle_off_rounded,
                      label: 'History',
                      selected: _currentIndex == 2,
                      onTap: () => setState(() => _currentIndex = 2),
                      r: r,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final activeColor = AppColors.sageGreen;
    final inactiveColor = t.textPrimary.withOpacity(0.35);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: activeColor.withOpacity(0.1),
        highlightColor: activeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(r.sp(12)),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: r.sp(6), horizontal: r.wp(4)),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(r.sp(12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? activeColor : inactiveColor,
                size: r.wp(20),
              ),
              SizedBox(height: r.sp(2)),
              Text(
                label,
                style: TextStyle(
                  color: selected ? activeColor : inactiveColor,
                  fontSize: r.fs(10),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String assistantName;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorHospital;
  final String? profilePicture;
  final ValueChanged<int> onNavigate;

  const _HomeTab({
    required this.assistantName,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorHospital,
    this.profilePicture,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(r.wp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      assistantName,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: r.fs(22),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.findAncestorStateOfType<_AssistantHomeScreenState>()?._goToProfile(context),
                  child: Container(
                    width: r.wp(44),
                    height: r.wp(44),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.sageGreen.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: profilePicture != null
                          ? CachedNetworkImage(
                              imageUrl: '${AppConfig.baseUrl}$profilePicture',
                              placeholder: (context, url) => const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.account_circle_rounded,
                                color: t.textMuted,
                                size: r.wp(24),
                              ),
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.account_circle_rounded,
                              color: AppColors.sageGreen,
                              size: r.wp(24),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.sp(24)),
          Text(
            'Assigned Clinical Supervisor',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.sp(10)),
          Container(
            padding: EdgeInsets.all(r.sp(16)),
            decoration: BoxDecoration(
              color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
              borderRadius: BorderRadius.circular(r.sp(18)),
              border: Border.all(color: t.border.withOpacity(0.7)),
              boxShadow: [
                BoxShadow(
                  color: t.textPrimary.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: r.wp(42),
                      height: r.wp(42),
                      decoration: BoxDecoration(
                        color: AppColors.sageGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.healing_rounded,
                          color: AppColors.sageGreen,
                          size: r.wp(20),
                        ),
                      ),
                    ),
                    SizedBox(width: r.wp(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            doctorSpecialty,
                            style: TextStyle(
                              color: t.textMuted,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: r.sp(24),
                  color: t.border.withOpacity(0.5),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: r.sp(16),
                      color: t.textMuted,
                    ),
                    SizedBox(width: r.wp(8)),
                    Expanded(
                      child: Text(
                        doctorHospital,
                        style: TextStyle(
                          color: t.textPrimary.withOpacity(0.8),
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.sp(24)),
          Text(
            'Quick Actions',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.sp(10)),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Manage Patients',
                  onTap: () => onNavigate(1),
                  r: r,
                  t: t,
                ),
              ),
              SizedBox(width: r.wp(12)),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.analytics_rounded,
                  label: 'Past Diagnostics',
                  onTap: () => onNavigate(2),
                  r: r,
                  t: t,
                ),
              ),
            ],
          ),
          SizedBox(height: r.sp(28)),
          Container(
            padding: EdgeInsets.all(r.sp(14)),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(r.sp(14)),
              border: Border.all(color: Colors.amber.shade200.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: r.sp(18),
                      color: Colors.amber.shade700,
                    ),
                    SizedBox(width: r.wp(6)),
                    Text(
                      'Role Scoping & Permissions',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.sp(8)),
                Text(
                  '• Review and update patient directories\n• Query comprehensive execution files\n• Transmit diagnostic updates to central system\n• Execution actions are logged continuously',
                  style: TextStyle(
                    color: t.textPrimary.withOpacity(0.7),
                    fontSize: r.fs(12),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(r.sp(16)),
          decoration: BoxDecoration(
            color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
            borderRadius: BorderRadius.circular(r.sp(16)),
            border: Border.all(color: t.border.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: t.textPrimary.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(r.sp(8)),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(r.sp(10)),
                ),
                child: Icon(
                  icon,
                  color: AppColors.sageGreen,
                  size: r.sp(20),
                ),
              ),
              SizedBox(height: r.sp(16)),
              Text(
                label,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}